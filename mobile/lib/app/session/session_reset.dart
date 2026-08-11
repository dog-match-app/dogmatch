import 'package:dogmatch/core/services/app_notifications_service.dart';
import 'package:dogmatch/core/services/location_service.dart';
import 'package:dogmatch/core/services/realtime_service.dart';
import 'package:dogmatch/features/discovery/presentation/cubit/active_dog_cubit.dart';
import 'package:dogmatch/features/matches/presentation/cubit/activity_badge_cubit.dart';
import 'package:injectable/injectable.dart';

/// Ponto ÚNICO de limpeza do estado por-conta ao encerrar a sessão (logout
/// ou expiração), chamado pelo listener de auth do `app.dart`. Todo
/// singleton que guarda dados do usuário logado é resetado AQUI — nunca
/// espalhe resets por telas ou features.
///
/// Hoje cobre:
/// - [ActiveDogCubit]: lista + seleção de cães — sem o reset, o Descobrir da
///   conta seguinte consultava `GET /discovery` com o cão da conta anterior
///   e recebia 403 ("você não tem permissão");
/// - [LocationService]: flags de sessão (throttle do sync automático,
///   convite da aba Matches e pedido único de permissão);
/// - [RealtimeService]: derruba o socket da sessão e limpa rooms/dedup;
/// - [ActivityBadgeCubit]: zera o badge de atividade da conta anterior;
/// - [AppNotificationsService]: registros de tela ativa + flag do pedido
///   único de permissão.
///
/// Tokens não entram aqui: o `AuthBloc`/`AuthRepository` já os limpam nos
/// fluxos de logout/expiração.
@lazySingleton
class SessionReset {
  SessionReset(
    this._activeDogCubit,
    this._locationService,
    this._realtimeService,
    this._activityBadgeCubit,
    this._notificationsService,
  );

  final ActiveDogCubit _activeDogCubit;
  final LocationService _locationService;
  final RealtimeService _realtimeService;
  final ActivityBadgeCubit _activityBadgeCubit;
  final AppNotificationsService _notificationsService;

  void resetSession() {
    _activeDogCubit.reset();
    _locationService.endSession();
    _realtimeService.stop();
    _activityBadgeCubit.reset();
    _notificationsService.resetSession();
  }
}
