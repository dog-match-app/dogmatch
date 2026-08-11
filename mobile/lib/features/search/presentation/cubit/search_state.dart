part of 'search_cubit.dart';

enum SearchStatus { initial, loading, loadingMore, success, error }

class SearchState extends Equatable {
  const SearchState({
    this.status = SearchStatus.initial,
    this.filters = const SearchFilters(),
    this.items = const [],
    this.page = 1,
    this.total = 0,
    this.hasMore = false,
    this.locationRequired = false,
    this.message,
  });

  final SearchStatus status;
  final SearchFilters filters;

  /// Resultados acumulados de todas as páginas carregadas.
  final List<SearchCardModel> items;

  final int page;
  final int total;
  final bool hasMore;

  /// O último erro foi `LOCATION_REQUIRED` — sincronizada a localização
  /// ([LocationService.onLocationSynced]), a busca refaz sozinha.
  final bool locationRequired;

  /// Mensagem de erro pronta para a UI (PT-BR, via [ApiException]).
  final String? message;

  SearchState copyWith({
    SearchStatus? status,
    SearchFilters? filters,
    List<SearchCardModel>? items,
    int? page,
    int? total,
    bool? hasMore,
    bool locationRequired = false,
    String? message,
  }) {
    return SearchState(
      status: status ?? this.status,
      filters: filters ?? this.filters,
      items: items ?? this.items,
      page: page ?? this.page,
      total: total ?? this.total,
      hasMore: hasMore ?? this.hasMore,
      locationRequired: locationRequired,
      message: message,
    );
  }

  @override
  List<Object?> get props =>
      [status, filters, items, page, total, hasMore, locationRequired, message];
}
