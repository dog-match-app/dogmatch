import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dogmatch/app/di/injection.dart';
import 'package:dogmatch/core/services/app_notifications_service.dart';
import 'package:dogmatch/core/services/location_service.dart';
import 'package:dogmatch/core/utils/relative_time.dart';
import 'package:dogmatch/core/widgets/empty_state.dart';
import 'package:dogmatch/core/widgets/loading_indicator.dart';
import 'package:dogmatch/features/discovery/presentation/widgets/match_dialog.dart';
import 'package:dogmatch/features/dogs/presentation/widgets/active_dog_selector.dart';
import 'package:dogmatch/features/matches/data/models/like_received_model.dart';
import 'package:dogmatch/features/matches/data/models/match_model.dart';
import 'package:dogmatch/features/matches/presentation/cubit/activity_badge_cubit.dart';
import 'package:dogmatch/features/matches/presentation/cubit/likes_cubit.dart';
import 'package:dogmatch/features/matches/presentation/cubit/matches_cubit.dart';
import 'package:dogmatch/features/matches/presentation/widgets/like_received_card.dart';
import 'package:dogmatch/features/search/data/models/search_card_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Segmentos da aba: a lista de matches e as curtidas recebidas.
enum _MatchesSegment { matches, likes }

class MatchesPage extends StatelessWidget {
  const MatchesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<MatchesCubit>()..load()),
        BlocProvider(create: (_) => getIt<LikesCubit>()..load()),
      ],
      child: const _MatchesView(),
    );
  }
}

class _MatchesView extends StatefulWidget {
  const _MatchesView();

  @override
  State<_MatchesView> createState() => _MatchesViewState();
}

class _MatchesViewState extends State<_MatchesView> {
  _MatchesSegment _segment = _MatchesSegment.matches;

  @override
  void initState() {
    super.initState();
    // Segmento inicial visível: os matches atuais deixam de contar como
    // "novos" no badge da bottom bar.
    unawaited(getIt<ActivityBadgeCubit>().markMatchesSeen());
  }

  void _onSegmentChanged(_MatchesSegment segment) {
    setState(() => _segment = segment);
    final badge = getIt<ActivityBadgeCubit>();
    unawaited(
      segment == _MatchesSegment.matches
          ? badge.markMatchesSeen()
          : badge.markLikesSeen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Matches'),
        actions: const [ActiveDogSelector.compact()],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SegmentedButton<_MatchesSegment>(
              segments: const [
                ButtonSegment(
                  value: _MatchesSegment.matches,
                  icon: Icon(Icons.pets),
                  label: Text('Matches'),
                ),
                ButtonSegment(
                  value: _MatchesSegment.likes,
                  icon: Icon(Icons.favorite_outline),
                  label: Text('Curtidas'),
                ),
              ],
              selected: {_segment},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  _onSegmentChanged(selection.first),
            ),
          ),
        ),
      ),
      // Listener das ações do "Curtir de volta" (MatchDialog + erro).
      body: BlocListener<LikesCubit, LikesState>(
        listener: (context, state) async {
          if (state.actionError != null) {
            final message = state.actionError!;
            context.read<LikesCubit>().clearTransient();
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(message)));
          }
          if (state.pendingMatch != null) {
            final match = state.pendingMatch!;
            final matchesCubit = context.read<MatchesCubit>();
            context.read<LikesCubit>().clearTransient();
            // Dialog em tela ⇒ a notificação deste `match:new` é suprimida.
            getIt<AppNotificationsService>().matchDialogShown(match.id);
            await showDialog<void>(
              context: context,
              builder: (_) => MatchDialog(match: match),
            );
            // O novo match aparece no outro segmento sem depender do socket.
            unawaited(matchesCubit.load());
          }
        },
        // IndexedStack preserva o estado (scroll/listas) dos dois segmentos.
        child: IndexedStack(
          index: _segment.index,
          sizing: StackFit.expand,
          children: const [_MatchesList(), _LikesList()],
        ),
      ),
    );
  }
}

class _MatchesList extends StatelessWidget {
  const _MatchesList();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MatchesCubit, MatchesState>(
      builder: (context, state) {
        switch (state.status) {
          case MatchesStatus.initial:
          case MatchesStatus.loading:
            return const LoadingIndicator();
          case MatchesStatus.error:
            return EmptyState(
              icon: Icons.error_outline,
              title: 'Não foi possível carregar seus matches',
              message: state.errorMessage,
              actionLabel: 'Tentar novamente',
              onAction: () => context.read<MatchesCubit>().load(),
            );
          case MatchesStatus.loaded:
            if (state.matches.isEmpty) {
              return const EmptyState(
                icon: Icons.favorite_outline,
                title: 'Nenhum match ainda',
                message:
                    'Continue dando likes! Quando o like for mútuo, o '
                    'match aparece aqui.',
              );
            }
            return RefreshIndicator(
              onRefresh: () {
                // Convite não bloqueante: o refresh segue normalmente.
                unawaited(
                  getIt<LocationService>().offerLocationInvite(context),
                );
                return context.read<MatchesCubit>().load();
              },
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: state.matches.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, indent: 88),
                itemBuilder: (context, index) =>
                    _MatchTile(match: state.matches[index]),
              ),
            );
        }
      },
    );
  }
}

class _MatchTile extends StatelessWidget {
  const _MatchTile({required this.match});

  final MatchModel match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lastMessage = match.lastMessage;
    final timestamp = lastMessage?.createdAt ?? match.createdAt;
    final unread = match.unreadCount;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 28,
        backgroundColor: theme.colorScheme.primaryContainer,
        backgroundImage: match.otherDog.mainPhotoUrl == null
            ? null
            : CachedNetworkImageProvider(match.otherDog.mainPhotoUrl!),
        child: match.otherDog.mainPhotoUrl == null
            ? Icon(
                Icons.pets,
                color: theme.colorScheme.onPrimaryContainer,
              )
            : null,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              match.otherDog.name,
              style: theme.textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            relativeTimeLabel(timestamp),
            style: theme.textTheme.labelSmall?.copyWith(
              color: unread > 0
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              '${match.otherOwner.name} · '
              '${lastMessage?.content ?? 'Vocês deram match! Diga oi 🐶'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              // Última mensagem não lida em destaque (negrito).
              style: unread > 0
                  ? theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    )
                  : theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
            ),
          ),
          if (unread > 0) _UnreadBadge(count: unread),
        ],
      ),
      onTap: () async {
        final cubit = context.read<MatchesCubit>();
        // Zera o contador local na hora — o POST /matches/:id/read fica
        // com o ChatCubit ao abrir a conversa.
        cubit.markRead(match.id);
        // Convite não bloqueante: abrir o chat nunca espera a permissão.
        unawaited(getIt<LocationService>().offerLocationInvite(context));
        await context.push('/chat/${match.id}', extra: match);
        cubit.load();
      },
    );
  }
}

/// Badge circular com o total de mensagens não lidas do match.
class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      constraints: const BoxConstraints(minWidth: 22),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _LikesList extends StatelessWidget {
  const _LikesList();

  /// Abre o detalhe do cão que curtiu (entrada na cadeia detalhe↔dono ⇒
  /// `push`). O pop devolve o `myAction` final: um like dado lá dentro
  /// resolve a curtida — sai da lista e a lista de matches recarrega (o
  /// dialog de match já apareceu no detalhe).
  static Future<void> _openDetails(
    BuildContext context,
    LikeReceivedModel like,
  ) async {
    final likesCubit = context.read<LikesCubit>();
    final matchesCubit = context.read<MatchesCubit>();
    final action = await context.push<String>(
      '/search/dogs/${like.dog.id}',
      extra: SearchCardModel(
        dog: like.dog,
        distanceKm: like.distanceKm,
        owner: like.owner,
        myAction: like.myAction,
        matched: false,
      ),
    );
    if (action == SearchCardModel.likeAction) {
      likesCubit.removeByDogId(like.dog.id);
      unawaited(matchesCubit.load());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LikesCubit, LikesState>(
      builder: (context, state) {
        switch (state.status) {
          case LikesStatus.initial:
          case LikesStatus.loading:
            return const LoadingIndicator();
          case LikesStatus.error:
            return EmptyState(
              icon: Icons.error_outline,
              title: 'Não foi possível carregar as curtidas',
              message: state.errorMessage,
              actionLabel: 'Tentar novamente',
              onAction: () => context.read<LikesCubit>().load(),
            );
          case LikesStatus.loaded:
            if (state.likes.isEmpty) {
              return const EmptyState(
                icon: Icons.favorite_outline,
                title: 'Nenhuma curtida pendente 🐾',
                message:
                    'Quando alguém curtir este cão, a curtida aparece '
                    'aqui para você retribuir.',
              );
            }
            return RefreshIndicator(
              onRefresh: () => context.read<LikesCubit>().load(),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: state.likes.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final like = state.likes[index];
                  return LikeReceivedCard(
                    like: like,
                    likingBack:
                        state.likingBackDogIds.contains(like.dog.id),
                    onLikeBack: () =>
                        context.read<LikesCubit>().likeBack(like),
                    onTap: () => _openDetails(context, like),
                  );
                },
              ),
            );
        }
      },
    );
  }
}
