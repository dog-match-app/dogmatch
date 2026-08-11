import 'package:dogmatch/features/matches/data/models/like_received_model.dart';

/// Contrato das curtidas recebidas (segmento "Curtidas" da aba Matches).
abstract class LikesRepository {
  /// `GET /swipes/received?dogId=` — likes recebidos sem resposta recíproca
  /// e sem match; [dogId] filtra pela perspectiva do cão ativo (a lista do
  /// segmento), sem ele vale para todos os meus cães (badge de atividade).
  Future<LikesReceivedModel> getReceived({String? dogId});
}
