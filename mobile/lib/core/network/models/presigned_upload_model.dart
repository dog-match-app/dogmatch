import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'presigned_upload_model.g.dart';

/// `PresignedUploadDto` — resposta de `POST /files/presigned-upload`.
@JsonSerializable()
class PresignedUploadModel extends Equatable {
  const PresignedUploadModel({
    required this.uploadUrl,
    required this.publicUrl,
    required this.key,
    required this.expiresIn,
  });

  factory PresignedUploadModel.fromJson(Map<String, dynamic> json) =>
      _$PresignedUploadModelFromJson(json);

  /// URL assinada para o `PUT` do binário.
  final String uploadUrl;

  /// URL pública final do arquivo (download).
  final String publicUrl;

  /// Key do objeto no bucket (ex.: `dogs/uuid.jpg`).
  final String key;

  /// Validade da URL assinada, em segundos.
  final int expiresIn;

  Map<String, dynamic> toJson() => _$PresignedUploadModelToJson(this);

  @override
  List<Object?> get props => [uploadUrl, publicUrl, key, expiresIn];
}
