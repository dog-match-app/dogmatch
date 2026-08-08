import 'package:dogmatch/features/auth/data/models/user_model.dart';

/// Contrato de autenticação (`/auth/*` + `GET /users/me`).
abstract class AuthRepository {
  /// `POST /auth/login` — salva o par de tokens e devolve o usuário.
  Future<UserModel> login({required String email, required String password});

  /// `POST /auth/register` — salva o par de tokens e devolve o usuário.
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
  });

  /// `GET /users/me`.
  Future<UserModel> getMe();

  /// Existe sessão persistida no storage seguro?
  Future<bool> hasSession();

  /// `POST /auth/logout` (best-effort) + limpeza dos tokens locais.
  Future<void> logout();
}
