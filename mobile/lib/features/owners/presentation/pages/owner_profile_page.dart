import 'package:cached_network_image/cached_network_image.dart';
import 'package:dogmatch/app/di/injection.dart';
import 'package:dogmatch/core/widgets/empty_state.dart';
import 'package:dogmatch/core/widgets/loading_indicator.dart';
import 'package:dogmatch/features/dogs/data/models/dog_model.dart';
import 'package:dogmatch/features/dogs/presentation/widgets/dog_tag_chips.dart';
import 'package:dogmatch/features/owners/data/models/owner_profile_model.dart';
import 'package:dogmatch/features/owners/presentation/cubit/owner_profile_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Perfil público do dono (`/owners/:id`): header com avatar/cidade/
/// distância, "Membro desde", bio, estatísticas e a lista de cães dele.
class OwnerProfilePage extends StatelessWidget {
  const OwnerProfilePage({super.key, required this.ownerId});

  final String ownerId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<OwnerProfileCubit>()..load(ownerId),
      child: _OwnerProfileView(ownerId: ownerId),
    );
  }
}

class _OwnerProfileView extends StatelessWidget {
  const _OwnerProfileView({required this.ownerId});

  final String ownerId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OwnerProfileCubit, OwnerProfileState>(
      builder: (context, state) {
        switch (state.status) {
          case OwnerProfileStatus.initial:
          case OwnerProfileStatus.loading:
            return Scaffold(
              appBar: AppBar(),
              body: const LoadingIndicator(),
            );
          case OwnerProfileStatus.error:
            return Scaffold(
              appBar: AppBar(),
              body: EmptyState(
                icon: Icons.error_outline,
                title: 'Não foi possível carregar',
                message: state.message,
                actionLabel: 'Tentar novamente',
                onAction: () =>
                    context.read<OwnerProfileCubit>().load(ownerId),
              ),
            );
          case OwnerProfileStatus.success:
            final profile = state.profile!;
            return Scaffold(
              appBar: AppBar(title: Text(profile.name)),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _OwnerHeader(profile: profile),
                    const SizedBox(height: 16),
                    _StatsRow(stats: profile.stats),
                    const SizedBox(height: 24),
                    _OwnerDogsSection(profile: profile),
                  ],
                ),
              ),
            );
        }
      },
    );
  }
}

class _OwnerHeader extends StatelessWidget {
  const _OwnerHeader({required this.profile});

  final OwnerProfileModel profile;

  /// `"Cidade · a 4,6 km"`, só a cidade, só `"a 4,6 km"`, ou `null`.
  String? get _locationLabel {
    final city = profile.city;
    final distance = profile.distanceLabel;
    if (city != null && distance != null) return '$city · a $distance';
    if (city != null) return city;
    if (distance != null) return 'a $distance';
    return null;
  }

  /// `"ago/2026"` — mês abreviado pt_BR (sem o ponto do intl) + ano.
  String get _memberSinceLabel {
    final formatted =
        DateFormat('MMM/yyyy', 'pt_BR').format(profile.memberSince);
    return formatted.replaceAll('.', '');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = _locationLabel;
    return Column(
      children: [
        CircleAvatar(
          radius: 48,
          backgroundColor: theme.colorScheme.primaryContainer,
          backgroundImage: profile.avatarUrl == null
              ? null
              : CachedNetworkImageProvider(profile.avatarUrl!),
          child: profile.avatarUrl == null
              ? Icon(
                  Icons.person,
                  size: 48,
                  color: theme.colorScheme.onPrimaryContainer,
                )
              : null,
        ),
        const SizedBox(height: 12),
        Text(
          profile.name,
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        if (location != null) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  location,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 4),
        Text(
          'Membro desde $_memberSinceLabel',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (profile.bio != null && profile.bio!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            profile.bio!,
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

/// Linha de estatísticas: "🐶 X cães" e "🐾 Y matches".
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final OwnerStatsModel stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            emoji: '🐶',
            value: stats.dogs,
            label: stats.dogs == 1 ? 'cão' : 'cães',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            emoji: '🐾',
            value: stats.matches,
            label: stats.matches == 1 ? 'match' : 'matches',
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.emoji,
    required this.value,
    required this.label,
  });

  final String emoji;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 4),
            Text(
              '$value $label',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnerDogsSection extends StatelessWidget {
  const _OwnerDogsSection({required this.profile});

  final OwnerProfileModel profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Cães de ${profile.firstName}',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (profile.dogs.isEmpty)
          EmptyState(
            icon: Icons.pets,
            title: 'Nenhum cão por aqui',
            message:
                '${profile.firstName} ainda não tem cães ativos no DogMatch.',
          )
        else
          for (final dog in profile.dogs) ...[
            _OwnerDogCard(dog: dog),
            if (dog != profile.dogs.last) const SizedBox(height: 12),
          ],
      ],
    );
  }
}

/// Card de um cão do dono: foto, nome, raça e chips de idade/intenção.
/// Tap abre `/search/dogs/:id` sem extra (o detalhe faz o fetch).
class _OwnerDogCard extends StatelessWidget {
  const _OwnerDogCard({required this.dog});

  final DogModel dog;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/search/dogs/${dog.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 96,
                  height: 96,
                  child: _OwnerDogPhoto(url: dog.mainPhotoUrl),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dog.name,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dog.breed,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        DogAgeChip(dog: dog),
                        ...dogIntentChips(dog.intent),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OwnerDogPhoto extends StatelessWidget {
  const _OwnerDogPhoto({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fallback = ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(Icons.pets, size: 40, color: theme.colorScheme.outline),
    );
    if (url == null) return fallback;
    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      placeholder: (_, _) => ColoredBox(
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      errorWidget: (_, _, _) => fallback,
    );
  }
}
