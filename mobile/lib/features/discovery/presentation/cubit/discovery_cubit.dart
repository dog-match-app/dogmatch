import 'dart:async';

import 'package:dogmatch/core/error/api_exception.dart';
import 'package:dogmatch/features/discovery/data/models/discovery_card_model.dart';
import 'package:dogmatch/features/discovery/domain/entities/swipe_action.dart';
import 'package:dogmatch/features/discovery/domain/repositories/discovery_repository.dart';
import 'package:dogmatch/features/discovery/presentation/cubit/active_dog_cubit.dart';
import 'package:dogmatch/features/dogs/data/models/dog_model.dart';
import 'package:dogmatch/features/matches/data/models/match_model.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

part 'discovery_state.dart';

@injectable
class DiscoveryCubit extends Cubit<DiscoveryState> {
  DiscoveryCubit(
    this._discoveryRepository,
    this._activeDogCubit,
  ) : super(const DiscoveryState()) {
    _activeDogSubscription = _activeDogCubit.stream.listen((activeState) {
      final dog = activeState.active;
      if (dog == null || dog.id == state.activeDog?.id) return;
      emit(state.copyWith(activeDog: dog));
      _loadFeed();
    });
  }

  final DiscoveryRepository _discoveryRepository;
  final ActiveDogCubit _activeDogCubit;

  late final StreamSubscription<ActiveDogState> _activeDogSubscription;

  /// Swipes ainda não confirmados pela API (aguardados antes de recarregar
  /// o deck, para o feed não devolver cães já swipados).
  final Set<Future<void>> _pendingSwipes = {};

  /// Descarta respostas de decks obsoletos (troca de cão durante o fetch).
  int _feedRequestId = 0;

  Future<void> init() async {
    final requestId = ++_feedRequestId;
    emit(state.copyWith(status: DiscoveryStatus.loading));
    await _activeDogCubit.refresh();
    // A troca de cão pelo listener já recarregou o deck.
    if (isClosed || requestId != _feedRequestId) return;
    final activeState = _activeDogCubit.state;
    if (activeState.status == ActiveDogStatus.error) {
      emit(
        state.copyWith(
          status: DiscoveryStatus.error,
          errorMessage: activeState.message,
        ),
      );
      return;
    }
    final active = activeState.active;
    if (active == null) {
      emit(state.copyWith(status: DiscoveryStatus.noDogs));
      return;
    }
    emit(state.copyWith(activeDog: active));
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
    final requestId = ++_feedRequestId;
    emit(state.copyWith(status: DiscoveryStatus.loading));
    try {
      final cards = await _discoveryRepository.getFeed(dogId: activeDog.id);
      if (isClosed || requestId != _feedRequestId) return;
      emit(
        state.copyWith(
          status: DiscoveryStatus.loaded,
          cards: cards,
          deckKey: state.deckKey + 1,
        ),
      );
    } on ApiException catch (exception) {
      if (isClosed || requestId != _feedRequestId) return;
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

  @override
  Future<void> close() async {
    await _activeDogSubscription.cancel();
    return super.close();
  }
}
