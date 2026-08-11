import 'package:dogmatch/features/discovery/data/models/swipe_result_model.dart';
import 'package:dogmatch/features/discovery/domain/entities/swipe_action.dart';
import 'package:dogmatch/features/discovery/domain/repositories/discovery_repository.dart';
import 'package:dogmatch/features/discovery/presentation/cubit/active_dog_cubit.dart';
import 'package:dogmatch/features/dogs/data/models/dog_model.dart';
import 'package:dogmatch/features/dogs/data/models/dog_owner_model.dart';
import 'package:dogmatch/features/dogs/domain/entities/dog_enums.dart';
import 'package:dogmatch/features/dogs/domain/repositories/dog_repository.dart';
import 'package:dogmatch/features/matches/data/models/match_model.dart';
import 'package:dogmatch/features/matches/domain/repositories/match_repository.dart';
import 'package:dogmatch/features/search/data/models/search_card_model.dart';
import 'package:dogmatch/features/search/presentation/cubit/dog_detail_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDogRepository extends Mock implements DogRepository {}

class MockDiscoveryRepository extends Mock implements DiscoveryRepository {}

class MockMatchRepository extends Mock implements MatchRepository {}

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

void main() {
  final myDog = _makeDog('my-dog', name: 'Bidu');
  final targetDog = _makeDog('dog-1', name: 'Luna');

  SearchCardModel makeCard({String? myAction}) => SearchCardModel(
        dog: targetDog,
        owner: const DogOwnerModel(id: 'owner-dog-1', name: 'Tutora'),
        myAction: myAction,
        matched: false,
      );

  late MockDogRepository dogRepository;
  late MockDiscoveryRepository discoveryRepository;
  late MockMatchRepository matchRepository;
  late ActiveDogCubit activeDogCubit;

  setUpAll(() => registerFallbackValue(SwipeAction.like));

  setUp(() {
    dogRepository = MockDogRepository();
    discoveryRepository = MockDiscoveryRepository();
    matchRepository = MockMatchRepository();
    when(() => dogRepository.getMyDogs()).thenAnswer((_) async => [myDog]);
    activeDogCubit = ActiveDogCubit(dogRepository);
  });

  tearDown(() => activeDogCubit.close());

  DogDetailCubit buildCubit() => DogDetailCubit(
        dogRepository,
        discoveryRepository,
        matchRepository,
        activeDogCubit,
      );

  group('DogDetailCubit — curtir sobre um PASS (desfazer pass acidental)',
      () {
    test('like com myAction PASS é permitido e atualiza o card para LIKE',
        () async {
      when(
        () => discoveryRepository.swipe(
          swiperDogId: myDog.id,
          targetDogId: targetDog.id,
          action: SwipeAction.like,
        ),
      ).thenAnswer((_) async => const SwipeResultModel(matched: false));

      final cubit = buildCubit();
      await cubit.init(
        dogId: targetDog.id,
        card: makeCard(myAction: SearchCardModel.passAction),
      );
      expect(cubit.state.card?.isPassed, isTrue);

      await cubit.swipe(SwipeAction.like);

      expect(cubit.state.card?.myAction, SearchCardModel.likeAction);
      expect(cubit.state.card?.isLiked, isTrue);
      expect(cubit.state.card?.isPassed, isFalse);
      verify(
        () => discoveryRepository.swipe(
          swiperDogId: myDog.id,
          targetDogId: targetDog.id,
          action: SwipeAction.like,
        ),
      ).called(1);
      await cubit.close();
    });

    test('re-swipe PASS→LIKE com like recíproco agenda o dialog de match',
        () async {
      final match = MatchModel(
        id: 'match-1',
        createdAt: DateTime.utc(2026),
        myDog: myDog,
        otherDog: targetDog,
        otherOwner: const MatchOwnerModel(id: 'owner-dog-1', name: 'Tutora'),
      );
      when(
        () => discoveryRepository.swipe(
          swiperDogId: myDog.id,
          targetDogId: targetDog.id,
          action: SwipeAction.like,
        ),
      ).thenAnswer(
        (_) async => SwipeResultModel(matched: true, match: match),
      );

      final cubit = buildCubit();
      await cubit.init(
        dogId: targetDog.id,
        card: makeCard(myAction: SearchCardModel.passAction),
      );
      await cubit.swipe(SwipeAction.like);

      expect(cubit.state.card?.isMatched, isTrue);
      expect(cubit.state.pendingMatch, match);
      await cubit.close();
    });

    test('já curtido ⇒ swipe é bloqueado (não repete o like)', () async {
      final cubit = buildCubit();
      await cubit.init(
        dogId: targetDog.id,
        card: makeCard(myAction: SearchCardModel.likeAction),
      );

      await cubit.swipe(SwipeAction.like);

      expect(cubit.state.card?.myAction, SearchCardModel.likeAction);
      verifyNever(
        () => discoveryRepository.swipe(
          swiperDogId: any(named: 'swiperDogId'),
          targetDogId: any(named: 'targetDogId'),
          action: any(named: 'action'),
        ),
      );
      await cubit.close();
    });
  });
}
