import 'package:dio/dio.dart';
import 'package:dogmatch/core/config/app_config.dart';
import 'package:dogmatch/core/network/auth_interceptor.dart';
import 'package:dogmatch/core/network/auth_session_manager.dart';
import 'package:dogmatch/core/storage/token_storage.dart';
import 'package:flutter/foundation.dart';

/// Fábrica do [Dio] autenticado usado por todos os repositórios REST.
class DioClient {
  const DioClient._();

  static Dio create({
    required TokenStorage tokenStorage,
    required AuthSessionManager sessionManager,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiV1,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
      ),
    );

    dio.interceptors.add(AuthInterceptor(tokenStorage, sessionManager, dio));

    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          logPrint: (message) => debugPrint('$message'),
        ),
      );
    }

    return dio;
  }
}
