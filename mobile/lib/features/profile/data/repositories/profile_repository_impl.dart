import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dogmatch/core/error/api_exception.dart';
import 'package:dogmatch/core/network/file_uploader.dart';
import 'package:dogmatch/features/auth/data/models/user_model.dart';
import 'package:dogmatch/features/profile/domain/repositories/profile_repository.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: ProfileRepository)
class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._dio, this._fileUploader);

  final Dio _dio;
  final FileUploader _fileUploader;

  @override
  Future<UserModel> getMe() {
    return guardApi(() async {
      final response = await _dio.get<Map<String, dynamic>>('/users/me');
      return UserModel.fromJson(response.data!);
    });
  }

  @override
  Future<UserModel> updateProfile({
    String? name,
    String? bio,
    String? phone,
    String? city,
    double? latitude,
    double? longitude,
    String? avatarUrl,
  }) {
    return guardApi(() async {
      final body = <String, dynamic>{
        'name': ?name,
        'bio': ?bio,
        'phone': ?phone,
        'city': ?city,
        'latitude': ?latitude,
        'longitude': ?longitude,
        'avatarUrl': ?avatarUrl,
      };
      final response =
          await _dio.patch<Map<String, dynamic>>('/users/me', data: body);
      return UserModel.fromJson(response.data!);
    });
  }

  @override
  Future<UserModel> uploadAvatar({
    required Uint8List bytes,
    required String contentType,
  }) async {
    final upload = await _fileUploader.uploadBytes(
      bytes: bytes,
      contentType: contentType,
      folder: 'avatars',
    );
    return updateProfile(avatarUrl: upload.publicUrl);
  }
}
