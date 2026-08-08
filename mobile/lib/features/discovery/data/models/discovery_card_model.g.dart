// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'discovery_card_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DiscoveryOwnerModel _$DiscoveryOwnerModelFromJson(Map<String, dynamic> json) =>
    DiscoveryOwnerModel(
      id: json['id'] as String,
      name: json['name'] as String,
      city: json['city'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
    );

Map<String, dynamic> _$DiscoveryOwnerModelToJson(
  DiscoveryOwnerModel instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'city': ?instance.city,
  'avatarUrl': ?instance.avatarUrl,
};

DiscoveryCardModel _$DiscoveryCardModelFromJson(Map<String, dynamic> json) =>
    DiscoveryCardModel(
      dog: DogModel.fromJson(json['dog'] as Map<String, dynamic>),
      distanceKm: (json['distanceKm'] as num).toDouble(),
      owner: DiscoveryOwnerModel.fromJson(
        json['owner'] as Map<String, dynamic>,
      ),
    );

Map<String, dynamic> _$DiscoveryCardModelToJson(DiscoveryCardModel instance) =>
    <String, dynamic>{
      'dog': instance.dog.toJson(),
      'distanceKm': instance.distanceKm,
      'owner': instance.owner.toJson(),
    };
