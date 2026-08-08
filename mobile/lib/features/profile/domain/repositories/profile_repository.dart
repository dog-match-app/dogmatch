import 'dart:typed_data';

import 'package:dogmatch/features/auth/data/models/user_model.dart';

/// Contrato do perfil do dono (`/users/me` + upload de avatar).
abstract class ProfileRepository {
  /// `GET /users/me`.
  Future<UserModel> getMe();

  /// `PATCH /users/me` — envia apenas os campos não nulos.
  Future<UserModel> updateProfile({
    String? name,
    String? bio,
    String? phone,
    String? city,
    double? latitude,
    double? longitude,
    String? avatarUrl,
  });

  /// Upload presigned (`folder: avatars`) + `PATCH /users/me { avatarUrl }`.
  Future<UserModel> uploadAvatar({
    required Uint8List bytes,
    required String contentType,
  });
}
