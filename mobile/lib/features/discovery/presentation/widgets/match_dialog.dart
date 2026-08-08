import 'package:cached_network_image/cached_network_image.dart';
import 'package:dogmatch/features/dogs/data/models/dog_model.dart';
import 'package:dogmatch/features/matches/data/models/match_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Dialog exibido quando um swipe resulta em match.
class MatchDialog extends StatelessWidget {
  const MatchDialog({super.key, required this.match});

  final MatchModel match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Deu match! 🐾', textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _DogAvatar(dog: match.myDog),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(
                  Icons.favorite,
                  color: theme.colorScheme.primary,
                  size: 32,
                ),
              ),
              _DogAvatar(dog: match.otherDog),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${match.myDog.name} e ${match.otherDog.name} se curtiram!',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Continuar'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            context.push('/chat/${match.id}', extra: match);
          },
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Text('Enviar mensagem'),
        ),
      ],
    );
  }
}

class _DogAvatar extends StatelessWidget {
  const _DogAvatar({required this.dog});

  final DogModel dog;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: theme.colorScheme.primaryContainer,
          backgroundImage: dog.mainPhotoUrl == null
              ? null
              : CachedNetworkImageProvider(dog.mainPhotoUrl!),
          child: dog.mainPhotoUrl == null
              ? Icon(
                  Icons.pets,
                  color: theme.colorScheme.onPrimaryContainer,
                )
              : null,
        ),
        const SizedBox(height: 8),
        Text(dog.name, style: theme.textTheme.labelLarge),
      ],
    );
  }
}
