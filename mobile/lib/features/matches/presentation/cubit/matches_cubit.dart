import 'dart:async';

import 'package:dogmatch/core/error/api_exception.dart';
import 'package:dogmatch/features/discovery/presentation/cubit/active_dog_cubit.dart';
import 'package:dogmatch/features/matches/data/models/match_model.dart';
import 'package:dogmatch/features/matches/domain/repositories/match_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

part 'matches_state.dart';

/// Lista os matches do cão ativo (mesma seleção do Discovery) e refaz o
/// fetch quando a seleção muda.
@injectable
class MatchesCubit extends Cubit<MatchesState> {
  MatchesCubit(
    this._matchRepository,
    this._activeDogCubit,
  ) : super(const MatchesState()) {
    _activeDogSubscription = _activeDogCubit.stream.listen((activeState) {
      final dog = activeState.active;
      if (dog != null && dog.id != state.activeDogId) load();
    });
  }

  final MatchRepository _matchRepository;
  final ActiveDogCubit _activeDogCubit;

  late final StreamSubscription<ActiveDogState> _activeDogSubscription;

  /// Descarta respostas obsoletas quando o cão troca durante o fetch.
  int _requestId = 0;

  Future<void> load() async {
    final requestId = ++_requestId;
    emit(state.copyWith(status: MatchesStatus.loading));
    await _activeDogCubit.ensureLoaded();
    if (isClosed || requestId != _requestId) return;
    final activeState = _activeDogCubit.state;
    if (activeState.status == ActiveDogStatus.error) {
      emit(
        state.copyWith(
          status: MatchesStatus.error,
          errorMessage: activeState.message,
        ),
      );
      return;
    }
    final activeDog = activeState.active;
    if (activeDog == null) {
      emit(state.copyWith(status: MatchesStatus.loaded, matches: []));
      return;
    }
    emit(state.copyWith(activeDogId: activeDog.id));
    try {
      final matches = await _matchRepository.getMatches(dogId: activeDog.id);
      if (isClosed || requestId != _requestId) return;
      emit(state.copyWith(status: MatchesStatus.loaded, matches: matches));
    } on ApiException catch (exception) {
      if (isClosed || requestId != _requestId) return;
      emit(
        state.copyWith(
          status: MatchesStatus.error,
          errorMessage: exception.message,
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    await _activeDogSubscription.cancel();
    return super.close();
  }
}
