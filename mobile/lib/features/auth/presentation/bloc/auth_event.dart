part of 'auth_bloc.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Disparado no boot: decide entre sessão válida e login.
final class AuthAppStarted extends AuthEvent {
  const AuthAppStarted();
}

/// Login/registro concluído com sucesso.
final class AuthLoggedIn extends AuthEvent {
  const AuthLoggedIn(this.user);

  final UserModel user;

  @override
  List<Object?> get props => [user];
}

/// Usuário pediu para sair.
final class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

/// Refresh de token falhou definitivamente (sessão inválida).
final class AuthSessionExpired extends AuthEvent {
  const AuthSessionExpired();
}
