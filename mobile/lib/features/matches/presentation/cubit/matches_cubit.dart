import 'dart:async';

import 'package:dogmatch/core/error/api_exception.dart';
import 'package:dogmatch/core/services/app_notifications_service.dart';
import 'package:dogmatch/core/services/realtime_service.dart';
import 'package:dogmatch/features/chat/data/models/message_model.dart';
import 'package:dogmatch/features/discovery/presentation/cubit/active_dog_cubit.dart';
import 'package:dogmatch/features/matches/data/models/match_model.dart';
import 'package:dogmatch/features/matches/domain/repositories/match_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

part 'matches_state.dart';

/// Lista os matches do cão ativo (mesma seleção do Discovery) e refaz o
/// fetch quando a seleção muda. Enquanto a aba vive, os eventos do socket
/// (via `RealtimeService`) mantêm a lista quente sem refetch: `message:new`
/// com o chat fechado incrementa o `unreadCount` local e atualiza a última
/// mensagem; `match:new` do cão ativo entra no topo. [markRead] zera o
/// contador local ao abrir um chat (o `POST /matches/:id/read` é do
/// `ChatCubit`).
@injectable
class MatchesCubit extends Cubit<MatchesState> {
  MatchesCubit(
    this._matchRepository,
    this._activeDogCubit,
    this._realtimeService,
    this._notificationsService,
  ) : super(const MatchesState()) {
    _activeDogSubscription = _activeDogCubit.stream.listen((activeState) {
      final dog = activeState.active;
      if (dog != null && dog.id != state.activeDogId) load();
    });
    _matchNewSubscription = _realtimeService.onMatchNew.listen(_onMatchNew);
    _messageNewSubscription =
        _realtimeService.onMessageNew.listen(_onMessageNew);
  }

  final MatchRepository _matchRepository;
  final ActiveDogCubit _activeDogCubit;
  final RealtimeService _realtimeService;
  final AppNotificationsService _notificationsService;

  late final StreamSubscription<ActiveDogState> _activeDogSubscription;
  late final StreamSubscription<MatchModel> _matchNewSubscription;
  late final StreamSubscription<MessageModel> _messageNewSubscription;

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

  /// Zera o contador local de não lidas do match (chamado ao abrir o chat
  /// pela lista — a UI não espera o `POST /matches/:id/read` do servidor).
  void markRead(String matchId) {
    if (state.status != MatchesStatus.loaded) return;
    emit(
      state.copyWith(
        matches: [
          for (final match in state.matches)
            if (match.id == matchId) match.copyWith(unreadCount: 0) else match,
        ],
      ),
    );
  }

  void _onMessageNew(MessageModel message) {
    if (state.status != MatchesStatus.loaded) return;
    // Chat aberto: quem exibe e marca como lida é o ChatCubit — a lista
    // será atualizada pelo load() na volta.
    if (_notificationsService.isChatOpen(message.matchId)) return;
    final index =
        state.matches.indexWhere((match) => match.id == message.matchId);
    if (index == -1) return;
    final match = state.matches[index];
    final matches = [...state.matches];
    matches[index] = match.copyWith(
      unreadCount: match.unreadCount + 1,
      lastMessage: message,
    );
    emit(state.copyWith(matches: matches));
  }

  void _onMatchNew(MatchModel match) {
    if (state.status != MatchesStatus.loaded) return;
    if (match.myDog.id != state.activeDogId) return;
    if (state.matches.any((existing) => existing.id == match.id)) return;
    emit(state.copyWith(matches: [match, ...state.matches]));
  }

  @override
  Future<void> close() async {
    await _activeDogSubscription.cancel();
    await _matchNewSubscription.cancel();
    await _messageNewSubscription.cancel();
    return super.close();
  }
}
