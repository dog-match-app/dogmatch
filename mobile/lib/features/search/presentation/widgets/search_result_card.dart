import 'package:cached_network_image/cached_network_image.dart';
import 'package:dogmatch/features/search/data/models/search_card_model.dart';
import 'package:flutter/material.dart';

/// Badge de interação do card: "Match 🐾" ou "Curtido ❤".
class SearchCardBadge extends StatelessWidget {
  const SearchCardBadge({super.key, required this.card});

  final SearchCardModel card;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final String label;
    final Color background;
    final Color foreground;
    if (card.isMatched) {
      label = 'Match 🐾';
      background = scheme.primaryContainer;
      foreground = scheme.onPrimaryContainer;
    } else if (card.isLiked) {
      label = 'Curtido ❤';
      background = scheme.tertiaryContainer;
      foreground = scheme.onTertiaryContainer;
    } else {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: foreground, fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// Card horizontal de um resultado da busca: foto 96px, nome + idade, raça,
/// cidade/distância, chip de intenção e badge de interação.
class SearchResultCard extends StatelessWidget {
  const SearchResultCard({super.key, required this.card, required this.onTap});

  final SearchCardModel card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dog = card.dog;
    final location = card.locationLabel;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
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
                            '${dog.name}, ${dog.ageLabel}',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (card.isMatched || card.isLiked) ...[
                          const SizedBox(width: 8),
                          SearchCardBadge(card: card),
                        ],
                      ],
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        dog.intent.labelPtBr,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
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
      placeholder: (_, _) => ColoredBox(
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      errorWidget: (_, _, _) => fallback,
    );
  }
}
