import 'package:dogmatch/features/chat/data/models/message_model.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'messages_page_model.g.dart';

/// Página de mensagens — resposta de `GET /matches/:id/messages`.
@JsonSerializable()
class MessagesPageModel extends Equatable {
  const MessagesPageModel({
    this.items = const [],
    this.nextCursor,
  });

  factory MessagesPageModel.fromJson(Map<String, dynamic> json) =>
      _$MessagesPageModelFromJson(json);

  final List<MessageModel> items;

  /// Cursor da próxima página (mensagens mais antigas); `null` = fim.
  final String? nextCursor;

  Map<String, dynamic> toJson() => _$MessagesPageModelToJson(this);

  @override
  List<Object?> get props => [items, nextCursor];
}
