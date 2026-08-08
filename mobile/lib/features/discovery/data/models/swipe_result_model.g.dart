// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'swipe_result_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SwipeResultModel _$SwipeResultModelFromJson(Map<String, dynamic> json) =>
    SwipeResultModel(
      matched: json['matched'] as bool,
      match: json['match'] == null
          ? null
          : MatchModel.fromJson(json['match'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$SwipeResultModelToJson(SwipeResultModel instance) =>
    <String, dynamic>{
      'matched': instance.matched,
      'match': ?instance.match?.toJson(),
    };
