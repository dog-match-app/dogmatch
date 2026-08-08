// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_card_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SearchCardModel _$SearchCardModelFromJson(Map<String, dynamic> json) =>
    SearchCardModel(
      dog: DogModel.fromJson(json['dog'] as Map<String, dynamic>),
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      owner: DogOwnerModel.fromJson(json['owner'] as Map<String, dynamic>),
      myAction: json['myAction'] as String?,
      matched: json['matched'] as bool?,
    );

Map<String, dynamic> _$SearchCardModelToJson(SearchCardModel instance) =>
    <String, dynamic>{
      'dog': instance.dog.toJson(),
      'distanceKm': ?instance.distanceKm,
      'owner': instance.owner.toJson(),
      'myAction': ?instance.myAction,
      'matched': ?instance.matched,
    };
