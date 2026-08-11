import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dogmatch/core/services/location_service.dart';
import 'package:dogmatch/features/auth/data/models/user_model.dart';
import 'package:dogmatch/features/discovery/data/models/discovery_card_model.dart';
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

void main() {
  final myDog = _makeDog('my-dog', name: 'Bidu');
  final card = DiscoveryCardModel(
    dog: _makeDog('dog-1', name: 'Luna'),
    distanceKm: 2.3,
    owner: const DiscoveryOwnerModel(id: 'owner-dog-1', name: 'Tutora'),
  );
  final user = UserModel(
    id: 'user-1',
    email: 'ana@demo.com',
    name: 'Ana',
    latitude: -23.5505,
    longitude: -46.6333,
    createdAt: DateTime.utc(2026),
  );

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
    when(() => locationService.onLocationSynced)
        .thenAnswer((_) => locationSyncController.stream);
    when(() => dogRepository.getMyDogs()).thenAnswer((_) async => [myDog]);
    activeDogCubit = ActiveDogCubit(dogRepository);
  });

  tearDown(() async {
    await locationSyncController.close();
    await activeDogCubit.close();
  });

  DiscoveryCubit buildCubit() =>
      DiscoveryCubit(discoveryRepository, activeDogCubit, locationService);

  group('DiscoveryCubit — localização sincronizada', () {
    blocTest<DiscoveryCubit, DiscoveryState>(
      'em locationRequired, recarrega o deck ao receber onLocationSynced',
      build: () {
        when(() => discoveryRepository.getFeed(dogId: myDog.id))
            .thenAnswer((_) async => [card]);
        return buildCubit();
      },
      seed: () => DiscoveryState(
        status: DiscoveryStatus.locationRequired,
        activeDog: myDog,
      ),
      act: (cubit) async {
        locationSyncController.add(user);
        await cubit.stream
            .firstWhere((state) => state.status == DiscoveryStatus.loaded);
      },
      expect: () => [
        DiscoveryState(status: DiscoveryStatus.loading, activeDog: myDog),
        DiscoveryState(
          status: DiscoveryStatus.loaded,
          activeDog: myDog,
          cards: [card],
          deckKey: 1,
        ),
      ],
      verify: (_) {
        verify(() => discoveryRepository.getFeed(dogId: myDog.id)).called(1);
      },
    );

    blocTest<DiscoveryCubit, DiscoveryState>(
      'fora de locationRequired, onLocationSynced não refaz o feed',
      build: buildCubit,
      seed: () => DiscoveryState(
        status: DiscoveryStatus.loaded,
        activeDog: myDog,
        cards: [card],
        deckKey: 1,
      ),
      act: (cubit) => locationSyncController.add(user),
      wait: const Duration(milliseconds: 50),
      expect: () => const <DiscoveryState>[],
      verify: (_) {
        verifyNever(
          () => discoveryRepository.getFeed(dogId: any(named: 'dogId')),
        );
      },
    );
  });
}
