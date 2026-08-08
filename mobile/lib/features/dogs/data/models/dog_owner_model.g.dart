// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dog_owner_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DogOwnerModel _$DogOwnerModelFromJson(Map<String, dynamic> json) =>
    DogOwnerModel(
      id: json['id'] as String,
      name: json['name'] as String,
      city: json['city'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
    );

Map<String, dynamic> _$DogOwnerModelToJson(DogOwnerModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'city': ?instance.city,
      'avatarUrl': ?instance.avatarUrl,
    };
