import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dogmatch/core/services/location_service.dart';
import 'package:dogmatch/core/storage/app_preferences.dart';
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

class MockAppPreferences extends Mock implements AppPreferences {}

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

  late MockDiscoveryRepository discoveryRepository;
  late MockDogRepository dogRepository;
  late ActiveDogCubit activeDogCubit;
  late MockLocationService locationService;
  late MockAppPreferences appPreferences;
  late StreamController<UserModel> locationSyncController;

  setUp(() {
    discoveryRepository = MockDiscoveryRepository();
    dogRepository = MockDogRepository();
    locationService = MockLocationService();
    appPreferences = MockAppPreferences();
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

  DiscoveryCubit buildCubit() => DiscoveryCubit(
        discoveryRepository,
        activeDogCubit,
        locationService,
        appPreferences,
      );

  group('DiscoveryCubit — raio máximo configurável', () {
    test('init usa o raio persistido no GET /discovery', () async {
      when(() => appPreferences.getDiscoveryRadiusKm())
          .thenAnswer((_) async => 120);
      when(
        () => discoveryRepository.getFeed(dogId: myDog.id, radiusKm: 120),
      ).thenAnswer((_) async => [card]);

      final cubit = buildCubit();
      await cubit.init();
      // O feed dispara pelo listener do cão ativo; aguarda a fila esvaziar.
      await pumpEventQueue();

      expect(cubit.state.status, DiscoveryStatus.loaded);
      expect(cubit.state.radiusKm, 120);
      expect(cubit.state.cards, [card]);
      verify(
        () => discoveryRepository.getFeed(dogId: myDog.id, radiusKm: 120),
      ).called(1);
      await cubit.close();
    });

    test('sem preferência salva, init mantém o padrão do backend (50 km)',
        () async {
      when(() => appPreferences.getDiscoveryRadiusKm())
          .thenAnswer((_) async => null);
      when(
        () => discoveryRepository.getFeed(
          dogId: myDog.id,
          radiusKm: DiscoveryState.defaultRadiusKm,
        ),
      ).thenAnswer((_) async => [card]);

      final cubit = buildCubit();
      await cubit.init();
      await pumpEventQueue();

      expect(cubit.state.radiusKm, DiscoveryState.defaultRadiusKm);
      verify(
        () => discoveryRepository.getFeed(
          dogId: myDog.id,
          radiusKm: DiscoveryState.defaultRadiusKm,
        ),
      ).called(1);
      await cubit.close();
    });

    blocTest<DiscoveryCubit, DiscoveryState>(
      'trocar o raio persiste a preferência e recarrega o deck',
      build: () {
        when(() => appPreferences.setDiscoveryRadiusKm(any()))
            .thenAnswer((_) async {});
        when(
          () => discoveryRepository.getFeed(dogId: myDog.id, radiusKm: 25),
        ).thenAnswer((_) async => [card]);
        return buildCubit();
      },
      seed: () => DiscoveryState(
        status: DiscoveryStatus.loaded,
        activeDog: myDog,
        deckKey: 1,
      ),
      act: (cubit) => cubit.changeRadius(25),
      expect: () => [
        DiscoveryState(
          status: DiscoveryStatus.loaded,
          activeDog: myDog,
          deckKey: 1,
          radiusKm: 25,
        ),
        DiscoveryState(
          status: DiscoveryStatus.loading,
          activeDog: myDog,
          deckKey: 1,
          radiusKm: 25,
        ),
        DiscoveryState(
          status: DiscoveryStatus.loaded,
          activeDog: myDog,
          cards: [card],
          deckKey: 2,
          radiusKm: 25,
        ),
      ],
      verify: (_) {
        verify(() => appPreferences.setDiscoveryRadiusKm(25)).called(1);
        verify(
          () => discoveryRepository.getFeed(dogId: myDog.id, radiusKm: 25),
        ).called(1);
      },
    );

    blocTest<DiscoveryCubit, DiscoveryState>(
      'aplicar o mesmo raio é no-op (não persiste nem recarrega)',
      build: buildCubit,
      seed: () => DiscoveryState(
        status: DiscoveryStatus.loaded,
        activeDog: myDog,
        deckKey: 1,
      ),
      act: (cubit) => cubit.changeRadius(DiscoveryState.defaultRadiusKm),
      expect: () => const <DiscoveryState>[],
      verify: (_) {
        verifyNever(() => appPreferences.setDiscoveryRadiusKm(any()));
        verifyNever(
          () => discoveryRepository.getFeed(
            dogId: any(named: 'dogId'),
            radiusKm: any(named: 'radiusKm'),
          ),
        );
      },
    );
  });
}
