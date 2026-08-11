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

  /// Última visita ao segmento "Matches" — matches criados depois disso
  /// contam como "novos" no badge da bottom bar; `null` = nunca visitou.
  Future<DateTime?> getLastSeenMatches();

  Future<void> setLastSeenMatches(DateTime seenAt);

  /// Última visita ao segmento "Curtidas" — curtidas recebidas depois disso
  /// contam como "novas" no badge da bottom bar; `null` = nunca visitou.
  Future<DateTime?> getLastSeenLikes();

  Future<void> setLastSeenLikes(DateTime seenAt);
}

@LazySingleton(as: AppPreferences)
class SharedPreferencesAppPreferences implements AppPreferences {
  SharedPreferencesAppPreferences(this._preferences);

  static const String discoveryRadiusKmKey = 'discovery_radius_km';
  static const String lastSeenMatchesKey = 'last_seen_matches';
  static const String lastSeenLikesKey = 'last_seen_likes';

  final SharedPreferencesAsync _preferences;

  @override
  Future<int?> getDiscoveryRadiusKm() =>
      _preferences.getInt(discoveryRadiusKmKey);

  @override
  Future<void> setDiscoveryRadiusKm(int radiusKm) =>
      _preferences.setInt(discoveryRadiusKmKey, radiusKm);

  @override
  Future<DateTime?> getLastSeenMatches() => _readInstant(lastSeenMatchesKey);

  @override
  Future<void> setLastSeenMatches(DateTime seenAt) =>
      _writeInstant(lastSeenMatchesKey, seenAt);

  @override
  Future<DateTime?> getLastSeenLikes() => _readInstant(lastSeenLikesKey);

  @override
  Future<void> setLastSeenLikes(DateTime seenAt) =>
      _writeInstant(lastSeenLikesKey, seenAt);

  Future<DateTime?> _readInstant(String key) async {
    final millis = await _preferences.getInt(key);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }

  Future<void> _writeInstant(String key, DateTime instant) =>
      _preferences.setInt(key, instant.toUtc().millisecondsSinceEpoch);
}
