import 'package:dogmatch/core/error/api_exception.dart';
import 'package:dogmatch/features/dogs/data/models/dog_model.dart';
import 'package:dogmatch/features/dogs/domain/repositories/dog_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

part 'active_dog_state.dart';

/// Fonte única do "cão ativo": a lista dos meus cães e qual deles está
/// selecionado. Discovery, busca, matches e detalhe consomem esta seleção —
/// nenhum outro cubit guarda a escolha nem carrega a lista por conta própria.
@lazySingleton
class ActiveDogCubit extends Cubit<ActiveDogState> {
  ActiveDogCubit(this._dogRepository) : super(const ActiveDogState());

  final DogRepository _dogRepository;

  Future<void>? _inFlight;

  /// Incrementado a cada [reset]: cargas da sessão anterior ainda em voo
  /// são descartadas ao completar (nada da conta antiga pode ser emitido).
  int _generation = 0;

  /// Carrega a lista só na primeira vez (as telas chamam a cada abertura).
  Future<void> ensureLoaded() {
    if (state.status == ActiveDogStatus.ready) return Future<void>.value();
    return refresh();
  }

  /// Recarrega a lista preservando a seleção. Chamadas concorrentes
  /// compartilham a mesma requisição.
  Future<void> refresh() {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;
    late final Future<void> request;
    request = _load().whenComplete(() {
      // Após um reset no meio da carga, o in-flight já é de outra sessão —
      // só o próprio request pode se desregistrar.
      if (identical(_inFlight, request)) _inFlight = null;
    });
    _inFlight = request;
    return request;
  }

  void select(DogModel dog) {
    if (dog.id == state.active?.id) return;
    emit(state.copyWith(active: dog));
  }

  /// Encerramento de sessão (logout/expirada): volta ao estado inicial para
  /// nenhum cão da conta anterior vazar na conta seguinte — sem isto o
  /// Descobrir consultava o feed com o `dogId` antigo e levava 403. Chamado
  /// apenas pelo ponto único de reset da sessão (`SessionReset`).
  void reset() {
    _generation++;
    _inFlight = null;
    emit(const ActiveDogState());
  }

  Future<void> _load() async {
    final generation = _generation;
    emit(state.copyWith(status: ActiveDogStatus.loading));
    try {
      final dogs = await _dogRepository.getMyDogs();
      if (isClosed || generation != _generation) return;
      final selectedId = state.active?.id;
      emit(
        ActiveDogState(
          status: ActiveDogStatus.ready,
          dogs: dogs,
          active: dogs.isEmpty
              ? null
              : dogs.firstWhere(
                  (dog) => dog.id == selectedId,
                  orElse: () => dogs.first,
                ),
        ),
      );
    } on ApiException catch (exception) {
      if (isClosed || generation != _generation) return;
      emit(
        state.copyWith(
          status: ActiveDogStatus.error,
          message: exception.message,
        ),
      );
    }
  }
}
