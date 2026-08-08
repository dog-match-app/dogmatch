import 'package:dogmatch/features/dogs/domain/entities/dog_enums.dart';
import 'package:equatable/equatable.dart';

/// Ordenação dos resultados da busca (`orderBy` de `GET /discovery/search`).
enum SearchOrderBy {
  distance('distance', 'Distância'),
  recent('recent', 'Recentes');

  const SearchOrderBy(this.apiValue, this.labelPtBr);

  /// Valor enviado à API.
  final String apiValue;

  /// Rótulo exibido na UI.
  final String labelPtBr;
}

/// Filtros da busca estilo OLX (`GET /discovery/search`, §3.5.1 do contrato).
///
/// Campos `null` (ou coleções vazias) significam "não filtrar".
class SearchFilters extends Equatable {
  const SearchFilters({
    this.q = '',
    this.sex,
    this.sizes = const {},
    this.intent,
    this.ageMinYears,
    this.ageMaxYears,
    this.neutered,
    this.pedigree,
    this.radiusKm,
    this.orderBy,
  });

  /// Busca textual em nome + raça.
  final String q;

  final DogSex? sex;

  /// Um ou mais portes (enviados como CSV no parâmetro `size`).
  final Set<DogSize> sizes;

  /// Apenas [DogIntent.breeding] ou [DogIntent.friendship] — a API não aceita
  /// `BOTH` como filtro (perfis `BOTH` são incluídos pelo servidor nos dois
  /// casos). A UI só oferece essas duas opções.
  final DogIntent? intent;

  final int? ageMinYears;
  final int? ageMaxYears;

  /// `null` = não filtrar; `true` = apenas castrados.
  final bool? neutered;

  /// `null` = não filtrar; `true` = apenas com pedigree.
  final bool? pedigree;

  /// `null` = sem limite de distância.
  final int? radiusKm;

  /// `null` = default do servidor (distância quando o usuário tem
  /// localização; senão, mais recentes).
  final SearchOrderBy? orderBy;

  /// Sentinela do [copyWith] para diferenciar "não alterar" de "definir null".
  static const Object _unset = Object();

  /// Nº de filtros ativos — exclui [q] (campo de busca) e [orderBy]
  /// (ordenação não é filtro). Alimenta o badge do botão de filtros e o
  /// rótulo "Aplicar (N)".
  int get activeCount {
    var count = 0;
    if (sex != null) count++;
    if (sizes.isNotEmpty) count++;
    if (intent != null) count++;
    if (ageMinYears != null || ageMaxYears != null) count++;
    if (neutered != null) count++;
    if (pedigree != null) count++;
    if (radiusKm != null) count++;
    return count;
  }

  /// Query string do `GET /discovery/search` — só inclui parâmetros ativos.
  Map<String, dynamic> toQueryParams({
    String? dogId,
    bool excludeSwiped = false,
    required int page,
    required int limit,
  }) {
    final query = q.trim();
    final sortedSizes = [...sizes]
      ..sort((a, b) => a.index.compareTo(b.index));
    return <String, dynamic>{
      if (query.isNotEmpty) 'q': query,
      'sex': ?sex?.apiValue,
      if (sortedSizes.isNotEmpty)
        'size': sortedSizes.map((size) => size.apiValue).join(','),
      'intent': ?intent?.apiValue,
      'ageMinYears': ?ageMinYears,
      'ageMaxYears': ?ageMaxYears,
      'neutered': ?neutered,
      'pedigree': ?pedigree,
      'radiusKm': ?radiusKm,
      'orderBy': ?orderBy?.apiValue,
      'dogId': ?dogId,
      if (excludeSwiped) 'excludeSwiped': excludeSwiped,
      'page': page,
      'limit': limit,
    };
  }

  /// Cópia com alterações; campos anuláveis aceitam `null` explícito para
  /// limpar o filtro (sentinela interna diferencia "não passado" de `null`).
  SearchFilters copyWith({
    String? q,
    Object? sex = _unset,
    Set<DogSize>? sizes,
    Object? intent = _unset,
    Object? ageMinYears = _unset,
    Object? ageMaxYears = _unset,
    Object? neutered = _unset,
    Object? pedigree = _unset,
    Object? radiusKm = _unset,
    Object? orderBy = _unset,
  }) {
    return SearchFilters(
      q: q ?? this.q,
      sex: identical(sex, _unset) ? this.sex : sex as DogSex?,
      sizes: sizes ?? this.sizes,
      intent: identical(intent, _unset) ? this.intent : intent as DogIntent?,
      ageMinYears: identical(ageMinYears, _unset)
          ? this.ageMinYears
          : ageMinYears as int?,
      ageMaxYears: identical(ageMaxYears, _unset)
          ? this.ageMaxYears
          : ageMaxYears as int?,
      neutered: identical(neutered, _unset) ? this.neutered : neutered as bool?,
      pedigree: identical(pedigree, _unset) ? this.pedigree : pedigree as bool?,
      radiusKm: identical(radiusKm, _unset) ? this.radiusKm : radiusKm as int?,
      orderBy: identical(orderBy, _unset)
          ? this.orderBy
          : orderBy as SearchOrderBy?,
    );
  }

  /// Remove todos os filtros, preservando o texto de busca [q]
  /// (o campo de busca vive fora do sheet de filtros).
  SearchFilters cleared() => SearchFilters(q: q);

  @override
  List<Object?> get props => [
        q,
        sex,
        sizes,
        intent,
        ageMinYears,
        ageMaxYears,
        neutered,
        pedigree,
        radiusKm,
        orderBy,
      ];
}
