import 'package:dogmatch/core/error/api_exception.dart';
import 'package:dogmatch/features/discovery/data/models/swipe_result_model.dart';
import 'package:dogmatch/features/discovery/domain/entities/swipe_action.dart';
import 'package:dogmatch/features/discovery/domain/repositories/discovery_repository.dart';
import 'package:dogmatch/features/discovery/presentation/cubit/active_dog_cubit.dart';
import 'package:dogmatch/features/dogs/data/models/dog_model.dart';
import 'package:dogmatch/features/dogs/data/models/dog_owner_model.dart';
import 'package:dogmatch/features/dogs/domain/entities/dog_enums.dart';
import 'package:dogmatch/features/dogs/domain/repositories/dog_repository.dart';
import 'package:dogmatch/features/matches/data/models/like_received_model.dart';
import 'package:dogmatch/features/matches/data/models/match_model.dart';
import 'package:dogmatch/features/matches/domain/repositories/likes_repository.dart';
import 'package:dogmatch/features/matches/presentation/cubit/likes_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockLikesRepository extends Mock implements LikesRepository {}

class MockDiscoveryRepository extends Mock implements DiscoveryRepository {}

class MockDogRepository extends Mock implements DogRepository {}

DogModel _makeDog(String id, {String name = 'Rex'}) => DogModel(
      id: id,
      ownerId: 'owner-$id',
      name: name,
      breed: 'Vira-lata',
      sex: DogSex.male,
      birthDate: DateTime.utc(2024),
      size: DogSize.medium,
      intent: DogIntent.friendship,
      createdAt: DateTime.utc(2026),
    );

LikeReceivedModel _makeLike(DogModel dog, {String? myAction}) =>
    LikeReceivedModel(
      dog: dog,
      distanceKm: 1.2,
      owner: DogOwnerModel(id: 'owner-${dog.id}', name: 'Tutora'),
      likedAt: DateTime.utc(2026, 2, 1),
      myAction: myAction,
    );

void main() {
  final myDog = _makeDog('my-dog', name: 'Bidu');
  final likerDog = _makeDog('liker-dog', name: 'Luna');
  final otherLikerDog = _makeDog('other-liker', name: 'Thor');
  final like = _makeLike(likerDog);
  final otherLike = _makeLike(otherLikerDog, myAction: 'PASS');
  final match = MatchModel(
    id: 'match-1',
    createdAt: DateTime.utc(2026, 3, 1),
    myDog: myDog,
    otherDog: likerDog,
    otherOwner: const MatchOwnerModel(id: 'owner-liker-dog', name: 'Tutora'),
  );

  late MockLikesRepository likesRepository;
  late MockDiscoveryRepository discoveryRepository;
  late MockDogRepository dogRepository;
  late ActiveDogCubit activeDogCubit;

  setUp(() {
    likesRepository = MockLikesRepository();
    discoveryRepository = MockDiscoveryRepository();
    dogRepository = MockDogRepository();
    when(() => dogRepository.getMyDogs()).thenAnswer((_) async => [myDog]);
    activeDogCubit = ActiveDogCubit(dogRepository);
  });

  tearDown(() async {
    await activeDogCubit.close();
  });

  LikesCubit buildCubit() =>
      LikesCubit(likesRepository, discoveryRepository, activeDogCubit);

  group('LikesCubit', () {
    test('load lista as curtidas recebidas pelo cão ativo', () async {
      when(() => likesRepository.getReceived(dogId: myDog.id)).thenAnswer(
        (_) async =>
            LikesReceivedModel(items: [like, otherLike], total: 2),
      );

      final cubit = buildCubit();
      await cubit.load();
      await pumpEventQueue();

      expect(cubit.state.status, LikesStatus.loaded);
      expect(cubit.state.likes, [like, otherLike]);
      expect(cubit.state.activeDogId, myDog.id);
      await cubit.close();
    });

    test('load emite erro com a mensagem pronta da ApiException', () async {
      when(() => likesRepository.getReceived(dogId: myDog.id))
          .thenThrow(const ApiException('Erro no servidor.'));

      final cubit = buildCubit();
      await cubit.load();
      await pumpEventQueue();

      expect(cubit.state.status, LikesStatus.error);
      expect(cubit.state.errorMessage, 'Erro no servidor.');
      await cubit.close();
    });

    test(
        'likeBack com match remove a curtida da lista e agenda o '
        'MatchDialog', () async {
      when(() => likesRepository.getReceived(dogId: myDog.id)).thenAnswer(
        (_) async =>
            LikesReceivedModel(items: [like, otherLike], total: 2),
      );
      when(
        () => discoveryRepository.swipe(
          swiperDogId: myDog.id,
          targetDogId: likerDog.id,
          action: SwipeAction.like,
        ),
      ).thenAnswer((_) async => SwipeResultModel(matched: true, match: match));

      final cubit = buildCubit();
      await cubit.load();
      await pumpEventQueue();

      await cubit.likeBack(like);

      expect(cubit.state.likes, [otherLike]);
      expect(cubit.state.pendingMatch, match);
      expect(cubit.state.likingBackDogIds, isEmpty);
      verify(
        () => discoveryRepository.swipe(
          swiperDogId: myDog.id,
          targetDogId: likerDog.id,
          action: SwipeAction.like,
        ),
      ).called(1);
      await cubit.close();
    });

    test(
        'likeBack com erro mantém a curtida na lista e expõe o erro '
        'transitório', () async {
      when(() => likesRepository.getReceived(dogId: myDog.id)).thenAnswer(
        (_) async => LikesReceivedModel(items: [like], total: 1),
      );
      when(
        () => discoveryRepository.swipe(
          swiperDogId: myDog.id,
          targetDogId: likerDog.id,
          action: SwipeAction.like,
        ),
      ).thenThrow(const ApiException('Sem conexão.'));

      final cubit = buildCubit();
      await cubit.load();
      await pumpEventQueue();

      await cubit.likeBack(like);

      expect(cubit.state.likes, [like]);
      expect(cubit.state.pendingMatch, isNull);
      expect(cubit.state.actionError, 'Sem conexão.');
      expect(cubit.state.likingBackDogIds, isEmpty);
      await cubit.close();
    });

    test('removeByDogId tira a curtida resolvida no detalhe', () async {
      when(() => likesRepository.getReceived(dogId: myDog.id)).thenAnswer(
        (_) async =>
            LikesReceivedModel(items: [like, otherLike], total: 2),
      );

      final cubit = buildCubit();
      await cubit.load();
      await pumpEventQueue();

      cubit.removeByDogId(likerDog.id);

      expect(cubit.state.likes, [otherLike]);
      await cubit.close();
    });
  });
}
