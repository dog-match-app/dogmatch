import 'package:dio/dio.dart';

/// Exceção de domínio com mensagem amigável em PT-BR, mapeada a partir de
/// erros HTTP/rede do Dio.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.backendCode});

  factory ApiException.fromDioException(DioException exception) {
    switch (exception.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(
          'Tempo de conexão esgotado. Verifique sua internet e tente novamente.',
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          'Não foi possível conectar ao servidor. Verifique sua internet.',
        );
      case DioExceptionType.badCertificate:
        return const ApiException('Falha de segurança na conexão.');
      case DioExceptionType.cancel:
        return const ApiException('Operação cancelada.');
      case DioExceptionType.badResponse:
        return ApiException._fromResponse(exception);
      // `unknown` e tipos novos de versões futuras do Dio.
      default:
        return const ApiException(
          'Não foi possível conectar. Verifique sua internet e tente novamente.',
        );
    }
  }

  factory ApiException._fromResponse(DioException exception) {
    final statusCode = exception.response?.statusCode;
    final backendMessage = _backendMessage(exception.response?.data);
    final backendCode = backendMessage != null &&
            RegExp(r'^[A-Z0-9_]+$').hasMatch(backendMessage)
        ? backendMessage
        : null;
    final path = exception.requestOptions.path;

    String message;
    switch (statusCode) {
      case 400:
        message = backendCode == 'LOCATION_REQUIRED'
            ? 'Defina sua localização no perfil para descobrir cães por perto.'
            : 'Dados inválidos. Verifique os campos e tente novamente.';
      case 401:
        message = path.contains('/auth/login')
            ? 'E-mail ou senha inválidos.'
            : 'Sessão expirada. Entre novamente.';
      case 403:
        message = 'Você não tem permissão para acessar este recurso.';
      case 404:
        message = 'Não encontramos o que você procura.';
      case 409:
        message = 'Este e-mail já está em uso.';
      case 429:
        message = 'Muitas tentativas. Aguarde um instante e tente de novo.';
      default:
        message = statusCode != null && statusCode >= 500
            ? 'Erro no servidor. Tente novamente mais tarde.'
            : 'Erro inesperado. Tente novamente.';
    }
    return ApiException(
      message,
      statusCode: statusCode,
      backendCode: backendCode,
    );
  }

  /// Mensagem pronta para exibição ao usuário.
  final String message;

  final int? statusCode;

  /// Código simbólico devolvido pelo backend (ex.: `LOCATION_REQUIRED`).
  final String? backendCode;

  bool get isLocationRequired => backendCode == 'LOCATION_REQUIRED';

  static String? _backendMessage(dynamic data) {
    if (data is Map) {
      final message = data['message'];
      if (message is String && message.isNotEmpty) return message;
      if (message is List && message.isNotEmpty) return message.join('\n');
    }
    return null;
  }

  @override
  String toString() => 'ApiException(statusCode: $statusCode): $message';
}

/// Executa [run] convertendo qualquer [DioException] em [ApiException].
Future<T> guardApi<T>(Future<T> Function() run) async {
  try {
    return await run();
  } on DioException catch (exception) {
    throw ApiException.fromDioException(exception);
  }
}
