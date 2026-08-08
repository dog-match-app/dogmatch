import 'package:dio/dio.dart';
import 'package:dogmatch/core/error/api_exception.dart';
import 'package:dogmatch/features/chat/data/models/message_model.dart';
import 'package:dogmatch/features/chat/data/models/messages_page_model.dart';
import 'package:dogmatch/features/chat/domain/repositories/chat_repository.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: ChatRepository)
class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<MessagesPageModel> getMessages(
    String matchId, {
    String? cursor,
    int limit = 30,
  }) {
    return guardApi(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/matches/$matchId/messages',
        queryParameters: {'limit': limit, 'cursor': ?cursor},
      );
      return MessagesPageModel.fromJson(response.data!);
    });
  }

  @override
  Future<MessageModel> sendMessage(String matchId, String content) {
    return guardApi(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/matches/$matchId/messages',
        data: {'content': content},
      );
      return MessageModel.fromJson(response.data!);
    });
  }
}
