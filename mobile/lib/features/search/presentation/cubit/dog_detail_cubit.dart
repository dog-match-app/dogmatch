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
  ) : super(const DogDetailState());

  final DogRepository _dogRepository;
  final DiscoveryRepository _discoveryRepository;
  final MatchRepository _matchRepository;
  final ActiveDogCubit _activeDogCubit;

  /// Match recebido na resposta do swipe — evita refetch em "Abrir conversa".
  MatchModel? _matchFromSwipe;

  Future<void> init({required String dogId, SearchCardModel? card}) async {
    emit(state.copyWith(status: DogDetailStatus.loading));
    try {
      final activeDog = await _ensureActiveDog();
      var resolved = card;
      if (resolved == null) {
        final dog = await _dogRepository.getDog(dogId);
        // Card sem distância/badges — a rota veio sem a perspectiva da busca.
        resolved = SearchCardModel(
          dog: dog,
          owner: dog.owner ?? DogOwnerModel(id: dog.ownerId, name: 'Dono'),
        );
      }
      emit(
        state.copyWith(
          status: DogDetailStatus.success,
          card: resolved,
          activeDog: activeDog,
        ),
      );
    } on ApiException catch (exception) {
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

  /// Mesmo padrão do Matches: sem seleção, assume o primeiro cão do usuário.
  /// Falha aqui não bloqueia a tela (apenas esconde as ações).
  Future<DogModel?> _ensureActiveDog() async {
    final active = _activeDogCubit.state;
    if (active != null) return active;
    try {
      final dogs = await _dogRepository.getMyDogs();
      if (dogs.isEmpty) return null;
      _activeDogCubit.select(dogs.first);
      return dogs.first;
    } on ApiException {
      return null;
    }
  }
}
