import 'package:dogmatch/features/chat/data/models/message_model.dart';
import 'package:dogmatch/features/dogs/data/models/dog_model.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'match_model.g.dart';

/// Resumo do outro dono (`MatchDto.otherOwner`).
@JsonSerializable()
class MatchOwnerModel extends Equatable {
  const MatchOwnerModel({
    required this.id,
    required this.name,
    this.avatarUrl,
  });

  factory MatchOwnerModel.fromJson(Map<String, dynamic> json) =>
      _$MatchOwnerModelFromJson(json);

  final String id;
  final String name;
  final String? avatarUrl;

  Map<String, dynamic> toJson() => _$MatchOwnerModelToJson(this);

  @override
  List<Object?> get props => [id, name, avatarUrl];
}

/// `MatchDto` do contrato da API — sempre na perspectiva do cão consultado
/// (`myDog` × `otherDog`).
@JsonSerializable()
class MatchModel extends Equatable {
  const MatchModel({
    required this.id,
    required this.createdAt,
    required this.myDog,
    required this.otherDog,
    required this.otherOwner,
    this.lastMessage,
    this.unreadCount = 0,
  });

  factory MatchModel.fromJson(Map<String, dynamic> json) =>
      _$MatchModelFromJson(json);

  final String id;
  final DateTime createdAt;
  final DogModel myDog;
  final DogModel otherDog;
  final MatchOwnerModel otherOwner;
  final MessageModel? lastMessage;

  /// Mensagens do outro participante ainda sem `readAt` (`MatchDto.
  /// unreadCount`); default 0 para payloads antigos sem o campo.
  @JsonKey(defaultValue: 0)
  final int unreadCount;

  Map<String, dynamic> toJson() => _$MatchModelToJson(this);

  /// Cópia com o estado local de leitura atualizado (badge de não lidas e
  /// última mensagem chegando pelo socket) — os demais campos são imutáveis.
  MatchModel copyWith({int? unreadCount, MessageModel? lastMessage}) {
    return MatchModel(
      id: id,
      createdAt: createdAt,
      myDog: myDog,
      otherDog: otherDog,
      otherOwner: otherOwner,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  @override
  List<Object?> get props =>
      [id, createdAt, myDog, otherDog, otherOwner, lastMessage, unreadCount];
}
