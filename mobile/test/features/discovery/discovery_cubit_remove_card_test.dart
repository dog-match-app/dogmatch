import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dogmatch/core/services/location_service.dart';
import 'package:dogmatch/features/auth/data/models/user_model.dart';
import 'package:dogmatch/features/discovery/data/models/discovery_card_model.dart';
import 'package:dogmatch/features/discovery/data/models/swipe_result_model.dart';
import 'package:dogmatch/features/discovery/domain/entities/swipe_action.dart';
import 'package:dogmatch/features/discovery/domain/repositories/discovery_repository.dart';
import 'package:dogmatch/features/discovery/presentation/cubit/active_dog_cubit.dart';
import 'package:dogmatch/features/discovery/presentation/cubit/discovery_cubit.dart';
import 'package:dogmatch/features/dogs/data/models/dog_model.dart';
import 'package:dogmatch/features/dogs/domain/entities/dog_enums.dart';
import 'package:dogmatch/features/dogs/domain/repositories/dog_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDiscoveryRepository extends Mock implements DiscoveryRepository {}

class MockDogRepository extends Mock implements DogRepository {}

class MockLocationService extends Mock implements LocationService {}

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

DiscoveryCardModel _makeCard(String dogId, {String name = 'Luna'}) =>
    DiscoveryCardModel(
      dog: _makeDog(dogId, name: name),
      distanceKm: 2.3,
      owner: DiscoveryOwnerModel(id: 'owner-$dogId', name: 'Tutora'),
    );

void main() {
  final myDog = _makeDog('my-dog', name: 'Bidu');
  final card1 = _makeCard('dog-1', name: 'Luna');
  final card2 = _makeCard('dog-2', name: 'Thor');
  final card3 = _makeCard('dog-3', name: 'Mel');

  late MockDiscoveryRepository discoveryRepository;
  late MockDogRepository dogRepository;
  late ActiveDogCubit activeDogCubit;
  late MockLocationService locationService;
  late StreamController<UserModel> locationSyncController;

  setUp(() {
    discoveryRepository = MockDiscoveryRepository();
    dogRepository = MockDogRepository();
    locationService = MockLocationService();
    locationSyncController = StreamController<UserModel>.broadcast();
    when(
      () => locationService.onLocationSynced,
    ).thenAnswer((_) => locationSyncController.stream);
    when(() => dogRepository.getMyDogs()).thenAnswer((_) async => [myDog]);
    activeDogCubit = ActiveDogCubit(dogRepository);
  });

  tearDown(() async {
    await locationSyncController.close();
    await activeDogCubit.close();
  });

  DiscoveryCubit buildCubit() =>
      DiscoveryCubit(discoveryRepository, activeDogCubit, locationService);

  group('DiscoveryCubit.removeCard — like/pass feito dentro do detalhe', () {
    blocTest<DiscoveryCubit, DiscoveryState>(
      'remove o card certo e recria o deck (deckKey incrementado)',
      build: buildCubit,
      seed: () => DiscoveryState(
        status: DiscoveryStatus.loaded,
        activeDog: myDog,
        cards: [card1, card2, card3],
        deckKey: 1,
      ),
      act: (cubit) => cubit.removeCard(card2.dog.id),
      expect: () => [
        DiscoveryState(
          status: DiscoveryStatus.loaded,
          activeDog: myDog,
          cards: [card1, card3],
          deckKey: 2,
        ),
      ],
      verify: (_) {
        verifyNever(
          () => discoveryRepository.getFeed(dogId: any(named: 'dogId')),
        );
      },
    );

    blocTest<DiscoveryCubit, DiscoveryState>(
      'id inexistente no deck não emite nada nem recarrega o feed',
      build: buildCubit,
      seed: () => DiscoveryState(
        status: DiscoveryStatus.loaded,
        activeDog: myDog,
        cards: [card1],
        deckKey: 1,
      ),
      act: (cubit) => cubit.removeCard('dog-fantasma'),
      expect: () => const <DiscoveryState>[],
      verify: (_) {
        verifyNever(
          () => discoveryRepository.getFeed(dogId: any(named: 'dogId')),
        );
      },
    );

    blocTest<DiscoveryCubit, DiscoveryState>(
      'fora do estado loaded, removeCard é no-op',
      build: buildCubit,
      seed: () => DiscoveryState(
        status: DiscoveryStatus.loading,
        activeDog: myDog,
        cards: [card1],
      ),
      act: (cubit) => cubit.removeCard(card1.dog.id),
      expect: () => const <DiscoveryState>[],
    );

    blocTest<DiscoveryCubit, DiscoveryState>(
      'deck recriado não ressuscita cards já swipados fisicamente',
      build: () {
        when(
          () => discoveryRepository.swipe(
            swiperDogId: myDog.id,
            targetDogId: card1.dog.id,
            action: SwipeAction.like,
          ),
        ).thenAnswer((_) async => const SwipeResultModel(matched: false));
        return buildCubit();
      },
      seed: () => DiscoveryState(
        status: DiscoveryStatus.loaded,
        activeDog: myDog,
        cards: [card1, card2, card3],
        deckKey: 1,
      ),
      act: (cubit) async {
        // card1 saiu pelo swipe físico (CardSwiper avança o índice interno
        // sem mexer em state.cards); o detalhe foi aberto no card2.
        await cubit.onSwiped(card1, SwipeAction.like);
        await cubit.removeCard(card2.dog.id);
      },
      expect: () => [
        DiscoveryState(
          status: DiscoveryStatus.loaded,
          activeDog: myDog,
          cards: [card3],
          deckKey: 2,
        ),
      ],
    );

    blocTest<DiscoveryCubit, DiscoveryState>(
      'deck vazio após remover o último segue o fim de deck (recarrega e '
      'cai no estado vazio quando o feed não devolve cards)',
      build: () {
        when(
          () => discoveryRepository.getFeed(dogId: myDog.id),
        ).thenAnswer((_) async => <DiscoveryCardModel>[]);
        return buildCubit();
      },
      seed: () => DiscoveryState(
        status: DiscoveryStatus.loaded,
        activeDog: myDog,
        cards: [card1],
        deckKey: 1,
      ),
      act: (cubit) => cubit.removeCard(card1.dog.id),
      expect: () => [
        DiscoveryState(
          status: DiscoveryStatus.loading,
          activeDog: myDog,
          cards: [card1],
          deckKey: 1,
        ),
        DiscoveryState(
          status: DiscoveryStatus.loaded,
          activeDog: myDog,
          cards: const [],
          deckKey: 2,
        ),
      ],
      verify: (_) {
        verify(() => discoveryRepository.getFeed(dogId: myDog.id)).called(1);
      },
    );
  });
}
