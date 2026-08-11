import 'package:cached_network_image/cached_network_image.dart';
import 'package:dogmatch/core/utils/relative_time.dart';
import 'package:dogmatch/features/dogs/presentation/widgets/dog_tag_chips.dart';
import 'package:dogmatch/features/matches/data/models/like_received_model.dart';
import 'package:flutter/material.dart';

/// Card de uma curtida recebida: foto, nome, chips padrão (idade/intenção),
/// cidade/distância, "curtiu há X", badge "Você passou 👋" quando o cão
/// ativo passou este cão, e o botão primário "Curtir de volta".
class LikeReceivedCard extends StatelessWidget {
  const LikeReceivedCard({
    super.key,
    required this.like,
    required this.likingBack,
    required this.onLikeBack,
    required this.onTap,
  });

  final LikeReceivedModel like;

  /// "Curtir de volta" em andamento — desabilita o botão e mostra spinner.
  final bool likingBack;

  final VoidCallback onLikeBack;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dog = like.dog;
    final location = like.locationLabel;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 96,
                      height: 96,
                      child: _DogPhoto(url: dog.mainPhotoUrl),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                dog.name,
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (like.wasPassed) ...[
                              const SizedBox(width: 8),
                              const _PassedBadge(),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.favorite,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                likedAgoLabel(like.likedAt),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (location != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  location,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
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
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: likingBack ? null : onLikeBack,
                icon: likingBack
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.favorite),
                label: const Text('Curtir de volta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Você passou 👋" em cor neutra: o pass é reversível — curtir de volta
/// (ou pelo detalhe) desfaz.
class _PassedBadge extends StatelessWidget {
  const _PassedBadge();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Você passou 👋',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _DogPhoto extends StatelessWidget {
  const _DogPhoto({required this.url});

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
      placeholder: (_, _) =>
          ColoredBox(color: theme.colorScheme.surfaceContainerHighest),
      errorWidget: (_, _, _) => fallback,
    );
  }
}
