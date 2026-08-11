// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'like_received_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LikeReceivedModel _$LikeReceivedModelFromJson(Map<String, dynamic> json) =>
    LikeReceivedModel(
      dog: DogModel.fromJson(json['dog'] as Map<String, dynamic>),
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      owner: DogOwnerModel.fromJson(json['owner'] as Map<String, dynamic>),
      likedAt: DateTime.parse(json['likedAt'] as String),
      myAction: json['myAction'] as String?,
    );

Map<String, dynamic> _$LikeReceivedModelToJson(LikeReceivedModel instance) =>
    <String, dynamic>{
      'dog': instance.dog.toJson(),
      'distanceKm': ?instance.distanceKm,
      'owner': instance.owner.toJson(),
      'likedAt': instance.likedAt.toIso8601String(),
      'myAction': ?instance.myAction,
    };

LikesReceivedModel _$LikesReceivedModelFromJson(Map<String, dynamic> json) =>
    LikesReceivedModel(
      items: (json['items'] as List<dynamic>)
          .map((e) => LikeReceivedModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toInt(),
    );

Map<String, dynamic> _$LikesReceivedModelToJson(LikesReceivedModel instance) =>
    <String, dynamic>{
      'items': instance.items.map((e) => e.toJson()).toList(),
      'total': instance.total,
    };
