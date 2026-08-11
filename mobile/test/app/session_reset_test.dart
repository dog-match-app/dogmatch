import 'package:dogmatch/app/session/session_reset.dart';
import 'package:dogmatch/core/services/app_notifications_service.dart';
import 'package:dogmatch/core/services/location_service.dart';
import 'package:dogmatch/core/services/realtime_service.dart';
import 'package:dogmatch/features/discovery/presentation/cubit/active_dog_cubit.dart';
import 'package:dogmatch/features/matches/presentation/cubit/activity_badge_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockActiveDogCubit extends Mock implements ActiveDogCubit {}

class MockLocationService extends Mock implements LocationService {}

class MockRealtimeService extends Mock implements RealtimeService {}

class MockActivityBadgeCubit extends Mock implements ActivityBadgeCubit {}

class MockAppNotificationsService extends Mock
    implements AppNotificationsService {}

void main() {
  test(
      'resetSession limpa TODO estado por-conta: cão ativo, localização, '
      'socket da sessão, badge de atividade e notificações', () {
    final activeDogCubit = MockActiveDogCubit();
    final locationService = MockLocationService();
    final realtimeService = MockRealtimeService();
    final activityBadgeCubit = MockActivityBadgeCubit();
    final notificationsService = MockAppNotificationsService();

    SessionReset(
      activeDogCubit,
      locationService,
      realtimeService,
      activityBadgeCubit,
      notificationsService,
    ).resetSession();

    verify(() => activeDogCubit.reset()).called(1);
    verify(() => locationService.endSession()).called(1);
    verify(() => realtimeService.stop()).called(1);
    verify(() => activityBadgeCubit.reset()).called(1);
    verify(() => notificationsService.resetSession()).called(1);
    verifyNoMoreInteractions(activeDogCubit);
    verifyNoMoreInteractions(locationService);
    verifyNoMoreInteractions(realtimeService);
    verifyNoMoreInteractions(activityBadgeCubit);
    verifyNoMoreInteractions(notificationsService);
  });
}
