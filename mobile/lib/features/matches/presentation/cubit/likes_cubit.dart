import 'dart:async';

import 'package:dogmatch/core/error/api_exception.dart';
import 'package:dogmatch/features/discovery/domain/entities/swipe_action.dart';
import 'package:dogmatch/features/discovery/domain/repositories/discovery_repository.dart';
import 'package:dogmatch/features/discovery/presentation/cubit/active_dog_cubit.dart';
import 'package:dogmatch/features/matches/data/models/like_received_model.dart';
import 'package:dogmatch/features/matches/data/models/match_model.dart';
import 'package:dogmatch/features/matches/domain/repositories/likes_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

part 'likes_state.dart';

/// Curtidas recebidas pelo cão ativo (segmento "Curtidas" da aba Matches):
/// lista `GET /swipes/received?dogId=` e o "Curtir de volta" (reutiliza o
/// `POST /swipes` do discovery — match praticamente garantido). Refaz o
/// fetch quando o `ActiveDogCubit` troca, como o `MatchesCubit`.
@injectable
class LikesCubit extends Cubit<LikesState> {
  LikesCubit(
    this._likesRepository,
    this._discoveryRepository,
    this._activeDogCubit,
  ) : super(const LikesState()) {
    _activeDogSubscription = _activeDogCubit.stream.listen((activeState) {
      final dog = activeState.active;
      if (dog != null && dog.id != state.activeDogId) load();
    });
  }

  final LikesRepository _likesRepository;
  final DiscoveryRepository _discoveryRepository;
  final ActiveDogCubit _activeDogCubit;

  late final StreamSubscription<ActiveDogState> _activeDogSubscription;

  /// Descarta respostas obsoletas quando o cão troca durante o fetch.
  int _requestId = 0;

  Future<void> load() async {
    final requestId = ++_requestId;
    emit(state.copyWith(status: LikesStatus.loading));
    await _activeDogCubit.ensureLoaded();
    if (isClosed || requestId != _requestId) return;
    final activeState = _activeDogCubit.state;
    if (activeState.status == ActiveDogStatus.error) {
      emit(
        state.copyWith(
          status: LikesStatus.error,
          errorMessage: activeState.message,
        ),
      );
      return;
    }
    final activeDog = activeState.active;
    if (activeDog == null) {
      emit(state.copyWith(status: LikesStatus.loaded, likes: []));
      return;
    }
    emit(state.copyWith(activeDogId: activeDog.id));
    try {
      final likes = await _likesRepository.getReceived(dogId: activeDog.id);
      if (isClosed || requestId != _requestId) return;
      emit(state.copyWith(status: LikesStatus.loaded, likes: likes.items));
    } on ApiException catch (exception) {
      if (isClosed || requestId != _requestId) return;
      emit(
        state.copyWith(
          status: LikesStatus.error,
          errorMessage: exception.message,
        ),
      );
    }
  }

  /// "Curtir de volta": LIKE do cão ativo no cão que curtiu. Sucesso remove
  /// a curtida da lista; `matched` agenda o MatchDialog ([LikesState.
  /// pendingMatch], consumido pelo listener da página).
  Future<void> likeBack(LikeReceivedModel like) async {
    final activeDogId = state.activeDogId;
    if (activeDogId == null || state.likingBackDogIds.contains(like.dog.id)) {
      return;
    }
    emit(
      state.copyWith(
        likingBackDogIds: {...state.likingBackDogIds, like.dog.id},
      ),
    );
    try {
      final result = await _discoveryRepository.swipe(
        swiperDogId: activeDogId,
        targetDogId: like.dog.id,
        action: SwipeAction.like,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          likes: [
            for (final item in state.likes)
              if (item.dog.id != like.dog.id) item,
          ],
          likingBackDogIds: {...state.likingBackDogIds}..remove(like.dog.id),
          pendingMatch: result.matched ? result.match : null,
        ),
      );
    } on ApiException catch (exception) {
      if (isClosed) return;
      emit(
        state.copyWith(
          likingBackDogIds: {...state.likingBackDogIds}..remove(like.dog.id),
          actionError: exception.message,
        ),
      );
    }
  }

  /// Remove a curtida do cão [dogId] — usada quando o like aconteceu DENTRO
  /// do detalhe (`/search/dogs/:id` devolve o `myAction` final no pop).
  void removeByDogId(String dogId) {
    if (!state.likes.any((like) => like.dog.id == dogId)) return;
    emit(
      state.copyWith(
        likes: [
          for (final like in state.likes)
            if (like.dog.id != dogId) like,
        ],
      ),
    );
  }

  /// Limpa os campos one-shot (dialog de match, erro transitório) após o
  /// listener da UI consumi-los.
  void clearTransient() => emit(state.copyWith());

  @override
  Future<void> close() async {
    await _activeDogSubscription.cancel();
    return super.close();
  }
}
