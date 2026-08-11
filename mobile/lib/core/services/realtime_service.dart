import 'dart:async';
import 'dart:collection';

import 'package:dogmatch/core/network/socket_client.dart';
import 'package:dogmatch/core/storage/token_storage.dart';
import 'package:dogmatch/features/chat/data/models/message_model.dart';
import 'package:dogmatch/features/matches/data/models/match_model.dart';
import 'package:injectable/injectable.dart';

/// Dono ÚNICO da conexão Socket.IO durante a sessão autenticada.
///
/// Antes, o `ChatCubit` conectava ao abrir a conversa e desconectava ao
/// fechá-la — fora do chat o app ficava surdo para `match:new` e
/// `message:new`. Agora a conexão vive a sessão inteira ([start] no
/// `AuthAuthenticated`, [stop] no `SessionReset`) e os eventos são
/// re-emitidos como streams tipadas com dedup por id (o servidor pode
/// entregar o mesmo evento pelo room do match E pelo room do usuário).
///
/// Ninguém mais chama `SocketClient.connect/disconnect/on`: um `connect`
/// avulso recriaria o socket e derrubaria os handlers registrados aqui.
/// O chat usa [joinMatch]/[leaveMatch]/[sendMessage] e escuta [onMessageNew].
@lazySingleton
class RealtimeService {
  RealtimeService(this._socketClient, this._tokenStorage);

  /// Ids recentes lembrados por evento para o dedup (janela suficiente para
  /// entregas duplicadas imediatas sem crescer sem limite).
  static const int _dedupWindow = 200;

  final SocketClient _socketClient;
  final TokenStorage _tokenStorage;

  final StreamController<MatchModel> _matchNewController =
      StreamController<MatchModel>.broadcast();
  final StreamController<MessageModel> _messageNewController =
      StreamController<MessageModel>.broadcast();

  /// Rooms de match a (re)entrar a cada conexão (o servidor não persiste
  /// membership entre reconexões).
  final Set<String> _joinedMatchIds = {};

  final Set<String> _seenMessageIds = {};
  final Queue<String> _seenMessageOrder = Queue<String>();
  final Set<String> _seenMatchIds = {};
  final Queue<String> _seenMatchOrder = Queue<String>();

  bool _started = false;

  /// Novo match envolvendo um dos meus cães (payload `MatchDto` já na minha
  /// perspectiva).
  Stream<MatchModel> get onMatchNew => _matchNewController.stream;

  /// Mensagem nova de qualquer match meu (room `user:<id>`) ou do match
  /// aberto (room `match:<id>`), já deduplicada.
  Stream<MessageModel> get onMessageNew => _messageNewController.stream;

  bool get isConnected => _socketClient.isConnected;

  /// Início da sessão autenticada: conecta e registra os handlers.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    await ensureConnected();
  }

  /// Reconecta se a conexão caiu e foi descartada (ex.: socket derrubado no
  /// logout anterior). Sem token não faz nada — o fallback REST cobre.
  Future<void> ensureConnected() async {
    if (!_started || _socketClient.isConnected) return;
    final accessToken = await _tokenStorage.readAccessToken();
    if (accessToken == null || accessToken.isEmpty) return;
    // `connect` em socket desconectado recria o socket do zero, então os
    // handlers precisam ser registrados de novo logo em seguida.
    _socketClient.connect(accessToken: accessToken);
    _socketClient.onConnect(_rejoinMatches);
    _socketClient.on('match:new', _handleMatchNew);
    _socketClient.on('message:new', _handleMessageNew);
  }

  /// Entra no room do match (chat aberto) e lembra dele para reconexões.
  void joinMatch(String matchId) {
    _joinedMatchIds.add(matchId);
    _socketClient.emit('match:join', {'matchId': matchId});
  }

  void leaveMatch(String matchId) {
    _joinedMatchIds.remove(matchId);
  }

  /// Envia mensagem pelo socket — o chamador deve checar [isConnected] e
  /// usar o fallback REST quando desconectado.
  void sendMessage({required String matchId, required String content}) {
    _socketClient.emit('message:send', {
      'matchId': matchId,
      'content': content,
    });
  }

  /// Fim da sessão: derruba a conexão e limpa o estado por-conta.
  void stop() {
    _started = false;
    _joinedMatchIds.clear();
    _seenMessageIds.clear();
    _seenMessageOrder.clear();
    _seenMatchIds.clear();
    _seenMatchOrder.clear();
    _socketClient.disconnect();
  }

  void _rejoinMatches() {
    for (final matchId in _joinedMatchIds) {
      _socketClient.emit('match:join', {'matchId': matchId});
    }
  }

  void _handleMatchNew(dynamic data) {
    // Payload malformado nunca pode derrubar o app: evento é descartado.
    try {
      if (data is! Map) return;
      final match = MatchModel.fromJson(Map<String, dynamic>.from(data));
      if (!_firstSeen(_seenMatchIds, _seenMatchOrder, match.id)) return;
      _matchNewController.add(match);
    } on Object {
      return;
    }
  }

  void _handleMessageNew(dynamic data) {
    try {
      if (data is! Map) return;
      final message = MessageModel.fromJson(Map<String, dynamic>.from(data));
      if (!_firstSeen(_seenMessageIds, _seenMessageOrder, message.id)) return;
      _messageNewController.add(message);
    } on Object {
      return;
    }
  }

  bool _firstSeen(Set<String> seen, Queue<String> order, String id) {
    if (!seen.add(id)) return false;
    order.add(id);
    if (order.length > _dedupWindow) seen.remove(order.removeFirst());
    return true;
  }

  @disposeMethod
  void dispose() {
    stop();
    unawaited(_matchNewController.close());
    unawaited(_messageNewController.close());
  }
}
