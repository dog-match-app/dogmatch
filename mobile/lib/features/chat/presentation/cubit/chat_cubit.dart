import 'dart:async';

import 'package:dogmatch/core/error/api_exception.dart';
import 'package:dogmatch/core/services/app_notifications_service.dart';
import 'package:dogmatch/core/services/realtime_service.dart';
import 'package:dogmatch/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:dogmatch/features/chat/data/models/message_model.dart';
import 'package:dogmatch/features/chat/domain/repositories/chat_repository.dart';
import 'package:dogmatch/features/matches/data/models/match_model.dart';
import 'package:dogmatch/features/matches/domain/repositories/match_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

part 'chat_state.dart';

/// Conversa de um match: histórico paginado via REST, tempo real via
/// `RealtimeService` (`match:join` + `message:send`/`message:new`) com
/// fallback REST quando o socket está desconectado.
///
/// A conexão do socket pertence à sessão (`RealtimeService`), não a este
/// cubit: abrir/fechar o chat só entra/sai do room. Abrir a conversa também
/// registra o chat como "tela ativa" no `AppNotificationsService` (suprime
/// notificação das mensagens deste match e zera o badge) e marca as
/// mensagens do outro como lidas (`POST /matches/:id/read`).
@injectable
class ChatCubit extends Cubit<ChatState> {
  ChatCubit(
    this._chatRepository,
    this._matchRepository,
    this._realtimeService,
    this._notificationsService,
    this._authBloc,
  ) : super(const ChatState());

  final ChatRepository _chatRepository;
  final MatchRepository _matchRepository;
  final RealtimeService _realtimeService;
  final AppNotificationsService _notificationsService;
  final AuthBloc _authBloc;

  String? _matchId;

  StreamSubscription<MessageModel>? _messageSubscription;

  Future<void> init({required String matchId, MatchModel? match}) async {
    _matchId = matchId;
    // Registrado ANTES do carregamento: mensagem chegando pelo socket com a
    // conversa já em tela não pode virar notificação nem contar no badge.
    _notificationsService.chatOpened(matchId);
    final authState = _authBloc.state;
    emit(
      state.copyWith(
        status: ChatStatus.loading,
        match: match,
        myUserId:
            authState is AuthAuthenticated ? authState.user.id : null,
      ),
    );
    try {
      // Rota aberta por deep link sem extra: busca o match na API.
      if (match == null) {
        final found = await _matchRepository.findMatch(matchId);
        if (found != null) emit(state.copyWith(match: found));
      }
      final page = await _chatRepository.getMessages(matchId);
      emit(
        state.copyWith(
          status: ChatStatus.loaded,
          messages: _sortDescending(page.items),
          nextCursor: page.nextCursor,
          clearNextCursor: page.nextCursor == null,
        ),
      );
      unawaited(_markReadQuietly());
      await _connectRealtime(matchId);
    } on ApiException catch (exception) {
      emit(
        state.copyWith(
          status: ChatStatus.error,
          errorMessage: exception.message,
        ),
      );
    }
  }

  /// Tenta reabrir a conversa após um erro de carregamento.
  Future<void> retry() => init(matchId: _matchId!, match: state.match);

  /// Pagina mensagens mais antigas (scroll no topo da lista).
  Future<void> loadMore() async {
    if (!state.hasMore || state.loadingMore) return;
    emit(state.copyWith(loadingMore: true));
    try {
      final page = await _chatRepository.getMessages(
        _matchId!,
        cursor: state.nextCursor,
      );
      emit(
        state.copyWith(
          loadingMore: false,
          messages: _merge(state.messages, page.items),
          nextCursor: page.nextCursor,
          clearNextCursor: page.nextCursor == null,
        ),
      );
    } on ApiException catch (exception) {
      emit(
        state.copyWith(loadingMore: false, errorMessage: exception.message),
      );
    }
  }

  /// Envia pelo socket quando conectado (a mensagem volta via
  /// `message:new`); senão, fallback `POST /matches/:id/messages`.
  Future<void> send(String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;
    if (_realtimeService.isConnected) {
      _realtimeService.sendMessage(matchId: _matchId!, content: trimmed);
      return;
    }
    emit(state.copyWith(sending: true));
    try {
      final message = await _chatRepository.sendMessage(_matchId!, trimmed);
      emit(
        state.copyWith(
          sending: false,
          messages: _merge(state.messages, [message]),
        ),
      );
    } on ApiException catch (exception) {
      emit(state.copyWith(sending: false, errorMessage: exception.message));
    }
  }

  Future<void> _connectRealtime(String matchId) async {
    await _realtimeService.ensureConnected();
    _realtimeService.joinMatch(matchId);
    _messageSubscription ??=
        _realtimeService.onMessageNew.listen(_onMessageNew);
  }

  void _onMessageNew(MessageModel message) {
    if (isClosed || message.matchId != _matchId) return;
    emit(state.copyWith(messages: _merge(state.messages, [message])));
    // Mensagem do outro lida na hora (conversa em tela): mantém o
    // `unreadCount` do servidor zerado para a lista de matches.
    if (message.senderId != state.myUserId) unawaited(_markReadQuietly());
  }

  /// `POST /matches/:id/read` em melhor esforço: falhar não atrapalha a
  /// conversa — o contador local já foi zerado pela lista/badge.
  Future<void> _markReadQuietly() async {
    final matchId = _matchId;
    if (matchId == null) return;
    try {
      await _matchRepository.markRead(matchId);
    } on ApiException {
      // Sem rede o servidor re-entrega o contador no próximo fetch.
    }
  }

  /// Mescla com dedup por id e reordena (mais recente primeiro).
  static List<MessageModel> _merge(
    List<MessageModel> current,
    List<MessageModel> incoming,
  ) {
    final byId = <String, MessageModel>{
      for (final message in current) message.id: message,
      for (final message in incoming) message.id: message,
    };
    return _sortDescending(byId.values.toList());
  }

  static List<MessageModel> _sortDescending(List<MessageModel> messages) {
    final sorted = [...messages]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  @override
  Future<void> close() async {
    final matchId = _matchId;
    if (matchId != null) {
      _realtimeService.leaveMatch(matchId);
      _notificationsService.chatClosed(matchId);
    }
    await _messageSubscription?.cancel();
    return super.close();
  }
}
