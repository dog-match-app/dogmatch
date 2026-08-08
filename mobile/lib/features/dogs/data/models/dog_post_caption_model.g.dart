// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dog_post_caption_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DogPostCaptionModel _$DogPostCaptionModelFromJson(Map<String, dynamic> json) =>
    DogPostCaptionModel(
      id: json['id'] as String,
      text: json['text'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );

Map<String, dynamic> _$DogPostCaptionModelToJson(
  DogPostCaptionModel instance,
) => <String, dynamic>{
  'id': instance.id,
  'text': instance.text,
  'x': instance.x,
  'y': instance.y,
};
