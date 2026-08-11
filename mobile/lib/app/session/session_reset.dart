import 'package:dogmatch/core/services/location_service.dart';
import 'package:dogmatch/features/discovery/presentation/cubit/active_dog_cubit.dart';
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
///   convite da aba Matches e pedido único de permissão).
///
/// Tokens e socket não entram aqui: o `AuthBloc`/`AuthRepository` já limpam
/// ambos nos fluxos de logout/expiração.
@lazySingleton
class SessionReset {
  SessionReset(this._activeDogCubit, this._locationService);

  final ActiveDogCubit _activeDogCubit;
  final LocationService _locationService;

  void resetSession() {
    _activeDogCubit.reset();
    _locationService.endSession();
  }
}
