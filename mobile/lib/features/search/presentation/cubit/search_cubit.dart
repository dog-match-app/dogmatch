import 'dart:async';

import 'package:dogmatch/core/error/api_exception.dart';
import 'package:dogmatch/core/services/location_service.dart';
import 'package:dogmatch/features/auth/data/models/user_model.dart';
import 'package:dogmatch/features/discovery/presentation/cubit/active_dog_cubit.dart';
import 'package:dogmatch/features/search/data/models/search_card_model.dart';
import 'package:dogmatch/features/search/domain/entities/search_filters.dart';
import 'package:dogmatch/features/search/domain/repositories/search_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

part 'search_state.dart';

/// Busca com filtros estilo OLX: lista paginada com scroll infinito.
///
/// Usa o cão ativo ([ActiveDogCubit]) como `dogId` para habilitar os badges
/// `myAction`/`matched` nos cards; nunca envia `excludeSwiped` — o ponto da
/// busca é mostrar tudo, inclusive cães já swipados.
@injectable
class SearchCubit extends Cubit<SearchState> {
  SearchCubit(
    this._searchRepository,
    this._activeDogCubit,
    this._locationService,
  ) : super(const SearchState()) {
    _activeDogSubscription = _activeDogCubit.stream.listen((activeState) {
      final dog = activeState.active;
      if (dog != null && dog.id != _dogId) search();
    });
    _locationSyncSubscription =
        _locationService.onLocationSynced.listen((_) {
      if (state.locationRequired) search();
    });
  }

  static const Duration debounceDuration = Duration(milliseconds: 400);
  static const int _pageSize = 20;

  final SearchRepository _searchRepository;
  final ActiveDogCubit _activeDogCubit;
  final LocationService _locationService;

  late final StreamSubscription<ActiveDogState> _activeDogSubscription;
  late final StreamSubscription<UserModel> _locationSyncSubscription;

  Timer? _debounce;

  /// Cão usado na última busca — a perspectiva dos badges da lista atual.
  String? _dogId;

  /// Identifica a busca mais recente; respostas de buscas antigas (ex.: um
  /// debounce que resolveu depois de uma nova busca) são descartadas.
  int _requestId = 0;

  /// Busca a página 1 com os filtros atuais (reseta a lista acumulada).
  Future<void> search() async {
    _debounce?.cancel();
    final requestId = ++_requestId;
    emit(state.copyWith(status: SearchStatus.loading));
    await _activeDogCubit.ensureLoaded();
    if (isClosed || requestId != _requestId) return;
    _dogId = _activeDogCubit.state.active?.id;
    try {
      final result = await _searchRepository.search(
        state.filters,
        dogId: _dogId,
        excludeSwiped: false,
        page: 1,
        limit: _pageSize,
      );
      if (isClosed || requestId != _requestId) return;
      emit(
        state.copyWith(
          status: SearchStatus.success,
          items: result.items,
          page: result.page,
          total: result.total,
          hasMore: result.hasMore,
        ),
      );
    } on ApiException catch (exception) {
      if (isClosed || requestId != _requestId) return;
      emit(
        state.copyWith(
          status: SearchStatus.error,
          message: exception.message,
          locationRequired: exception.isLocationRequired,
        ),
      );
    }
  }

  /// Carrega a próxima página e acumula na lista; ignorado quando não há
  /// mais páginas ou quando já existe carregamento em andamento.
  Future<void> loadMore() async {
    if (!state.hasMore) return;
    if (state.status == SearchStatus.loading ||
        state.status == SearchStatus.loadingMore) {
      return;
    }
    final requestId = ++_requestId;
    emit(state.copyWith(status: SearchStatus.loadingMore));
    try {
      final result = await _searchRepository.search(
        state.filters,
        dogId: _activeDogCubit.state.active?.id,
        excludeSwiped: false,
        page: state.page + 1,
        limit: _pageSize,
      );
      if (isClosed || requestId != _requestId) return;
      emit(
        state.copyWith(
          status: SearchStatus.success,
          items: [...state.items, ...result.items],
          page: result.page,
          total: result.total,
          hasMore: result.hasMore,
        ),
      );
    } on ApiException catch (exception) {
      if (isClosed || requestId != _requestId) return;
      // Mantém os itens acumulados; a UI mostra a mensagem sem perder a lista.
      emit(
        state.copyWith(
          status: SearchStatus.error,
          message: exception.message,
          locationRequired: exception.isLocationRequired,
        ),
      );
    }
  }

  /// Aplica os filtros do sheet e refaz a busca.
  Future<void> updateFilters(SearchFilters filters) {
    emit(state.copyWith(filters: filters));
    return search();
  }

  /// Atualiza o texto de busca com debounce de [debounceDuration].
  void updateQuery(String query) {
    final normalized = query.trim();
    if (normalized == state.filters.q) return;
    emit(state.copyWith(filters: state.filters.copyWith(q: normalized)));
    _debounce?.cancel();
    _debounce = Timer(debounceDuration, search);
  }

  /// Pull-to-refresh: refaz a busca da página 1.
  Future<void> refresh() => search();

  @override
  Future<void> close() async {
    _debounce?.cancel();
    await _activeDogSubscription.cancel();
    await _locationSyncSubscription.cancel();
    return super.close();
  }
}
