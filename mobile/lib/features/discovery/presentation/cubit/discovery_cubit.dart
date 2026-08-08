import 'package:dogmatch/core/error/api_exception.dart';
import 'package:dogmatch/features/discovery/data/models/discovery_card_model.dart';
import 'package:dogmatch/features/discovery/domain/entities/swipe_action.dart';
import 'package:dogmatch/features/discovery/domain/repositories/discovery_repository.dart';
import 'package:dogmatch/features/discovery/presentation/cubit/active_dog_cubit.dart';
import 'package:dogmatch/features/dogs/data/models/dog_model.dart';
import 'package:dogmatch/features/dogs/domain/repositories/dog_repository.dart';
import 'package:dogmatch/features/matches/data/models/match_model.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

part 'discovery_state.dart';

@injectable
class DiscoveryCubit extends Cubit<DiscoveryState> {
  DiscoveryCubit(
    this._dogRepository,
    this._discoveryRepository,
    this._activeDogCubit,
  ) : super(const DiscoveryState());

  final DogRepository _dogRepository;
  final DiscoveryRepository _discoveryRepository;
  final ActiveDogCubit _activeDogCubit;

  /// Swipes ainda não confirmados pela API (aguardados antes de recarregar
  /// o deck, para o feed não devolver cães já swipados).
  final Set<Future<void>> _pendingSwipes = {};

  Future<void> init() async {
    emit(state.copyWith(status: DiscoveryStatus.loading));
    try {
      final dogs = await _dogRepository.getMyDogs();
      if (dogs.isEmpty) {
        _activeDogCubit.select(null);
        emit(state.copyWith(status: DiscoveryStatus.noDogs, myDogs: []));
        return;
      }
      var active = _activeDogCubit.state;
      if (active == null || !dogs.any((dog) => dog.id == active?.id)) {
        active = dogs.first;
        _activeDogCubit.select(active);
      }
      emit(state.copyWith(myDogs: dogs, activeDog: active));
      await _loadFeed();
    } on ApiException catch (exception) {
      emit(
        state.copyWith(
          status: DiscoveryStatus.error,
          errorMessage: exception.message,
        ),
      );
    }
  }

  Future<void> selectDog(DogModel dog) async {
    if (dog.id == state.activeDog?.id) return;
    _activeDogCubit.select(dog);
    emit(state.copyWith(activeDog: dog));
    await _loadFeed();
  }

  Future<void> refreshDeck() => _loadFeed();

  /// Chamado pelo CardSwiper quando o deck acaba: busca a próxima leva.
  Future<void> onDeckFinished() async {
    await Future.wait(_pendingSwipes.toList());
    await _loadFeed();
  }

  Future<void> onSwiped(DiscoveryCardModel card, SwipeAction action) async {
    final activeDog = state.activeDog;
    if (activeDog == null) return;
    late final Future<void> pending;
    pending = _registerSwipe(activeDog.id, card, action)
        .whenComplete(() => _pendingSwipes.remove(pending));
    _pendingSwipes.add(pending);
    await pending;
  }

  void clearPendingMatch() => emit(state.copyWith());

  void clearSwipeError() => emit(state.copyWith());

  Future<void> _registerSwipe(
    String swiperDogId,
    DiscoveryCardModel card,
    SwipeAction action,
  ) async {
    try {
      final result = await _discoveryRepository.swipe(
        swiperDogId: swiperDogId,
        targetDogId: card.dog.id,
        action: action,
      );
      if (result.matched && result.match != null && !isClosed) {
        emit(state.copyWith(pendingMatch: result.match));
      }
    } on ApiException catch (exception) {
      if (!isClosed) emit(state.copyWith(swipeError: exception.message));
    }
  }

  Future<void> _loadFeed() async {
    final activeDog = state.activeDog;
    if (activeDog == null) return;
    emit(state.copyWith(status: DiscoveryStatus.loading));
    try {
      final cards = await _discoveryRepository.getFeed(dogId: activeDog.id);
      emit(
        state.copyWith(
          status: DiscoveryStatus.loaded,
          cards: cards,
          deckKey: state.deckKey + 1,
        ),
      );
    } on ApiException catch (exception) {
      if (exception.isLocationRequired) {
        emit(state.copyWith(status: DiscoveryStatus.locationRequired));
      } else {
        emit(
          state.copyWith(
            status: DiscoveryStatus.error,
            errorMessage: exception.message,
          ),
        );
      }
    }
  }
}
