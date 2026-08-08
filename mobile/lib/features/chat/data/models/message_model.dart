import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'message_model.g.dart';

/// `MessageDto` do contrato da API (REST e evento `message:new`).
@JsonSerializable()
class MessageModel extends Equatable {
  const MessageModel({
    required this.id,
    required this.matchId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.readAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) =>
      _$MessageModelFromJson(json);

  final String id;
  final String matchId;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final DateTime? readAt;

  Map<String, dynamic> toJson() => _$MessageModelToJson(this);

  @override
  List<Object?> get props => [id, matchId, senderId, content, createdAt, readAt];
}
