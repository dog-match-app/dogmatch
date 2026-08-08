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
  });

  factory MatchModel.fromJson(Map<String, dynamic> json) =>
      _$MatchModelFromJson(json);

  final String id;
  final DateTime createdAt;
  final DogModel myDog;
  final DogModel otherDog;
  final MatchOwnerModel otherOwner;
  final MessageModel? lastMessage;

  Map<String, dynamic> toJson() => _$MatchModelToJson(this);

  @override
  List<Object?> get props =>
      [id, createdAt, myDog, otherDog, otherOwner, lastMessage];
}
