import 'package:dogmatch/features/owners/data/models/owner_profile_model.dart';

/// Contrato de acesso ao perfil público de um dono.
abstract class OwnersRepository {
  /// `GET /users/:id/profile`.
  Future<OwnerProfileModel> getOwnerProfile(String userId);
}
