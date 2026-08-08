import 'package:cached_network_image/cached_network_image.dart';
import 'package:dogmatch/app/di/injection.dart';
import 'package:dogmatch/core/widgets/empty_state.dart';
import 'package:dogmatch/core/widgets/loading_indicator.dart';
import 'package:dogmatch/core/widgets/primary_button.dart';
import 'package:dogmatch/features/discovery/domain/entities/swipe_action.dart';
import 'package:dogmatch/features/discovery/presentation/widgets/match_dialog.dart';
import 'package:dogmatch/features/dogs/data/models/dog_photo_model.dart';
import 'package:dogmatch/features/search/data/models/search_card_model.dart';
import 'package:dogmatch/features/search/presentation/cubit/dog_detail_cubit.dart';
import 'package:dogmatch/features/search/presentation/widgets/search_result_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Detalhe de um cão da busca (`/search/dogs/:id`). Recebe o
/// [SearchCardModel] via extra; sem extra, busca `GET /dogs/:id`.
class DogDetailPage extends StatelessWidget {
  const DogDetailPage({super.key, required this.dogId, this.card});

  final String dogId;
  final SearchCardModel? card;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<DogDetailCubit>()..init(dogId: dogId, card: card),
      child: _DogDetailView(dogId: dogId, initialCard: card),
    );
  }
}

class _DogDetailView extends StatelessWidget {
  const _DogDetailView({required this.dogId, this.initialCard});

  final String dogId;
  final SearchCardModel? initialCard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocConsumer<DogDetailCubit, DogDetailState>(
      listener: (context, state) async {
        final cubit = context.read<DogDetailCubit>();
        if (state.actionError != null) {
          cubit.clearTransient();
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(state.actionError!)));
        }
        if (state.matchToOpen != null) {
          final match = state.matchToOpen!;
          cubit.clearTransient();
          context.push('/chat/${match.id}', extra: match);
        }
        if (state.pendingMatch != null) {
          final match = state.pendingMatch!;
          cubit.clearTransient();
          await showDialog<void>(
            context: context,
            builder: (_) => MatchDialog(match: match),
          );
        }
      },
      builder: (context, state) {
        switch (state.status) {
          case DogDetailStatus.initial:
          case DogDetailStatus.loading:
            return Scaffold(
              appBar: AppBar(),
              body: const LoadingIndicator(),
            );
          case DogDetailStatus.error:
            return Scaffold(
              appBar: AppBar(),
              body: EmptyState(
                icon: Icons.error_outline,
                title: 'Não foi possível carregar',
                message: state.message,
                actionLabel: 'Tentar novamente',
                onAction: () => context
                    .read<DogDetailCubit>()
                    .init(dogId: dogId, card: initialCard),
              ),
            );
          case DogDetailStatus.success:
            final card = state.card!;
            final dog = card.dog;
            return Scaffold(
              appBar: AppBar(title: Text(dog.name)),
              body: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PhotoCarousel(photos: dog.sortedPhotos),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  '${dog.name}, ${dog.ageLabel}',
                                  style: theme.textTheme.headlineMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (card.isMatched || card.isLiked) ...[
                                const SizedBox(width: 8),
                                SearchCardBadge(card: card),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dog.breed,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Chip(label: Text(dog.sex.labelPtBr)),
                              Chip(label: Text(dog.size.labelPtBr)),
                              Chip(label: Text(dog.intent.labelPtBr)),
                              if (dog.neutered)
                                const Chip(label: Text('Castrado')),
                              if (dog.pedigree)
                                const Chip(label: Text('Pedigree')),
                            ],
                          ),
                          if (dog.bio != null && dog.bio!.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Sobre',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(dog.bio!, style: theme.textTheme.bodyLarge),
                          ],
                          const SizedBox(height: 16),
                          Text(
                            'Dono',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          _OwnerCard(card: card),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              bottomNavigationBar: SafeArea(
                minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: _BottomActions(state: state, dogId: dogId),
              ),
            );
        }
      },
    );
  }
}

/// Ações do rodapé conforme o estado: abrir conversa (match), curtir/passar
/// (com cão ativo) ou CTA de cadastro (sem cão).
class _BottomActions extends StatelessWidget {
  const _BottomActions({required this.state, required this.dogId});

  final DogDetailState state;
  final String dogId;

  @override
  Widget build(BuildContext context) {
    final card = state.card!;
    if (card.isMatched) {
      return PrimaryButton(
        label: 'Abrir conversa 💬',
        icon: Icons.chat_bubble_outline,
        loading: state.actionInProgress,
        onPressed: () => context.read<DogDetailCubit>().openConversation(),
      );
    }
    if (state.activeDog == null) {
      return PrimaryButton(
        label: 'Cadastre um cão para interagir',
        icon: Icons.pets,
        onPressed: () async {
          final cubit = context.read<DogDetailCubit>();
          final currentCard = cubit.state.card;
          await context.push('/dogs/new');
          await cubit.init(dogId: dogId, card: currentCard);
        },
      );
    }
    final canAct = !card.hasMyAction && !state.actionInProgress;
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: canAct
                  ? () =>
                      context.read<DogDetailCubit>().swipe(SwipeAction.pass)
                  : null,
              icon: const Icon(Icons.close),
              label: const Text('Passar'),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: canAct
                  ? () =>
                      context.read<DogDetailCubit>().swipe(SwipeAction.like)
                  : null,
              icon: const Icon(Icons.favorite),
              label: const Text('Curtir'),
            ),
          ),
        ),
      ],
    );
  }
}

class _OwnerCard extends StatelessWidget {
  const _OwnerCard({required this.card});

  final SearchCardModel card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final owner = card.owner;
    final location = card.locationLabel;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          backgroundImage: owner.avatarUrl == null
              ? null
              : CachedNetworkImageProvider(owner.avatarUrl!),
          child: owner.avatarUrl == null
              ? Icon(
                  Icons.person,
                  color: theme.colorScheme.onPrimaryContainer,
                )
              : null,
        ),
        title: Text(owner.name),
        subtitle: location == null ? null : Text(location),
      ),
    );
  }
}

/// Carousel de fotos com indicador de dots; fallback = ícone de pata.
class _PhotoCarousel extends StatefulWidget {
  const _PhotoCarousel({required this.photos});

  final List<DogPhotoModel> photos;

  @override
  State<_PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<_PhotoCarousel> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.photos.isEmpty) {
      return SizedBox(
        height: 320,
        width: double.infinity,
        child: ColoredBox(
          color: theme.colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.pets,
            size: 96,
            color: theme.colorScheme.outline,
          ),
        ),
      );
    }
    return SizedBox(
      height: 320,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            itemCount: widget.photos.length,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (context, index) => CachedNetworkImage(
              imageUrl: widget.photos[index].url,
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
          ),
          if (widget.photos.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < widget.photos.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: i == _index ? 20 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: i == _index ? Colors.white : Colors.white54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
