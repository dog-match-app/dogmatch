import 'package:dogmatch/app/di/injection.dart';
import 'package:dogmatch/core/widgets/empty_state.dart';
import 'package:dogmatch/core/widgets/loading_indicator.dart';
import 'package:dogmatch/features/dogs/data/models/dog_model.dart';
import 'package:dogmatch/features/dogs/data/models/dog_post_model.dart';
import 'package:dogmatch/features/dogs/domain/entities/dog_post_rules.dart';
import 'package:dogmatch/features/dogs/presentation/cubit/dog_posts_cubit.dart';
import 'package:dogmatch/features/dogs/presentation/widgets/dog_post_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Gerência da página do cão pelo dono (`/dogs/:id/posts`): lista os posts
/// como na visualização, com menu editar/excluir e FAB "Novo post"
/// (bloqueado com aviso ao atingir o limite de 10).
class DogPostsManagerPage extends StatelessWidget {
  const DogPostsManagerPage({super.key, required this.dogId, this.dog});

  final String dogId;

  /// Cão vindo via extra (título e mensagens); sem ele, textos genéricos.
  final DogModel? dog;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<DogPostsCubit>()..load(dogId),
      child: _ManagerView(dogId: dogId, dog: dog),
    );
  }
}

class _ManagerView extends StatelessWidget {
  const _ManagerView({required this.dogId, this.dog});

  final String dogId;
  final DogModel? dog;

  Future<void> _openComposer(BuildContext context, {DogPostModel? post}) async {
    final cubit = context.read<DogPostsCubit>();
    if (post == null) {
      await context.push('/dogs/$dogId/posts/new');
    } else {
      await context.push('/dogs/$dogId/posts/${post.id}/edit', extra: post);
    }
    // Recarrega ao voltar do composer (post criado/alterado).
    cubit.load(dogId);
  }

  Future<void> _confirmDelete(BuildContext context, DogPostModel post) async {
    final cubit = context.read<DogPostsCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir post'),
        content: Text(
          dog == null
              ? 'Este post será removido da página do cão.'
              : 'Este post será removido da página de ${dog!.name}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed == true) cubit.delete(post.id);
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocConsumer<DogPostsCubit, DogPostsState>(
      listener: (context, state) {
        if (state.actionError != null) {
          _showSnackBar(context, state.actionError!);
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              dog == null ? 'Página do cão' : 'Página de ${dog!.name}',
            ),
          ),
          floatingActionButton: state.status == DogPostsStatus.success
              ? FloatingActionButton.extended(
                  tooltip:
                      state.canAddMore ? 'Criar novo post' : postLimitMessage,
                  backgroundColor: state.canAddMore
                      ? null
                      : theme.colorScheme.surfaceContainerHighest,
                  foregroundColor: state.canAddMore
                      ? null
                      : theme.colorScheme.onSurfaceVariant,
                  onPressed: () {
                    if (!state.canAddMore) {
                      _showSnackBar(context, postLimitMessage);
                      return;
                    }
                    _openComposer(context);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Novo post'),
                )
              : null,
          body: switch (state.status) {
            DogPostsStatus.initial ||
            DogPostsStatus.loading =>
              const LoadingIndicator(),
            DogPostsStatus.error => EmptyState(
                icon: Icons.error_outline,
                title: 'Não foi possível carregar os posts',
                message: state.message,
                actionLabel: 'Tentar novamente',
                onAction: () => context.read<DogPostsCubit>().load(dogId),
              ),
            DogPostsStatus.success => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Text(
                      'Posts (${state.count}/$maxPostsPerDog)',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: state.posts.isEmpty
                        ? EmptyState(
                            icon: Icons.auto_stories_outlined,
                            title: 'Nenhum post ainda 🐾',
                            message: 'Monte a página com textos, fotos e '
                                'carrosséis com legendas.',
                            actionLabel: 'Criar primeiro post',
                            onAction: () => _openComposer(context),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                            itemCount: state.posts.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 16),
                            itemBuilder: (context, index) => _ManagerItem(
                              post: state.posts[index],
                              onEdit: (post) =>
                                  _openComposer(context, post: post),
                              onDelete: (post) =>
                                  _confirmDelete(context, post),
                            ),
                          ),
                  ),
                ],
              ),
          },
        );
      },
    );
  }
}

/// Post renderizado como na visualização + linha de contexto (tipo, data)
/// com o menu editar/excluir.
class _ManagerItem extends StatelessWidget {
  const _ManagerItem({
    required this.post,
    required this.onEdit,
    required this.onDelete,
  });

  final DogPostModel post;
  final ValueChanged<DogPostModel> onEdit;
  final ValueChanged<DogPostModel> onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = DateFormat('dd/MM/yyyy').format(post.createdAt.toLocal());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              dogPostTypeIcon(post.type),
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${post.type.labelPtBr} · $date',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Opções do post',
              onSelected: (action) =>
                  action == 'edit' ? onEdit(post) : onDelete(post),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 20),
                      SizedBox(width: 12),
                      Text('Editar'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 20),
                      SizedBox(width: 12),
                      Text('Excluir'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        DogPostCard(post: post),
      ],
    );
  }
}
