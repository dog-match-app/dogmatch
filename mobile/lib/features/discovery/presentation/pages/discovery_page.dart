import 'dart:math' as math;

import 'package:dogmatch/app/di/injection.dart';
import 'package:dogmatch/core/services/location_service.dart';
import 'package:dogmatch/core/widgets/empty_state.dart';
import 'package:dogmatch/core/widgets/loading_indicator.dart';
import 'package:dogmatch/features/discovery/data/models/discovery_card_model.dart';
import 'package:dogmatch/features/discovery/domain/entities/swipe_action.dart';
import 'package:dogmatch/features/discovery/presentation/cubit/discovery_cubit.dart';
import 'package:dogmatch/features/discovery/presentation/widgets/discovery_dog_card.dart';
import 'package:dogmatch/features/discovery/presentation/widgets/match_dialog.dart';
import 'package:dogmatch/features/dogs/presentation/widgets/active_dog_selector.dart';
import 'package:dogmatch/features/search/data/models/search_card_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:go_router/go_router.dart';

class DiscoveryPage extends StatelessWidget {
  const DiscoveryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<DiscoveryCubit>()..init(),
      child: const _DiscoveryView(),
    );
  }
}

class _DiscoveryView extends StatefulWidget {
  const _DiscoveryView();

  @override
  State<_DiscoveryView> createState() => _DiscoveryViewState();
}

class _DiscoveryViewState extends State<_DiscoveryView> {
  final CardSwiperController _swiperController = CardSwiperController();

  @override
  void dispose() {
    _swiperController.dispose();
    super.dispose();
  }

  /// Abre o detalhe completo do card (ENTRADA na cadeia detalhe↔dono, por
  /// isso `push`) e sincroniza o deck na volta: o pop do detalhe devolve o
  /// `myAction` final — se o usuário curtiu/passou lá dentro, o card não
  /// pode continuar no deck. O dialog de match já foi mostrado no detalhe.
  Future<void> _openDetails(
    BuildContext context,
    DiscoveryCardModel card,
  ) async {
    final cubit = context.read<DiscoveryCubit>();
    final action = await context.push<String>(
      '/search/dogs/${card.dog.id}',
      extra: SearchCardModel.fromDiscoveryCard(card),
    );
    if (action != null) await cubit.removeCard(card.dog.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Descobrir'),
        actions: const [ActiveDogSelector.compact()],
      ),
      body: BlocConsumer<DiscoveryCubit, DiscoveryState>(
        listener: (context, state) async {
          if (state.swipeError != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(state.swipeError!)));
            context.read<DiscoveryCubit>().clearSwipeError();
          }
          if (state.pendingMatch != null) {
            final match = state.pendingMatch!;
            context.read<DiscoveryCubit>().clearPendingMatch();
            await showDialog<void>(
              context: context,
              builder: (_) => MatchDialog(match: match),
            );
          }
        },
        builder: (context, state) {
          switch (state.status) {
            case DiscoveryStatus.initial:
            case DiscoveryStatus.loading:
              return const LoadingIndicator();
            case DiscoveryStatus.noDogs:
              return EmptyState(
                icon: Icons.pets,
                title: 'Cadastre seu primeiro cão',
                message:
                    'Para descobrir cãezinhos por perto, você precisa de um '
                    'perfil para o seu cão.',
                actionLabel: 'Cadastrar meu cão',
                onAction: () async {
                  final cubit = context.read<DiscoveryCubit>();
                  await context.push('/dogs/new');
                  cubit.init();
                },
              );
            case DiscoveryStatus.locationRequired:
              return EmptyState(
                icon: Icons.location_off_outlined,
                title: 'Precisamos da sua localização',
                message:
                    'Permita o acesso à localização para encontrarmos cães '
                    'próximos de você.',
                actionLabel: 'Ativar localização',
                onAction: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final result = await getIt<LocationService>()
                      .ensurePermission(context: context);
                  // Concedida + sincronizada ⇒ o cubit recarrega sozinho
                  // via onLocationSynced; deniedForever já mostrou o dialog.
                  if (!result.synced &&
                      result.status !=
                          LocationSyncStatus.permissionDeniedForever &&
                      result.errorMessage != null) {
                    messenger
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(content: Text(result.errorMessage!)),
                      );
                  }
                },
              );
            case DiscoveryStatus.error:
              return EmptyState(
                icon: Icons.error_outline,
                title: 'Algo deu errado',
                message: state.errorMessage,
                actionLabel: 'Tentar novamente',
                onAction: () => context.read<DiscoveryCubit>().refreshDeck(),
              );
            case DiscoveryStatus.loaded:
              if (state.cards.isEmpty) {
                return EmptyState(
                  icon: Icons.pets,
                  title: 'Sem cãezinhos por perto',
                  message:
                      'Por enquanto não há novos cães na sua região. Volte '
                      'mais tarde!',
                  actionLabel: 'Atualizar',
                  onAction: () =>
                      context.read<DiscoveryCubit>().refreshDeck(),
                );
              }
              return SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: CardSwiper(
                        key: ValueKey(state.deckKey),
                        controller: _swiperController,
                        cardsCount: state.cards.length,
                        numberOfCardsDisplayed:
                            math.min(3, state.cards.length),
                        isLoop: false,
                        padding:
                            const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        allowedSwipeDirection:
                            const AllowedSwipeDirection.only(
                          left: true,
                          right: true,
                        ),
                        onSwipe: (previousIndex, currentIndex, direction) {
                          context.read<DiscoveryCubit>().onSwiped(
                                state.cards[previousIndex],
                                direction == CardSwiperDirection.right
                                    ? SwipeAction.like
                                    : SwipeAction.pass,
                              );
                          return true;
                        },
                        onEnd: () =>
                            context.read<DiscoveryCubit>().onDeckFinished(),
                        cardBuilder: (context, index, _, _) =>
                            DiscoveryDogCard(
                          card: state.cards[index],
                          onOpenDetails: () =>
                              _openDetails(context, state.cards[index]),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16, top: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FloatingActionButton(
                            heroTag: 'discovery_pass',
                            onPressed: () => _swiperController
                                .swipe(CardSwiperDirection.left),
                            backgroundColor:
                                Theme.of(context).colorScheme.surface,
                            foregroundColor:
                                Theme.of(context).colorScheme.error,
                            child: const Icon(Icons.close),
                          ),
                          const SizedBox(width: 32),
                          FloatingActionButton(
                            heroTag: 'discovery_like',
                            onPressed: () => _swiperController
                                .swipe(CardSwiperDirection.right),
                            child: const Icon(Icons.favorite),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
          }
        },
      ),
    );
  }
}
