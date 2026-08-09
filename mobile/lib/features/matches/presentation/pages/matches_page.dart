import 'package:cached_network_image/cached_network_image.dart';
import 'package:dogmatch/app/di/injection.dart';
import 'package:dogmatch/core/widgets/empty_state.dart';
import 'package:dogmatch/core/widgets/loading_indicator.dart';
import 'package:dogmatch/features/dogs/presentation/widgets/active_dog_selector.dart';
import 'package:dogmatch/features/matches/data/models/match_model.dart';
import 'package:dogmatch/features/matches/presentation/cubit/matches_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class MatchesPage extends StatelessWidget {
  const MatchesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<MatchesCubit>()..load(),
      child: const _MatchesView(),
    );
  }
}

class _MatchesView extends StatelessWidget {
  const _MatchesView();

  /// Horário relativo curto em PT-BR: "agora", "5 min", "3 h", "2 d", data.
  static String _relativeTime(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime.toLocal());
    if (difference.inMinutes < 1) return 'agora';
    if (difference.inMinutes < 60) return '${difference.inMinutes} min';
    if (difference.inHours < 24) return '${difference.inHours} h';
    if (difference.inDays < 7) return '${difference.inDays} d';
    return DateFormat('dd/MM/yyyy').format(dateTime.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Matches'),
        actions: const [ActiveDogSelector.compact()],
      ),
      body: BlocBuilder<MatchesCubit, MatchesState>(
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
                onRefresh: () => context.read<MatchesCubit>().load(),
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
      ),
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
            _MatchesView._relativeTime(timestamp),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      subtitle: Text(
        '${match.otherOwner.name} · '
        '${lastMessage?.content ?? 'Vocês deram match! Diga oi 🐶'}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      onTap: () async {
        final cubit = context.read<MatchesCubit>();
        await context.push('/chat/${match.id}', extra: match);
        cubit.load();
      },
    );
  }
}
