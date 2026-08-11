import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Contrato fino das preferências locais NÃO sensíveis do app (nada de
/// token — segredo é `TokenStorage`). Injetável para os testes mockarem
/// sem tocar no plugin `shared_preferences`.
abstract class AppPreferences {
  /// Raio máximo (km) da aba Descobrir; `null` quando nunca configurado
  /// (o Descobrir usa o padrão do backend, 50).
  Future<int?> getDiscoveryRadiusKm();

  Future<void> setDiscoveryRadiusKm(int radiusKm);
}

@LazySingleton(as: AppPreferences)
class SharedPreferencesAppPreferences implements AppPreferences {
  SharedPreferencesAppPreferences(this._preferences);

  static const String discoveryRadiusKmKey = 'discovery_radius_km';

  final SharedPreferencesAsync _preferences;

  @override
  Future<int?> getDiscoveryRadiusKm() =>
      _preferences.getInt(discoveryRadiusKmKey);

  @override
  Future<void> setDiscoveryRadiusKm(int radiusKm) =>
      _preferences.setInt(discoveryRadiusKmKey, radiusKm);
}
