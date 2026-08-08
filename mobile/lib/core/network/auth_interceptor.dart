import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dogmatch/core/config/app_config.dart';
import 'package:dogmatch/core/network/auth_session_manager.dart';
import 'package:dogmatch/core/storage/token_storage.dart';

/// Injeta o bearer token e renova a sessão em respostas 401.
///
/// Garante **uma única** tentativa de refresh por vez: chamadas concorrentes
/// que tomarem 401 aguardam o mesmo [Completer] e reutilizam o resultado.
/// Se o refresh falhar, limpa o storage e notifica o [AuthSessionManager]
/// (o AuthBloc escuta e dispara o logout global).
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokenStorage, this._sessionManager, this._dio);

  static const String _retriedFlag = 'auth_retried';

  final TokenStorage _tokenStorage;
  final AuthSessionManager _sessionManager;

  /// Dio principal, usado para repetir a request original após o refresh.
  final Dio _dio;

  /// Dio "limpo" (sem interceptors) exclusivo para `POST /auth/refresh`.
  final Dio _refreshDio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiV1,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
    ),
  );

  Completer<bool>? _refreshCompleter;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final accessToken = await _tokenStorage.readAccessToken();
    if (accessToken != null && accessToken.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final isUnauthorized = err.response?.statusCode == 401;
    final isAuthRoute = err.requestOptions.path.contains('/auth/');
    final alreadyRetried = err.requestOptions.extra[_retriedFlag] == true;

    if (!isUnauthorized || isAuthRoute || alreadyRetried) {
      handler.next(err);
      return;
    }

    final refreshed = await _refreshTokens();
    if (!refreshed) {
      _sessionManager.notifySessionExpired();
      handler.next(err);
      return;
    }

    try {
      final requestOptions = err.requestOptions..extra[_retriedFlag] = true;
      // `fetch` passa novamente pelos interceptors; o onRequest injeta o
      // novo access token.
      final response = await _dio.fetch<dynamic>(requestOptions);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  /// Single-flight: a primeira chamada dispara o refresh, as demais
  /// aguardam o mesmo future.
  Future<bool> _refreshTokens() {
    final inFlight = _refreshCompleter;
    if (inFlight != null) return inFlight.future;

    final completer = Completer<bool>();
    _refreshCompleter = completer;

    _performRefresh().then(completer.complete).catchError((Object _) {
      completer.complete(false);
    }).whenComplete(() {
      _refreshCompleter = null;
    });

    return completer.future;
  }

  Future<bool> _performRefresh() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await _tokenStorage.clear();
      return false;
    }
    try {
      final response = await _refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final data = response.data;
      final newAccessToken = data?['accessToken'] as String?;
      final newRefreshToken = data?['refreshToken'] as String?;
      if (newAccessToken == null || newRefreshToken == null) {
        await _tokenStorage.clear();
        return false;
      }
      await _tokenStorage.saveTokens(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
      );
      return true;
    } on DioException {
      await _tokenStorage.clear();
      return false;
    }
  }
}
