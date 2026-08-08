import 'package:cached_network_image/cached_network_image.dart';
import 'package:dogmatch/features/discovery/data/models/discovery_card_model.dart';
import 'package:flutter/material.dart';

/// Card do deck de swipe: foto (troca por toque nas laterais), gradiente
/// inferior, "Nome, idade", raça, distância e chips de intenção.
class DiscoveryDogCard extends StatefulWidget {
  const DiscoveryDogCard({super.key, required this.card});

  final DiscoveryCardModel card;

  @override
  State<DiscoveryDogCard> createState() => _DiscoveryDogCardState();
}

class _DiscoveryDogCardState extends State<DiscoveryDogCard> {
  int _photoIndex = 0;

  void _onTapUp(TapUpDetails details, double width) {
    final photoCount = widget.card.dog.sortedPhotos.length;
    if (photoCount <= 1) return;
    setState(() {
      if (details.localPosition.dx > width / 2) {
        _photoIndex = (_photoIndex + 1) % photoCount;
      } else {
        _photoIndex = (_photoIndex - 1 + photoCount) % photoCount;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dog = widget.card.dog;
    final photos = dog.sortedPhotos;
    final photoUrl = photos.isEmpty ? null : photos[_photoIndex % photos.length].url;

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapUp: (details) => _onTapUp(details, constraints.maxWidth),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (photoUrl == null)
                  ColoredBox(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.pets,
                      size: 96,
                      color: theme.colorScheme.outline,
                    ),
                  )
                else
                  CachedNetworkImage(
                    imageUrl: photoUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => ColoredBox(
                      color: theme.colorScheme.surfaceContainerHighest,
                    ),
                    errorWidget: (_, _, _) => ColoredBox(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.pets,
                        size: 96,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                // Gradiente inferior para legibilidade do texto.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.center,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                ),
                if (photos.length > 1)
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Row(
                      children: [
                        for (var i = 0; i < photos.length; i++)
                          Expanded(
                            child: Container(
                              height: 3,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color: i == _photoIndex
                                    ? Colors.white
                                    : Colors.white38,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${dog.name}, ${dog.ageLabel}',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dog.breed,
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.card.distanceLabel,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _InfoChip(label: dog.intent.labelPtBr),
                          _InfoChip(label: dog.size.labelPtBr),
                          if (dog.pedigree)
                            const _InfoChip(label: 'Pedigree'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: Colors.white),
      ),
    );
  }
}
