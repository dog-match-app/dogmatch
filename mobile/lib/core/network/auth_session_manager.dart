import 'dart:async';

import 'package:injectable/injectable.dart';

/// Ponte entre a camada de rede e o AuthBloc: quando o refresh de token
/// falha definitivamente, o interceptor notifica por aqui e o AuthBloc
/// dispara o logout global — sem criar dependência circular.
@lazySingleton
class AuthSessionManager {
  final StreamController<void> _controller = StreamController<void>.broadcast();

  Stream<void> get onSessionExpired => _controller.stream;

  void notifySessionExpired() {
    if (!_controller.isClosed) _controller.add(null);
  }

  @disposeMethod
  Future<void> dispose() => _controller.close();
}
