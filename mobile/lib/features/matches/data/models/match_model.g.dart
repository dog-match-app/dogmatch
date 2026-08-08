// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'match_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MatchOwnerModel _$MatchOwnerModelFromJson(Map<String, dynamic> json) =>
    MatchOwnerModel(
      id: json['id'] as String,
      name: json['name'] as String,
      avatarUrl: json['avatarUrl'] as String?,
    );

Map<String, dynamic> _$MatchOwnerModelToJson(MatchOwnerModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'avatarUrl': ?instance.avatarUrl,
    };

MatchModel _$MatchModelFromJson(Map<String, dynamic> json) => MatchModel(
  id: json['id'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  myDog: DogModel.fromJson(json['myDog'] as Map<String, dynamic>),
  otherDog: DogModel.fromJson(json['otherDog'] as Map<String, dynamic>),
  otherOwner: MatchOwnerModel.fromJson(
    json['otherOwner'] as Map<String, dynamic>,
  ),
  lastMessage: json['lastMessage'] == null
      ? null
      : MessageModel.fromJson(json['lastMessage'] as Map<String, dynamic>),
);

Map<String, dynamic> _$MatchModelToJson(MatchModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt.toIso8601String(),
      'myDog': instance.myDog.toJson(),
      'otherDog': instance.otherDog.toJson(),
      'otherOwner': instance.otherOwner.toJson(),
      'lastMessage': ?instance.lastMessage?.toJson(),
    };
