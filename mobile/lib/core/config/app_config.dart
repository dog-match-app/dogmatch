/// Configuração global do app.
///
/// A URL base da API é definida em build time via `--dart-define`:
/// `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000`
class AppConfig {
  const AppConfig._();

  /// Base do backend (sem sufixo de versão). `10.0.2.2` é o localhost da
  /// máquina visto de dentro do emulador Android.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  /// Base REST versionada.
  static String get apiV1 => '$apiBaseUrl/api/v1';

  /// Base do Socket.IO (namespaces são anexados ao path, ex.: `/chat`).
  static String get wsUrl => apiBaseUrl;
}
