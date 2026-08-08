// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'presigned_upload_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PresignedUploadModel _$PresignedUploadModelFromJson(
  Map<String, dynamic> json,
) => PresignedUploadModel(
  uploadUrl: json['uploadUrl'] as String,
  publicUrl: json['publicUrl'] as String,
  key: json['key'] as String,
  expiresIn: (json['expiresIn'] as num).toInt(),
);

Map<String, dynamic> _$PresignedUploadModelToJson(
  PresignedUploadModel instance,
) => <String, dynamic>{
  'uploadUrl': instance.uploadUrl,
  'publicUrl': instance.publicUrl,
  'key': instance.key,
  'expiresIn': instance.expiresIn,
};
