// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'owner_profile_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OwnerStatsModel _$OwnerStatsModelFromJson(Map<String, dynamic> json) =>
    OwnerStatsModel(
      dogs: (json['dogs'] as num).toInt(),
      matches: (json['matches'] as num).toInt(),
    );

Map<String, dynamic> _$OwnerStatsModelToJson(OwnerStatsModel instance) =>
    <String, dynamic>{'dogs': instance.dogs, 'matches': instance.matches};

OwnerProfileModel _$OwnerProfileModelFromJson(Map<String, dynamic> json) =>
    OwnerProfileModel(
      id: json['id'] as String,
      name: json['name'] as String,
      bio: json['bio'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      city: json['city'] as String?,
      memberSince: DateTime.parse(json['memberSince'] as String),
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      stats: OwnerStatsModel.fromJson(json['stats'] as Map<String, dynamic>),
      dogs:
          (json['dogs'] as List<dynamic>?)
              ?.map((e) => DogModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$OwnerProfileModelToJson(OwnerProfileModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'bio': ?instance.bio,
      'avatarUrl': ?instance.avatarUrl,
      'city': ?instance.city,
      'memberSince': instance.memberSince.toIso8601String(),
      'distanceKm': ?instance.distanceKm,
      'stats': instance.stats.toJson(),
      'dogs': instance.dogs.map((e) => e.toJson()).toList(),
    };
