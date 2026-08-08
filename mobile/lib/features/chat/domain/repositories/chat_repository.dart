import 'package:dogmatch/features/chat/data/models/message_model.dart';
import 'package:dogmatch/features/chat/data/models/messages_page_model.dart';

/// Contrato REST do chat (o tempo real fica no SocketClient).
abstract class ChatRepository {
  /// `GET /matches/:id/messages?cursor=&limit=` — histórico paginado.
  Future<MessagesPageModel> getMessages(
    String matchId, {
    String? cursor,
    int limit = 30,
  });

  /// `POST /matches/:id/messages` — fallback quando o socket está fora.
  Future<MessageModel> sendMessage(String matchId, String content);
}
