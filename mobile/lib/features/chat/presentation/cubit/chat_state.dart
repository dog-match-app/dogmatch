part of 'chat_cubit.dart';

enum ChatStatus { initial, loading, loaded, error }

class ChatState extends Equatable {
  const ChatState({
    this.status = ChatStatus.initial,
    this.match,
    this.messages = const [],
    this.nextCursor,
    this.loadingMore = false,
    this.sending = false,
    this.myUserId,
    this.errorMessage,
  });

  final ChatStatus status;
  final MatchModel? match;

  /// Mensagens ordenadas da mais recente para a mais antiga
  /// (a lista é renderizada com `reverse: true`).
  final List<MessageModel> messages;

  /// Cursor para buscar mensagens mais antigas; `null` = fim do histórico.
  final String? nextCursor;

  final bool loadingMore;
  final bool sending;
  final String? myUserId;
  final String? errorMessage;

  bool get hasMore => nextCursor != null;

  ChatState copyWith({
    ChatStatus? status,
    MatchModel? match,
    List<MessageModel>? messages,
    String? nextCursor,
    bool clearNextCursor = false,
    bool? loadingMore,
    bool? sending,
    String? myUserId,
    String? errorMessage,
  }) {
    return ChatState(
      status: status ?? this.status,
      match: match ?? this.match,
      messages: messages ?? this.messages,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      loadingMore: loadingMore ?? this.loadingMore,
      sending: sending ?? this.sending,
      myUserId: myUserId ?? this.myUserId,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        match,
        messages,
        nextCursor,
        loadingMore,
        sending,
        myUserId,
        errorMessage,
      ];
}
