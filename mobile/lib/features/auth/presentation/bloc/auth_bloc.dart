import 'dart:async';

import 'package:dogmatch/core/network/auth_session_manager.dart';
import 'package:dogmatch/core/network/socket_client.dart';
import 'package:dogmatch/features/auth/data/models/user_model.dart';
import 'package:dogmatch/features/auth/domain/repositories/auth_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

part 'auth_event.dart';
part 'auth_state.dart';

/// Bloc global de autenticação: `unknown → authenticated | unauthenticated`.
/// O go_router escuta o stream deste bloc para os redirects.
@lazySingleton
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._authRepository, this._sessionManager, this._socketClient)
      : super(const AuthUnknown()) {
    on<AuthAppStarted>(_onAppStarted);
    on<AuthLoggedIn>(_onLoggedIn);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthSessionExpired>(_onSessionExpired);

    _sessionExpiredSubscription = _sessionManager.onSessionExpired
        .listen((_) => add(const AuthSessionExpired()));
  }

  final AuthRepository _authRepository;
  final AuthSessionManager _sessionManager;
  final SocketClient _socketClient;

  late final StreamSubscription<void> _sessionExpiredSubscription;

  Future<void> _onAppStarted(
    AuthAppStarted event,
    Emitter<AuthState> emit,
  ) async {
    if (!await _authRepository.hasSession()) {
      emit(const AuthUnauthenticated());
      return;
    }
    try {
      final user = await _authRepository.getMe();
      emit(AuthAuthenticated(user));
    } on Exception {
      emit(const AuthUnauthenticated());
    }
  }

  void _onLoggedIn(AuthLoggedIn event, Emitter<AuthState> emit) {
    emit(AuthAuthenticated(event.user));
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    _socketClient.disconnect();
    await _authRepository.logout();
    emit(const AuthUnauthenticated());
  }

  void _onSessionExpired(AuthSessionExpired event, Emitter<AuthState> emit) {
    _socketClient.disconnect();
    emit(const AuthUnauthenticated());
  }

  @override
  Future<void> close() async {
    await _sessionExpiredSubscription.cancel();
    return super.close();
  }
}
