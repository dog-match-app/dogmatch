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
    final request = _load().whenComplete(() => _inFlight = null);
    _inFlight = request;
    return request;
  }

  void select(DogModel dog) {
    if (dog.id == state.active?.id) return;
    emit(state.copyWith(active: dog));
  }

  Future<void> _load() async {
    emit(state.copyWith(status: ActiveDogStatus.loading));
    try {
      final dogs = await _dogRepository.getMyDogs();
      if (isClosed) return;
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
      if (isClosed) return;
      emit(
        state.copyWith(
          status: ActiveDogStatus.error,
          message: exception.message,
        ),
      );
    }
  }
}
