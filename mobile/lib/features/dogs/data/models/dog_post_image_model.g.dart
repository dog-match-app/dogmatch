// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dog_post_image_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DogPostImageModel _$DogPostImageModelFromJson(Map<String, dynamic> json) =>
    DogPostImageModel(
      id: json['id'] as String,
      url: json['url'] as String,
      position: (json['position'] as num?)?.toInt() ?? 0,
      captions:
          (json['captions'] as List<dynamic>?)
              ?.map(
                (e) => DogPostCaptionModel.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
    );

Map<String, dynamic> _$DogPostImageModelToJson(DogPostImageModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'url': instance.url,
      'position': instance.position,
      'captions': instance.captions.map((e) => e.toJson()).toList(),
    };
