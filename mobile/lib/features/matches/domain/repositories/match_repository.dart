import 'package:dogmatch/features/matches/data/models/match_model.dart';

/// Contrato da lista de matches.
abstract class MatchRepository {
  /// `GET /matches?dogId=` — [dogId] filtra pelos matches do cão ativo.
  Future<List<MatchModel>> getMatches({String? dogId});

  /// Busca um match pelo id (fallback quando a rota de chat abre sem extra).
  Future<MatchModel?> findMatch(String matchId);
}
