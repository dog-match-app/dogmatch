import 'package:dogmatch/app/session/session_reset.dart';
import 'package:dogmatch/core/services/location_service.dart';
import 'package:dogmatch/features/discovery/presentation/cubit/active_dog_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockActiveDogCubit extends Mock implements ActiveDogCubit {}

class MockLocationService extends Mock implements LocationService {}

void main() {
  test(
      'resetSession limpa TODO estado por-conta: cão ativo e sessão de '
      'localização', () {
    final activeDogCubit = MockActiveDogCubit();
    final locationService = MockLocationService();

    SessionReset(activeDogCubit, locationService).resetSession();

    verify(() => activeDogCubit.reset()).called(1);
    verify(() => locationService.endSession()).called(1);
    verifyNoMoreInteractions(activeDogCubit);
    verifyNoMoreInteractions(locationService);
  });
}
