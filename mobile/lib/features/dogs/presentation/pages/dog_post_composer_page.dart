import 'package:cached_network_image/cached_network_image.dart';
import 'package:dogmatch/app/di/injection.dart';
import 'package:dogmatch/core/network/file_uploader.dart';
import 'package:dogmatch/core/utils/telegram_text.dart';
import 'package:dogmatch/core/widgets/contained_image.dart';
import 'package:dogmatch/core/widgets/empty_state.dart';
import 'package:dogmatch/core/widgets/loading_indicator.dart';
import 'package:dogmatch/core/widgets/primary_button.dart';
import 'package:dogmatch/features/dogs/data/models/dog_post_model.dart';
import 'package:dogmatch/features/dogs/domain/entities/dog_post_draft.dart';
import 'package:dogmatch/features/dogs/domain/entities/dog_post_rules.dart';
import 'package:dogmatch/features/dogs/domain/entities/dog_post_type.dart';
import 'package:dogmatch/features/dogs/presentation/cubit/dog_post_composer_cubit.dart';
import 'package:dogmatch/features/dogs/presentation/pages/caption_editor_page.dart';
import 'package:dogmatch/features/dogs/presentation/widgets/dog_post_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

/// Composer de post da página do cão: criação (`/dogs/:id/posts/new`) e
/// edição (`/dogs/:id/posts/:postId/edit`, post via extra — sem extra, busca
/// na lista). Tipo imutável na edição; upload presigned na seleção; legendas
/// posicionadas pelo [CaptionEditorPage] em qualquer tipo com imagem.
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

  /// Abre o editor de legendas em tela cheia e grava o resultado no cubit
  /// (fonte da verdade do draft).
  Future<void> _openCaptionEditor(int imageIndex) async {
    final cubit = context.read<DogPostComposerCubit>();
    final image = cubit.state.images.elementAtOrNull(imageIndex);
    if (image == null) return;
    if (image.uploading) {
      _showSnackBar('Aguarde o envio da imagem.');
      return;
    }
    final images = cubit.state.images;
    final result = await context.push<List<DogPostDraftCaption>>(
      '/caption-editor',
      extra: CaptionEditorArgs(
        captions: image.captions,
        bytes: image.bytes,
        url: image.url,
        imageLabel: images.length > 1
            ? 'Imagem ${imageIndex + 1} de ${images.length}'
            : null,
      ),
    );
    if (result != null) cubit.setCaptions(imageIndex, result);
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
                      const SizedBox(height: 4),
                      Text(
                        'A foto aparece inteira no post e aceita até '
                        '$maxCaptionsPerImage legendas marcadas em pontos '
                        'dela.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (state.images.firstOrNull case final image?)
                        _ComposerImageEditor(
                          image: image,
                          onCaptions: () => _openCaptionEditor(0),
                          onPick: _pickImage,
                          onRemove: () => context
                              .read<DogPostComposerCubit>()
                              .removeImage(0),
                        )
                      else
                        _AddImagePlaceholder(onTap: _pickImage),
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
                        'Cada foto aparece inteira e aceita até '
                        '$maxCaptionsPerImage legendas marcadas em pontos '
                        'dela.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (var i = 0; i < state.images.length; i++) ...[
                        _ComposerImageEditor(
                          image: state.images[i],
                          label: 'Imagem ${i + 1} de ${state.images.length}',
                          onCaptions: () => _openCaptionEditor(i),
                          onRemove: () => context
                              .read<DogPostComposerCubit>()
                              .removeImage(i),
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

/// Fonte da imagem de uma [ComposerImage]: bytes locais (recém-escolhida) ou
/// URL remota (post em edição). `null` enquanto nenhuma das duas existe.
ImageProvider? _composerImageProvider(ComposerImage image) {
  final bytes = image.bytes;
  if (bytes != null) return MemoryImage(bytes);
  final url = image.url;
  return url == null ? null : CachedNetworkImageProvider(url);
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

/// Área tocável de "Adicionar imagem" (nenhuma imagem escolhida ainda).
class _AddImagePlaceholder extends StatelessWidget {
  const _AddImagePlaceholder({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
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
}

/// Uma imagem do draft (qualquer tipo com imagem): preview com a foto
/// INTEIRA — o mesmo enquadramento do post, para o ponto marcado bater com o
/// que será salvo —, marcadores das legendas e ações. Tocar no preview ou no
/// botão "Legendas" abre o editor de tela cheia.
class _ComposerImageEditor extends StatelessWidget {
  const _ComposerImageEditor({
    required this.image,
    required this.onCaptions,
    required this.onRemove,
    this.label,
    this.onPick,
  });

  final ComposerImage image;
  final VoidCallback onCaptions;
  final VoidCallback onRemove;
  final String? label;

  /// Só nos tipos de imagem única, onde escolher outra foto substitui a atual.
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = _composerImageProvider(image);
    final captions = image.captions;
    final pick = onPick;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label case final text?) ...[
          Text(
            text,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (provider == null)
                  ColoredBox(color: theme.colorScheme.surfaceContainerHighest)
                else
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: image.uploading ? null : onCaptions,
                    child: ContainedImage(
                      provider: provider,
                      overlayBuilder: (context, geometry) => [
                        for (final caption in captions)
                          positionCaptionMarker(
                            anchor: geometry.anchorOf(caption.x, caption.y),
                            containerSize: geometry.containerSize,
                            child: const IgnorePointer(
                              child: DogPostCaptionMarker(),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (image.uploading) const _UploadingOverlay(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 4,
          children: [
            TextButton.icon(
              onPressed: image.uploading ? null : onCaptions,
              icon: const Icon(Icons.label_outline),
              label: Text(
                captions.isEmpty
                    ? 'Adicionar legenda'
                    : 'Legendas (${captions.length})',
              ),
            ),
            if (pick != null)
              TextButton.icon(
                onPressed: image.uploading ? null : pick,
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Trocar'),
              ),
            TextButton.icon(
              onPressed: image.uploading ? null : onRemove,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remover'),
            ),
          ],
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
