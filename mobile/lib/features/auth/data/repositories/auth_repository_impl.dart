import 'package:dio/dio.dart';
import 'package:dogmatch/core/error/api_exception.dart';
import 'package:dogmatch/core/storage/token_storage.dart';
import 'package:dogmatch/features/auth/data/models/auth_response_model.dart';
import 'package:dogmatch/features/auth/data/models/user_model.dart';
import 'package:dogmatch/features/auth/domain/repositories/auth_repository.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: AuthRepository)
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._dio, this._tokenStorage);

  final Dio _dio;
  final TokenStorage _tokenStorage;

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) {
    return guardApi(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': email, 'password': password},
      );
      return _persistSession(AuthResponseModel.fromJson(response.data!));
    });
  }

  @override
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
  }) {
    return guardApi(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: {'name': name, 'email': email, 'password': password},
      );
      return _persistSession(AuthResponseModel.fromJson(response.data!));
    });
  }

  @override
  Future<UserModel> getMe() {
    return guardApi(() async {
      final response = await _dio.get<Map<String, dynamic>>('/users/me');
      return UserModel.fromJson(response.data!);
    });
  }

  @override
  Future<bool> hasSession() => _tokenStorage.hasSession();

  @override
  Future<void> logout() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await _dio.post<void>(
          '/auth/logout',
          data: {'refreshToken': refreshToken},
        );
      } on DioException {
        // Best-effort: mesmo sem rede o logout local acontece.
      }
    }
    await _tokenStorage.clear();
  }

  Future<UserModel> _persistSession(AuthResponseModel auth) async {
    await _tokenStorage.saveTokens(
      accessToken: auth.accessToken,
      refreshToken: auth.refreshToken,
    );
    return auth.user;
  }
}
