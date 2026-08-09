import 'dart:async';

import 'package:dogmatch/core/error/api_exception.dart';
import 'package:dogmatch/features/discovery/domain/entities/swipe_action.dart';
import 'package:dogmatch/features/discovery/domain/repositories/discovery_repository.dart';
import 'package:dogmatch/features/discovery/presentation/cubit/active_dog_cubit.dart';
import 'package:dogmatch/features/dogs/data/models/dog_model.dart';
import 'package:dogmatch/features/dogs/data/models/dog_owner_model.dart';
import 'package:dogmatch/features/dogs/domain/repositories/dog_repository.dart';
import 'package:dogmatch/features/matches/data/models/match_model.dart';
import 'package:dogmatch/features/matches/domain/repositories/match_repository.dart';
import 'package:dogmatch/features/search/data/models/search_card_model.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

part 'dog_detail_state.dart';

/// Detalhe de um cão vindo da busca: exibe o card recebido via extra ou, no
/// fallback (deep link), busca `GET /dogs/:id` (que inclui `owner`). Ações de
/// like/pass usam o cão ativo; `matched` abre a conversa do match.
@injectable
class DogDetailCubit extends Cubit<DogDetailState> {
  DogDetailCubit(
    this._dogRepository,
    this._discoveryRepository,
    this._matchRepository,
    this._activeDogCubit,
  ) : super(const DogDetailState()) {
    _activeDogSubscription = _activeDogCubit.stream.listen((activeState) {
      final dog = activeState.active;
      if (dog == null || dog.id == state.activeDog?.id) return;
      _applyActiveDog(dog);
    });
  }

  final DogRepository _dogRepository;
  final DiscoveryRepository _discoveryRepository;
  final MatchRepository _matchRepository;
  final ActiveDogCubit _activeDogCubit;

  late final StreamSubscription<ActiveDogState> _activeDogSubscription;

  /// Match recebido na resposta do swipe — evita refetch em "Abrir conversa".
  MatchModel? _matchFromSwipe;

  /// Descarta a checagem de match de um cão ativo já substituído.
  int _perspectiveRequestId = 0;

  Future<void> init({required String dogId, SearchCardModel? card}) async {
    emit(state.copyWith(status: DogDetailStatus.loading));
    await _activeDogCubit.ensureLoaded();
    try {
      var resolved = card;
      if (resolved == null) {
        final dog = await _dogRepository.getDog(dogId);
        // Card sem distância/badges — a rota veio sem a perspectiva da busca.
        resolved = SearchCardModel(
          dog: dog,
          owner: dog.owner ?? DogOwnerModel(id: dog.ownerId, name: 'Dono'),
        );
      }
      if (isClosed) return;
      emit(
        state.copyWith(
          status: DogDetailStatus.success,
          card: resolved,
          activeDog: _activeDogCubit.state.active,
        ),
      );
    } on ApiException catch (exception) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: DogDetailStatus.error,
          message: exception.message,
        ),
      );
    }
  }

  /// Registra like/pass com o cão ativo; em match, agenda o dialog
  /// "Deu match! 🐾" e atualiza o badge local.
  Future<void> swipe(SwipeAction action) async {
    final card = state.card;
    final activeDog = state.activeDog;
    if (card == null ||
        activeDog == null ||
        card.hasMyAction ||
        state.actionInProgress) {
      return;
    }
    emit(state.copyWith(actionInProgress: true));
    try {
      final result = await _discoveryRepository.swipe(
        swiperDogId: activeDog.id,
        targetDogId: card.dog.id,
        action: action,
      );
      if (result.matched) _matchFromSwipe = result.match;
      emit(
        state.copyWith(
          actionInProgress: false,
          card: card.copyWith(
            myAction: action.apiValue,
            matched: result.matched || card.isMatched,
          ),
          pendingMatch: result.matched ? result.match : null,
        ),
      );
    } on ApiException catch (exception) {
      emit(
        state.copyWith(
          actionInProgress: false,
          actionError: exception.message,
        ),
      );
    }
  }

  /// Localiza o match deste cão (perspectiva do cão ativo) e agenda a
  /// navegação para o chat.
  Future<void> openConversation() async {
    final card = state.card;
    if (card == null || state.actionInProgress) return;
    final known = _matchFromSwipe;
    if (known != null) {
      emit(state.copyWith(matchToOpen: known));
      return;
    }
    emit(state.copyWith(actionInProgress: true));
    try {
      final matches =
          await _matchRepository.getMatches(dogId: state.activeDog?.id);
      final match =
          matches.where((match) => match.otherDog.id == card.dog.id).firstOrNull;
      if (match == null) {
        emit(
          state.copyWith(
            actionInProgress: false,
            actionError: 'Não encontramos a conversa deste match.',
          ),
        );
        return;
      }
      emit(state.copyWith(actionInProgress: false, matchToOpen: match));
    } on ApiException catch (exception) {
      emit(
        state.copyWith(
          actionInProgress: false,
          actionError: exception.message,
        ),
      );
    }
  }

  /// Limpa os campos one-shot (dialog de match, navegação, erro transitório)
  /// após o listener da UI consumi-los.
  void clearTransient() => emit(state.copyWith());

  /// `myAction`/`matched` valem só para o cão que fez a busca: ao trocar o
  /// cão ativo, os badges caem e o match é reconsultado para o novo cão.
  /// Um like repetido é seguro (o `POST /swipes` é idempotente).
  Future<void> _applyActiveDog(DogModel dog) async {
    final card = state.card;
    final requestId = ++_perspectiveRequestId;
    _matchFromSwipe = null;
    emit(
      state.copyWith(
        activeDog: dog,
        card: card?.withoutMyPerspective(),
      ),
    );
    if (card == null) return;
    try {
      final matches = await _matchRepository.getMatches(dogId: dog.id);
      if (isClosed || requestId != _perspectiveRequestId) return;
      final match =
          matches.where((match) => match.otherDog.id == card.dog.id).firstOrNull;
      if (match == null) return;
      _matchFromSwipe = match;
      emit(
        state.copyWith(
          card: state.card?.copyWith(
            myAction: SearchCardModel.likeAction,
            matched: true,
          ),
        ),
      );
    } on ApiException {
      // Sem confirmação do match, o card segue sem badge e as ações ficam
      // disponíveis — repetir o like não quebra nada.
    }
  }

  @override
  Future<void> close() async {
    await _activeDogSubscription.cancel();
    return super.close();
  }
}
