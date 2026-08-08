import 'package:cached_network_image/cached_network_image.dart';
import 'package:dogmatch/app/di/injection.dart';
import 'package:dogmatch/core/network/file_uploader.dart';
import 'package:dogmatch/core/utils/telegram_text.dart';
import 'package:dogmatch/core/widgets/empty_state.dart';
import 'package:dogmatch/core/widgets/loading_indicator.dart';
import 'package:dogmatch/core/widgets/primary_button.dart';
import 'package:dogmatch/features/dogs/data/models/dog_post_model.dart';
import 'package:dogmatch/features/dogs/domain/entities/dog_post_rules.dart';
import 'package:dogmatch/features/dogs/domain/entities/dog_post_type.dart';
import 'package:dogmatch/features/dogs/presentation/cubit/dog_post_composer_cubit.dart';
import 'package:dogmatch/features/dogs/presentation/widgets/dog_post_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

/// Composer de post da página do cão: criação (`/dogs/:id/posts/new`) e
/// edição (`/dogs/:id/posts/:postId/edit`, post via extra — sem extra, busca
/// na lista). Tipo imutável na edição; upload presigned na seleção; legendas
/// posicionadas tocando na imagem (CAROUSEL).
class DogPostComposerPage extends StatelessWidget {
  const DogPostComposerPage({
    super.key,
    required this.dogId,
    this.postId,
    this.initialPost,
  });

  final String dogId;
  final String? postId;
  final DogPostModel? initialPost;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<DogPostComposerCubit>()
        ..init(dogId: dogId, postId: postId, initialPost: initialPost),
      child: _ComposerView(
        dogId: dogId,
        postId: postId,
        initialPost: initialPost,
      ),
    );
  }
}

class _ComposerView extends StatefulWidget {
  const _ComposerView({
    required this.dogId,
    this.postId,
    this.initialPost,
  });

  final String dogId;
  final String? postId;
  final DogPostModel? initialPost;

  @override
  State<_ComposerView> createState() => _ComposerViewState();
}

class _ComposerViewState extends State<_ComposerView> {
  final _textController = TextEditingController();
  final _imagePicker = ImagePicker();
  bool _prefilled = false;

  @override
  void initState() {
    super.initState();
    // Edição com o post via extra: o cubit emite o estado preenchido de forma
    // síncrona (antes do listener assinar) — preenche o controller já aqui.
    // O caminho sem extra (fetch) é coberto pelo listener abaixo.
    final initialPost = widget.initialPost;
    if (initialPost != null) {
      _prefilled = true;
      _textController.text = initialPost.text ?? '';
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickImage() async {
    final cubit = context.read<DogPostComposerCubit>();
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    await cubit.addImage(
      bytes: bytes,
      contentType: picked.mimeType ??
          FileUploader.guessImageContentType(picked.name),
    );
  }

  /// Dialog de texto da legenda (criação e edição). Devolve `null` no
  /// cancelamento e string vazia quando o dono pediu para remover.
  Future<String?> _captionDialog({String? initialText}) {
    final controller = TextEditingController(text: initialText ?? '');
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(initialText == null ? 'Nova legenda' : 'Editar legenda'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: maxCaptionLength,
          maxLines: 3,
          minLines: 1,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Legenda',
            hintText: 'O que aparece neste ponto da foto?',
          ),
        ),
        actions: [
          if (initialText != null)
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(''),
              child: const Text('Remover'),
            ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          ValueListenableBuilder(
            valueListenable: controller,
            builder: (_, value, _) => FilledButton(
              onPressed: value.text.trim().isEmpty
                  ? null
                  : () =>
                      Navigator.of(dialogContext).pop(value.text.trim()),
              child: const Text('Salvar'),
            ),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  Future<void> _addCaptionAt(int imageIndex, Offset normalized) async {
    final cubit = context.read<DogPostComposerCubit>();
    final image = cubit.state.images.elementAtOrNull(imageIndex);
    if (image == null) return;
    if (image.captions.length >= maxCaptionsPerImage) {
      _showSnackBar('Máximo de $maxCaptionsPerImage legendas por imagem');
      return;
    }
    final text = await _captionDialog();
    if (text == null || text.isEmpty) return;
    cubit.addCaption(
      imageIndex,
      text: text,
      x: normalized.dx,
      y: normalized.dy,
    );
  }

  Future<void> _editCaption(int imageIndex, int captionIndex) async {
    final cubit = context.read<DogPostComposerCubit>();
    final caption = cubit.state.images
        .elementAtOrNull(imageIndex)
        ?.captions
        .elementAtOrNull(captionIndex);
    if (caption == null) return;
    final text = await _captionDialog(initialText: caption.text);
    if (text == null) return;
    if (text.isEmpty) {
      cubit.removeCaption(imageIndex, captionIndex);
    } else {
      cubit.updateCaption(imageIndex, captionIndex, text);
    }
  }

  void _showFormattingHelp() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => const _FormattingHelpDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = widget.postId == null ? 'Novo post' : 'Editar post';
    return BlocConsumer<DogPostComposerCubit, DogPostComposerState>(
      listener: (context, state) {
        if (state.errorMessage != null) _showSnackBar(state.errorMessage!);
        if (state.savedPost != null) {
          _showSnackBar(
            widget.postId == null ? 'Post publicado!' : 'Alterações salvas!',
          );
          context.pop();
          return;
        }
        if (state.status == DogPostComposerStatus.ready &&
            state.isEditing &&
            !_prefilled) {
          _prefilled = true;
          _textController.text = state.text;
        }
      },
      builder: (context, state) {
        switch (state.status) {
          case DogPostComposerStatus.loading:
            return Scaffold(
              appBar: AppBar(title: Text(title)),
              body: const LoadingIndicator(),
            );
          case DogPostComposerStatus.error:
            return Scaffold(
              appBar: AppBar(title: Text(title)),
              body: EmptyState(
                icon: Icons.error_outline,
                title: 'Não foi possível carregar o post',
                message: state.message,
                actionLabel: 'Tentar novamente',
                onAction: () => context.read<DogPostComposerCubit>().init(
                      dogId: widget.dogId,
                      postId: widget.postId,
                      initialPost: widget.initialPost,
                    ),
              ),
            );
          case DogPostComposerStatus.ready:
            return Scaffold(
              appBar: AppBar(title: Text(title)),
              body: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text('Tipo do post', style: theme.textTheme.titleSmall),
                    if (state.isEditing) ...[
                      const SizedBox(height: 4),
                      Text(
                        'O tipo não pode ser alterado depois de publicado.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final type in DogPostType.values)
                          ChoiceChip(
                            avatar: Icon(dogPostTypeIcon(type), size: 18),
                            label: Text(type.labelPtBr),
                            selected: state.type == type,
                            onSelected: state.isEditing
                                ? null
                                : (_) => context
                                    .read<DogPostComposerCubit>()
                                    .selectType(type),
                          ),
                      ],
                    ),
                    if (state.type.allowsText) ...[
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Text(
                            state.type.requiresText
                                ? 'Texto'
                                : 'Texto (opcional)',
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            tooltip: 'Ajuda de formatação',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.help_outline, size: 20),
                            onPressed: _showFormattingHelp,
                          ),
                        ],
                      ),
                      TextFormField(
                        controller: _textController,
                        maxLength: maxPostTextLength,
                        maxLines: 8,
                        minLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: context
                            .read<DogPostComposerCubit>()
                            .textChanged,
                        decoration: const InputDecoration(
                          hintText: 'Conte a história deste post... use '
                              '**negrito**, __itálico__, ~~riscado~~ e '
                              '`mono`.',
                        ),
                      ),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: Text(
                          'Pré-visualização',
                          style: theme.textTheme.titleSmall,
                        ),
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: state.text.trim().isEmpty
                                ? Text(
                                    'Digite algo para pré-visualizar.',
                                    style:
                                        theme.textTheme.bodyMedium?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant,
                                    ),
                                  )
                                : TelegramText(
                                    state.text,
                                    style: theme.textTheme.bodyLarge,
                                  ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ],
                    if (state.type == DogPostType.image ||
                        state.type == DogPostType.imageText) ...[
                      const SizedBox(height: 24),
                      Text('Imagem', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      _SingleImageEditor(
                        image: state.images.firstOrNull,
                        onPick: _pickImage,
                        onRemove: () => context
                            .read<DogPostComposerCubit>()
                            .removeImage(0),
                      ),
                    ],
                    if (state.type == DogPostType.carousel) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Imagens (${state.images.length}/$maxCarouselImages)',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'De $minCarouselImages a $maxCarouselImages imagens. '
                        'Toque na imagem para adicionar uma legenda no ponto '
                        'tocado.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (var i = 0; i < state.images.length; i++) ...[
                        _CarouselImageEditor(
                          image: state.images[i],
                          onRemove: () => context
                              .read<DogPostComposerCubit>()
                              .removeImage(i),
                          onTapAt: (normalized) => _addCaptionAt(i, normalized),
                          onCaptionTap: (captionIndex) =>
                              _editCaption(i, captionIndex),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (state.images.length < maxCarouselImages)
                        OutlinedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: const Text('Adicionar imagem'),
                        ),
                    ],
                    const SizedBox(height: 32),
                    PrimaryButton(
                      label: state.isEditing
                          ? 'Salvar alterações'
                          : 'Publicar post',
                      loading: state.saving,
                      onPressed: state.uploading
                          ? null
                          : () =>
                              context.read<DogPostComposerCubit>().save(),
                    ),
                    if (state.uploading)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Enviando imagens...',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
        }
      },
    );
  }
}

/// Preview de uma [ComposerImage]: bytes locais (recém-escolhida) ou URL
/// remota (post em edição), com fallback neutro.
Widget _composerImagePreview(BuildContext context, ComposerImage image) {
  final theme = Theme.of(context);
  final bytes = image.bytes;
  if (bytes != null) return Image.memory(bytes, fit: BoxFit.cover);
  final url = image.url;
  if (url != null) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, _) =>
          ColoredBox(color: theme.colorScheme.surfaceContainerHighest),
      errorWidget: (_, _, _) => ColoredBox(
        color: theme.colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.broken_image_outlined),
      ),
    );
  }
  return ColoredBox(color: theme.colorScheme.surfaceContainerHighest);
}

/// Overlay de progresso do upload presigned da imagem.
class _UploadingOverlay extends StatelessWidget {
  const _UploadingOverlay();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      // Escurece a própria foto durante o upload (overlay sobre imagem).
      color: Colors.black38,
      child: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Botão circular de remover no canto da imagem (padrão do _PhotoGrid).
class _RemoveImageButton extends StatelessWidget {
  const _RemoveImageButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned(
      top: 8,
      right: 8,
      child: InkWell(
        onTap: onTap,
        child: CircleAvatar(
          radius: 16,
          backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.85),
          child: Icon(Icons.close, size: 18, color: theme.colorScheme.error),
        ),
      ),
    );
  }
}

/// Editor da imagem única (IMAGE / IMAGE_TEXT): adicionar, trocar, remover.
class _SingleImageEditor extends StatelessWidget {
  const _SingleImageEditor({
    required this.image,
    required this.onPick,
    required this.onRemove,
  });

  final ComposerImage? image;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = image;
    if (current == null) {
      return InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_photo_alternate_outlined,
                size: 40,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 8),
              const Text('Adicionar imagem'),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _composerImagePreview(context, current),
                if (current.uploading) const _UploadingOverlay(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: current.uploading ? null : onPick,
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Trocar'),
            ),
            TextButton.icon(
              onPressed: current.uploading ? null : onRemove,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remover'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Preview de uma imagem do carrossel no composer: toque adiciona legenda no
/// ponto (coords normalizadas), marcadores tocáveis para editar/remover.
class _CarouselImageEditor extends StatelessWidget {
  const _CarouselImageEditor({
    required this.image,
    required this.onRemove,
    required this.onTapAt,
    required this.onCaptionTap,
  });

  final ComposerImage image;
  final VoidCallback onRemove;

  /// Toque na imagem com o ponto normalizado (x/y ∈ [0,1]).
  final ValueChanged<Offset> onTapAt;
  final ValueChanged<int> onCaptionTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: image.uploading
                      ? null
                      : (details) => onTapAt(
                            Offset(
                              (details.localPosition.dx / width)
                                  .clamp(0.0, 1.0),
                              (details.localPosition.dy / height)
                                  .clamp(0.0, 1.0),
                            ),
                          ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _composerImagePreview(context, image),
                      for (var i = 0; i < image.captions.length; i++)
                        positionCaptionMarker(
                          x: image.captions[i].x,
                          y: image.captions[i].y,
                          width: width,
                          height: height,
                          child: GestureDetector(
                            onTap: () => onCaptionTap(i),
                            child: const DogPostCaptionMarker(),
                          ),
                        ),
                      if (image.uploading) const _UploadingOverlay(),
                      _RemoveImageButton(onTap: onRemove),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          image.captions.isEmpty
              ? 'Toque na imagem para adicionar uma legenda'
              : 'Legendas: ${image.captions.length}/$maxCaptionsPerImage · '
                  'toque num marcador para editar',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Dialog "Formatação": tabela token → resultado + exemplo renderizado.
class _FormattingHelpDialog extends StatelessWidget {
  const _FormattingHelpDialog();

  static const String _example =
      'A **Luna** adora __correr__ no parque, ~~dormir~~ brincar o dia '
      'todo e atende por `Lulu`.';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final codeStyle = theme.textTheme.bodyMedium?.copyWith(
      fontFamily: 'monospace',
      color: theme.colorScheme.onSurfaceVariant,
    );
    Widget row(String token, String rendered) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(child: Text(token, style: codeStyle)),
              Icon(
                Icons.arrow_right_alt,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TelegramText(
                  rendered,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        );
    return AlertDialog(
      title: const Text('Formatação'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            row('**texto**', '**negrito**'),
            row('__texto__', '__itálico__'),
            row('~~texto~~', '~~riscado~~'),
            row('`texto`', '`monoespaçado`'),
            const SizedBox(height: 16),
            Text('Exemplo', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(_example, style: codeStyle),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TelegramText(
                _example,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Entendi'),
        ),
      ],
    );
  }
}
