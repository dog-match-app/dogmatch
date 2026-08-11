import 'dart:async';

import 'package:dogmatch/core/error/api_exception.dart';
import 'package:dogmatch/core/services/location_service.dart';
import 'package:dogmatch/core/storage/app_preferences.dart';
import 'package:dogmatch/features/auth/data/models/user_model.dart';
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
    this._locationService,
    this._appPreferences,
  ) : super(const DiscoveryState()) {
    _activeDogSubscription = _activeDogCubit.stream.listen((activeState) {
      final dog = activeState.active;
      if (dog == null || dog.id == state.activeDog?.id) return;
      emit(state.copyWith(activeDog: dog));
      _loadFeed();
    });
    _locationSyncSubscription =
        _locationService.onLocationSynced.listen((_) {
      if (state.status == DiscoveryStatus.locationRequired) _loadFeed();
    });
  }

  final DiscoveryRepository _discoveryRepository;
  final ActiveDogCubit _activeDogCubit;
  final LocationService _locationService;
  final AppPreferences _appPreferences;

  late final StreamSubscription<ActiveDogState> _activeDogSubscription;
  late final StreamSubscription<UserModel> _locationSyncSubscription;

  /// Swipes ainda não confirmados pela API (aguardados antes de recarregar
  /// o deck, para o feed não devolver cães já swipados).
  final Set<Future<void>> _pendingSwipes = {};

  /// Cães deste deck já consumidos pelo swipe físico. O CardSwiper avança um
  /// índice interno e `state.cards` não muda a cada swipe; ao recriar o deck
  /// em [removeCard], este set impede cards já swipados de reaparecer.
  final Set<String> _consumedDogIds = {};

  /// Descarta respostas de decks obsoletos (troca de cão durante o fetch).
  int _feedRequestId = 0;

  Future<void> init() async {
    final requestId = ++_feedRequestId;
    // O raio precisa estar definido ANTES do refresh dos cães: a troca de
    // cão pelo listener pode disparar o primeiro `_loadFeed`.
    final radiusKm = await _readStoredRadius();
    if (isClosed) return;
    emit(state.copyWith(status: DiscoveryStatus.loading, radiusKm: radiusKm));
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

  /// Aplica o novo raio máximo (sheet do AppBar), persiste a preferência e
  /// recarrega o deck. Falha ao persistir não impede o raio de valer já.
  Future<void> changeRadius(int radiusKm) async {
    if (radiusKm == state.radiusKm) return;
    emit(state.copyWith(radiusKm: radiusKm));
    try {
      await _appPreferences.setDiscoveryRadiusKm(radiusKm);
    } on Exception {
      // Best-effort: sem persistência o valor ainda vale nesta sessão.
    }
    await _loadFeed();
  }

  /// Chamado pelo CardSwiper quando o deck acaba: busca a próxima leva.
  Future<void> onDeckFinished() async {
    await Future.wait(_pendingSwipes.toList());
    await _loadFeed();
  }

  Future<void> onSwiped(DiscoveryCardModel card, SwipeAction action) async {
    final activeDog = state.activeDog;
    if (activeDog == null) return;
    _consumedDogIds.add(card.dog.id);
    late final Future<void> pending;
    pending = _registerSwipe(activeDog.id, card, action)
        .whenComplete(() => _pendingSwipes.remove(pending));
    _pendingSwipes.add(pending);
    await pending;
  }

  /// Remove do deck o cão [dogId] após like/pass feito DENTRO do detalhe
  /// (o swipe físico não passa por aqui). Recria o deck só com os cards
  /// restantes; sem restantes, segue o fluxo de fim de deck já existente
  /// ([onDeckFinished]: aguarda swipes pendentes e recarrega o feed).
  Future<void> removeCard(String dogId) async {
    if (isClosed || state.status != DiscoveryStatus.loaded) return;
    if (!state.cards.any((card) => card.dog.id == dogId)) return;
    final remaining = [
      for (final card in state.cards)
        if (card.dog.id != dogId && !_consumedDogIds.contains(card.dog.id))
          card,
    ];
    if (remaining.isEmpty) {
      await onDeckFinished();
      return;
    }
    _consumedDogIds.clear();
    emit(state.copyWith(cards: remaining, deckKey: state.deckKey + 1));
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
      if (isClosed) return;
      if (exception.isLocationRequired) {
        emit(state.copyWith(status: DiscoveryStatus.locationRequired));
      } else {
        emit(state.copyWith(swipeError: exception.message));
      }
    }
  }

  Future<void> _loadFeed() async {
    final activeDog = state.activeDog;
    if (activeDog == null) return;
    final requestId = ++_feedRequestId;
    emit(state.copyWith(status: DiscoveryStatus.loading));
    try {
      final cards = await _discoveryRepository.getFeed(
        dogId: activeDog.id,
        radiusKm: state.radiusKm,
      );
      if (isClosed || requestId != _feedRequestId) return;
      _consumedDogIds.clear();
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

  /// Raio persistido (ou o atual, se a leitura falhar — preferência nunca
  /// pode derrubar o feed).
  Future<int> _readStoredRadius() async {
    try {
      return await _appPreferences.getDiscoveryRadiusKm() ?? state.radiusKm;
    } on Exception {
      return state.radiusKm;
    }
  }

  @override
  Future<void> close() async {
    await _activeDogSubscription.cancel();
    await _locationSyncSubscription.cancel();
    return super.close();
  }
}
