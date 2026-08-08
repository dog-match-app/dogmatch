// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dog_post_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DogPostModel _$DogPostModelFromJson(Map<String, dynamic> json) => DogPostModel(
  id: json['id'] as String,
  dogId: json['dogId'] as String,
  type: $enumDecode(_$DogPostTypeEnumMap, json['type']),
  text: json['text'] as String?,
  images:
      (json['images'] as List<dynamic>?)
          ?.map((e) => DogPostImageModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$DogPostModelToJson(DogPostModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'dogId': instance.dogId,
      'type': _$DogPostTypeEnumMap[instance.type]!,
      'text': ?instance.text,
      'images': instance.images.map((e) => e.toJson()).toList(),
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

const _$DogPostTypeEnumMap = {
  DogPostType.text: 'TEXT',
  DogPostType.image: 'IMAGE',
  DogPostType.imageText: 'IMAGE_TEXT',
  DogPostType.carousel: 'CAROUSEL',
};
