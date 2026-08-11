import 'package:dogmatch/app/di/injection.dart';
import 'package:dogmatch/core/services/location_service.dart';
import 'package:dogmatch/core/widgets/empty_state.dart';
import 'package:dogmatch/core/widgets/loading_indicator.dart';
import 'package:dogmatch/features/dogs/presentation/widgets/active_dog_selector.dart';
import 'package:dogmatch/features/search/domain/entities/search_filters.dart';
import 'package:dogmatch/features/search/presentation/cubit/search_cubit.dart';
import 'package:dogmatch/features/search/presentation/widgets/filter_sheet.dart';
import 'package:dogmatch/features/search/presentation/widgets/search_result_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<SearchCubit>()..search(),
      child: const _SearchView(),
    );
  }
}

class _SearchView extends StatefulWidget {
  const _SearchView();

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  final TextEditingController _queryController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _queryController.dispose();
    super.dispose();
  }

  /// Scroll infinito: dispara o loadMore a ~200px do fim da lista.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<SearchCubit>().loadMore();
    }
  }

  Future<void> _openFilters() async {
    final cubit = context.read<SearchCubit>();
    final result = await showModalBottomSheet<SearchFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SearchFilterSheet(initial: cubit.state.filters),
    );
    if (result == null) return;
    // Raio e ordenação por distância dependem da localização: pede a
    // permissão na hora e sincroniza antes de buscar; negada, a busca segue
    // e o estado de erro/lista cuida do resto.
    final needsLocation = result.radiusKm != null ||
        result.orderBy == SearchOrderBy.distance;
    if (needsLocation && mounted) {
      await getIt<LocationService>().ensurePermission(context: context);
    }
    await cubit.updateFilters(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar'),
        actions: const [ActiveDogSelector.compact()],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(68),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _queryController,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      hintText: 'Buscar por nome ou raça...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) =>
                        context.read<SearchCubit>().updateQuery(value),
                  ),
                ),
                BlocBuilder<SearchCubit, SearchState>(
                  buildWhen: (previous, current) =>
                      previous.filters != current.filters,
                  builder: (context, state) {
                    final count = state.filters.activeCount;
                    return IconButton(
                      tooltip: 'Filtros',
                      onPressed: _openFilters,
                      icon: Badge.count(
                        count: count,
                        isLabelVisible: count > 0,
                        child: const Icon(Icons.tune),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: BlocConsumer<SearchCubit, SearchState>(
        listener: (context, state) {
          // Erro com lista já carregada (ex.: falha do loadMore): SnackBar.
          if (state.status == SearchStatus.error &&
              state.items.isNotEmpty &&
              state.message != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(state.message!)));
          }
        },
        listenWhen: (previous, current) => previous.status != current.status,
        builder: (context, state) {
          if (state.status == SearchStatus.initial ||
              state.status == SearchStatus.loading) {
            return const LoadingIndicator();
          }
          if (state.status == SearchStatus.error && state.items.isEmpty) {
            return EmptyState(
              icon: Icons.error_outline,
              title: 'Não foi possível buscar',
              message: state.message,
              actionLabel: 'Tentar novamente',
              onAction: () => context.read<SearchCubit>().search(),
            );
          }
          if (state.items.isEmpty) {
            return EmptyState(
              icon: Icons.search_off,
              title: 'Nenhum cãozinho encontrado',
              message: 'Ajuste os filtros ou tente buscar por outro termo.',
              actionLabel: 'Ajustar filtros',
              onAction: _openFilters,
            );
          }
          final showFooter = state.status == SearchStatus.loadingMore;
          return RefreshIndicator(
            onRefresh: () => context.read<SearchCubit>().refresh(),
            child: ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: state.items.length + 1 + (showFooter ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      state.total == 1
                          ? '1 cão encontrado'
                          : '${state.total} cães encontrados',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  );
                }
                final itemIndex = index - 1;
                if (itemIndex >= state.items.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  );
                }
                final card = state.items[itemIndex];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SearchResultCard(
                    card: card,
                    onTap: () => context.push(
                      '/search/dogs/${card.dog.id}',
                      extra: card,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
