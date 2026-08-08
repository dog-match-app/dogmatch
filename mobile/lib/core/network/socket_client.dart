import 'package:dogmatch/core/config/app_config.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// Wrapper fino sobre o `socket_io_client` para o namespace `/chat`.
///
/// A conexão é autenticada no handshake com `auth: {'token': accessToken}`.
/// Se o socket estiver desconectado, o chat usa o fallback REST — por isso
/// todos os métodos são tolerantes a socket nulo/desconectado.
class SocketClient {
  io.Socket? _socket;

  bool get isConnected => _socket?.connected ?? false;

  /// Conecta (ou reconecta) ao namespace `/chat`.
  void connect({required String accessToken}) {
    if (_socket != null && isConnected) return;
    disconnect();
    _socket = io.io(
      '${AppConfig.wsUrl}/chat',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': accessToken})
          .build(),
    );
    _socket!.connect();
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }

  void emit(String event, dynamic data) {
    _socket?.emit(event, data);
  }

  void on(String event, void Function(dynamic data) handler) {
    _socket?.on(event, handler);
  }

  void off(String event, [void Function(dynamic data)? handler]) {
    _socket?.off(event, handler);
  }

  /// Registra callback de (re)conexão — útil para reentrar em rooms.
  void onConnect(void Function() handler) {
    _socket?.onConnect((_) => handler());
  }
}
