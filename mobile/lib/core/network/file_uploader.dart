import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dogmatch/core/error/api_exception.dart';
import 'package:dogmatch/core/network/models/presigned_upload_model.dart';
import 'package:injectable/injectable.dart';

/// Fluxo de upload direto ao storage (S3/MinIO) via presigned URL:
///
/// 1. `POST /files/presigned-upload { contentType, folder }` (Dio autenticado);
/// 2. `PUT` do binário na URL assinada com um Dio **sem interceptors**
///    (o header `Authorization` corromperia a assinatura);
/// 3. o chamador registra `key`/`publicUrl` na API.
@lazySingleton
class FileUploader {
  FileUploader(this._dio);

  /// Dio autenticado da API.
  final Dio _dio;

  /// Dio limpo, sem interceptors, exclusivo para o PUT no storage.
  final Dio _uploadDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
    ),
  );

  /// Sobe [bytes] para a pasta [folder] (`avatars` | `dogs`) e devolve o
  /// [PresignedUploadModel] com `key` e `publicUrl` para registro na API.
  Future<PresignedUploadModel> uploadBytes({
    required Uint8List bytes,
    required String contentType,
    required String folder,
  }) {
    return guardApi(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/files/presigned-upload',
        data: {'contentType': contentType, 'folder': folder},
      );
      final presigned = PresignedUploadModel.fromJson(response.data!);

      await _uploadDio.put<void>(
        presigned.uploadUrl,
        data: bytes,
        options: Options(
          contentType: contentType,
          headers: {Headers.contentLengthHeader: bytes.length},
        ),
      );
      return presigned;
    });
  }

  /// Content-Type a partir da extensão do arquivo (fallback `image/jpeg`).
  static String guessImageContentType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}
