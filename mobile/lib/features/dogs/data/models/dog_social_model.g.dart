// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dog_social_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DogSocialModel _$DogSocialModelFromJson(Map<String, dynamic> json) =>
    DogSocialModel(
      whatsapp: json['whatsapp'] as String?,
      instagram: json['instagram'] as String?,
      pinterest: json['pinterest'] as String?,
      telegram: json['telegram'] as String?,
    );

Map<String, dynamic> _$DogSocialModelToJson(DogSocialModel instance) =>
    <String, dynamic>{
      'whatsapp': ?instance.whatsapp,
      'instagram': ?instance.instagram,
      'pinterest': ?instance.pinterest,
      'telegram': ?instance.telegram,
    };
