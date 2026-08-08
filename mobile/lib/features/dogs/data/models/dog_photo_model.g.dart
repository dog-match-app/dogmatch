// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dog_photo_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DogPhotoModel _$DogPhotoModelFromJson(Map<String, dynamic> json) =>
    DogPhotoModel(
      id: json['id'] as String,
      url: json['url'] as String,
      position: (json['position'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$DogPhotoModelToJson(DogPhotoModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'url': instance.url,
      'position': instance.position,
    };
