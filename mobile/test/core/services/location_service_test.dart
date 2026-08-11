import 'package:dogmatch/core/error/api_exception.dart';
import 'package:dogmatch/core/services/location_service.dart';
import 'package:dogmatch/features/auth/data/models/user_model.dart';
import 'package:dogmatch/features/profile/domain/repositories/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mocktail/mocktail.dart';

class MockLocationGateway extends Mock implements LocationGateway {}

class MockProfileRepository extends Mock implements ProfileRepository {}

final _position = Position(
  latitude: -23.5505,
  longitude: -46.6333,
  timestamp: DateTime.utc(2026, 8, 10),
  accuracy: 10,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

final _user = UserModel(
  id: 'user-1',
  email: 'ana@demo.com',
  name: 'Ana',
  latitude: -23.5505,
  longitude: -46.6333,
  createdAt: DateTime.utc(2026),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockLocationGateway gateway;
  late MockProfileRepository profileRepository;
  late LocationService service;

  setUp(() {
    gateway = MockLocationGateway();
    profileRepository = MockProfileRepository();
    service = LocationService(gateway, profileRepository);
  });

  tearDown(() => service.dispose());

  void stubPermission(LocationPermission permission) {
    when(() => gateway.checkPermission()).thenAnswer((_) async => permission);
  }

  void stubSuccessfulSync() {
    when(() => gateway.isLocationServiceEnabled())
        .thenAnswer((_) async => true);
    when(() => gateway.getCurrentPosition())
        .thenAnswer((_) async => _position);
    when(
      () => profileRepository.updateProfile(
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
      ),
    ).thenAnswer((_) async => _user);
  }

  group('LocationService', () {
    test('permissão concedida ⇒ sincroniza uma única vez por sessão',
        () async {
      stubPermission(LocationPermission.whileInUse);
      stubSuccessfulSync();

      final first = await service.syncToProfile();
      final second = await service.syncToProfile();

      expect(first.status, LocationSyncStatus.synced);
      expect(first.user, _user);
      expect(second.status, LocationSyncStatus.synced);
      verify(
        () => profileRepository.updateProfile(
          latitude: _position.latitude,
          longitude: _position.longitude,
        ),
      ).called(1);
    });

    test('refresh manual (force) sincroniza de novo na mesma sessão',
        () async {
      stubPermission(LocationPermission.always);
      stubSuccessfulSync();

      await service.syncToProfile();
      final result = await service.syncToProfile(force: true);

      expect(result.status, LocationSyncStatus.synced);
      verify(
        () => profileRepository.updateProfile(
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
        ),
      ).called(2);
    });

    test('permissão negada ⇒ syncToProfile não sincroniza nem pede permissão',
        () async {
      stubPermission(LocationPermission.denied);

      final result = await service.syncToProfile();

      expect(result.status, LocationSyncStatus.permissionDenied);
      expect(result.errorMessage, isNotNull);
      verifyNever(() => gateway.requestPermission());
      verifyNever(() => gateway.getCurrentPosition());
      verifyNever(
        () => profileRepository.updateProfile(
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
        ),
      );
    });

    test('permissão negada ⇒ ensurePermission pede via prompt do sistema',
        () async {
      stubPermission(LocationPermission.denied);
      when(() => gateway.requestPermission())
          .thenAnswer((_) async => LocationPermission.denied);

      final result = await service.ensurePermission();

      expect(result.status, LocationSyncStatus.permissionDenied);
      verify(() => gateway.requestPermission()).called(1);
      verifyNever(
        () => profileRepository.updateProfile(
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
        ),
      );
    });

    test('deniedForever ⇒ ensurePermission não abre o prompt do sistema e '
        'sinaliza configurações', () async {
      stubPermission(LocationPermission.deniedForever);

      final result = await service.ensurePermission();

      expect(result.status, LocationSyncStatus.permissionDeniedForever);
      expect(result.errorMessage, contains('configurações'));
      verifyNever(() => gateway.requestPermission());
    });

    test('onLocationSynced emite ao conceder a permissão pelo ensurePermission',
        () async {
      var permission = LocationPermission.denied;
      when(() => gateway.checkPermission())
          .thenAnswer((_) async => permission);
      when(() => gateway.requestPermission()).thenAnswer((_) async {
        permission = LocationPermission.whileInUse;
        return permission;
      });
      stubSuccessfulSync();

      final emitted = expectLater(service.onLocationSynced, emits(_user));
      final result = await service.ensurePermission();

      expect(result.status, LocationSyncStatus.synced);
      expect(result.user, _user);
      await emitted;
    });

    test('startSession sincroniza sozinho quando a permissão já existe',
        () async {
      stubPermission(LocationPermission.whileInUse);
      stubSuccessfulSync();

      final emitted = expectLater(service.onLocationSynced, emits(_user));
      service.startSession();
      await emitted;

      verify(
        () => profileRepository.updateProfile(
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
        ),
      ).called(1);
      service.endSession();
    });

    test('GPS desligado ⇒ serviceDisabled com mensagem própria', () async {
      stubPermission(LocationPermission.whileInUse);
      when(() => gateway.isLocationServiceEnabled())
          .thenAnswer((_) async => false);

      final result = await service.syncToProfile();

      expect(result.status, LocationSyncStatus.serviceDisabled);
      expect(result.errorMessage, contains('GPS'));
      verifyNever(() => gateway.getCurrentPosition());
    });

    test('falha do PATCH ⇒ error com a mensagem da ApiException', () async {
      stubPermission(LocationPermission.whileInUse);
      when(() => gateway.isLocationServiceEnabled())
          .thenAnswer((_) async => true);
      when(() => gateway.getCurrentPosition())
          .thenAnswer((_) async => _position);
      when(
        () => profileRepository.updateProfile(
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
        ),
      ).thenThrow(
        const ApiException(
          'Erro no servidor. Tente novamente mais tarde.',
          statusCode: 500,
        ),
      );

      final result = await service.syncToProfile();

      expect(result.status, LocationSyncStatus.error);
      expect(
        result.errorMessage,
        'Erro no servidor. Tente novamente mais tarde.',
      );

      // A falha não conta como sincronizada: a próxima tentativa refaz.
      stubSuccessfulSync();
      final retry = await service.syncToProfile();
      expect(retry.status, LocationSyncStatus.synced);
    });
  });
}
