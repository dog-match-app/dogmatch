import 'package:dogmatch/core/error/api_exception.dart';
import 'package:dogmatch/core/network/socket_client.dart';
import 'package:dogmatch/core/storage/token_storage.dart';
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
/// Socket.IO (`match:join` + `message:send`/`message:new`) com fallback
/// REST quando o socket está desconectado.
@injectable
class ChatCubit extends Cubit<ChatState> {
  ChatCubit(
    this._chatRepository,
    this._matchRepository,
    this._socketClient,
    this._tokenStorage,
    this._authBloc,
  ) : super(const ChatState());

  final ChatRepository _chatRepository;
  final MatchRepository _matchRepository;
  final SocketClient _socketClient;
  final TokenStorage _tokenStorage;
  final AuthBloc _authBloc;

  late String _matchId;

  Future<void> init({required String matchId, MatchModel? match}) async {
    _matchId = matchId;
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
      await _connectSocket();
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
  Future<void> retry() => init(matchId: _matchId, match: state.match);

  /// Pagina mensagens mais antigas (scroll no topo da lista).
  Future<void> loadMore() async {
    if (!state.hasMore || state.loadingMore) return;
    emit(state.copyWith(loadingMore: true));
    try {
      final page = await _chatRepository.getMessages(
        _matchId,
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
    if (_socketClient.isConnected) {
      _socketClient.emit('message:send', {
        'matchId': _matchId,
        'content': trimmed,
      });
      return;
    }
    emit(state.copyWith(sending: true));
    try {
      final message = await _chatRepository.sendMessage(_matchId, trimmed);
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

  Future<void> _connectSocket() async {
    final accessToken = await _tokenStorage.readAccessToken();
    if (accessToken == null || accessToken.isEmpty) return;
    _socketClient.connect(accessToken: accessToken);
    // Reentra no room a cada (re)conexão.
    _socketClient.onConnect(() {
      _socketClient.emit('match:join', {'matchId': _matchId});
    });
    _socketClient.on('message:new', _onMessageNew);
    _socketClient.emit('match:join', {'matchId': _matchId});
  }

  void _onMessageNew(dynamic data) {
    if (isClosed || data is! Map) return;
    final message =
        MessageModel.fromJson(Map<String, dynamic>.from(data));
    if (message.matchId != _matchId) return;
    emit(state.copyWith(messages: _merge(state.messages, [message])));
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
  Future<void> close() {
    _socketClient.off('message:new', _onMessageNew);
    _socketClient.disconnect();
    return super.close();
  }
}
