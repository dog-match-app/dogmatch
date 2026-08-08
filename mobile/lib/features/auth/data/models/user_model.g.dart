// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserModel _$UserModelFromJson(Map<String, dynamic> json) => UserModel(
  id: json['id'] as String,
  email: json['email'] as String,
  name: json['name'] as String,
  phone: json['phone'] as String?,
  bio: json['bio'] as String?,
  avatarUrl: json['avatarUrl'] as String?,
  city: json['city'] as String?,
  latitude: (json['latitude'] as num?)?.toDouble(),
  longitude: (json['longitude'] as num?)?.toDouble(),
  createdAt: DateTime.parse(json['createdAt'] as String),
  dogs: (json['dogs'] as List<dynamic>?)
      ?.map((e) => DogModel.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$UserModelToJson(UserModel instance) => <String, dynamic>{
  'id': instance.id,
  'email': instance.email,
  'name': instance.name,
  'phone': ?instance.phone,
  'bio': ?instance.bio,
  'avatarUrl': ?instance.avatarUrl,
  'city': ?instance.city,
  'latitude': ?instance.latitude,
  'longitude': ?instance.longitude,
  'createdAt': instance.createdAt.toIso8601String(),
  'dogs': ?instance.dogs?.map((e) => e.toJson()).toList(),
};
