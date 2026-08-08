import 'package:dio/dio.dart';
import 'package:dogmatch/core/network/auth_session_manager.dart';
import 'package:dogmatch/core/network/dio_client.dart';
import 'package:dogmatch/core/network/socket_client.dart';
import 'package:dogmatch/core/storage/token_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';

/// Registra dependências de terceiros / construídas por fábrica.
@module
abstract class RegisterModule {
  @lazySingleton
  FlutterSecureStorage get secureStorage => const FlutterSecureStorage();

  @lazySingleton
  Dio dio(TokenStorage tokenStorage, AuthSessionManager sessionManager) =>
      DioClient.create(
        tokenStorage: tokenStorage,
        sessionManager: sessionManager,
      );

  @lazySingleton
  SocketClient get socketClient => SocketClient();
}
