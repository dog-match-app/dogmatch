import 'dart:async';

import 'package:dogmatch/core/error/api_exception.dart';
import 'package:dogmatch/features/discovery/presentation/cubit/active_dog_cubit.dart';
import 'package:dogmatch/features/dogs/data/models/dog_model.dart';
import 'package:dogmatch/features/dogs/domain/repositories/dog_repository.dart';
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
    this._dogRepository,
    this._activeDogCubit,
  ) : super(const MatchesState()) {
    _activeDogSubscription = _activeDogCubit.stream.listen((dog) {
      if (dog != null && dog.id != state.activeDogId) load();
    });
  }

  final MatchRepository _matchRepository;
  final DogRepository _dogRepository;
  final ActiveDogCubit _activeDogCubit;

  late final StreamSubscription<DogModel?> _activeDogSubscription;

  Future<void> load() async {
    emit(state.copyWith(status: MatchesStatus.loading));
    try {
      var activeDog = _activeDogCubit.state;
      if (activeDog == null) {
        final dogs = await _dogRepository.getMyDogs();
        if (dogs.isEmpty) {
          emit(state.copyWith(status: MatchesStatus.loaded, matches: []));
          return;
        }
        activeDog = dogs.first;
        // Atualiza o id antes do select para o listener não recarregar.
        emit(state.copyWith(activeDogId: activeDog.id));
        _activeDogCubit.select(activeDog);
      } else {
        emit(state.copyWith(activeDogId: activeDog.id));
      }
      final matches = await _matchRepository.getMatches(dogId: activeDog.id);
      emit(state.copyWith(status: MatchesStatus.loaded, matches: matches));
    } on ApiException catch (exception) {
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
