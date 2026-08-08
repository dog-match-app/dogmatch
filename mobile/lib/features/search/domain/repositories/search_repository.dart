import 'package:dogmatch/features/search/data/models/search_result_model.dart';
import 'package:dogmatch/features/search/domain/entities/search_filters.dart';

/// Contrato da busca com filtros estilo OLX.
abstract class SearchRepository {
  /// `GET /discovery/search` (§3.5.1 do contrato).
  ///
  /// [dogId] habilita a perspectiva do cão ativo (`myAction`/`matched` nos
  /// cards); [excludeSwiped] só é válido com [dogId].
  Future<SearchResultModel> search(
    SearchFilters filters, {
    String? dogId,
    bool excludeSwiped = false,
    int page = 1,
    int limit = 20,
  });
}
