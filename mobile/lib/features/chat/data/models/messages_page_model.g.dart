// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'messages_page_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MessagesPageModel _$MessagesPageModelFromJson(Map<String, dynamic> json) =>
    MessagesPageModel(
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => MessageModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      nextCursor: json['nextCursor'] as String?,
    );

Map<String, dynamic> _$MessagesPageModelToJson(MessagesPageModel instance) =>
    <String, dynamic>{
      'items': instance.items.map((e) => e.toJson()).toList(),
      'nextCursor': ?instance.nextCursor,
    };
