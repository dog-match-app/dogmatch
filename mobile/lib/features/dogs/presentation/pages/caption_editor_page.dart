import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dogmatch/core/widgets/contained_image.dart';
import 'package:dogmatch/features/dogs/domain/entities/dog_post_draft.dart';
import 'package:dogmatch/features/dogs/domain/entities/dog_post_rules.dart';
import 'package:dogmatch/features/dogs/presentation/widgets/dog_post_card.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Argumentos da rota `/caption-editor` (via `extra`): a imagem em edição
/// ([bytes] recém-selecionados ou [url] já enviada) e as legendas atuais.
class CaptionEditorArgs {
  const CaptionEditorArgs({
    required this.captions,
    this.bytes,
    this.url,
    this.imageLabel,
  });

  final List<DogPostDraftCaption> captions;
  final Uint8List? bytes;
  final String? url;

  /// Identifica a imagem no carrossel (ex.: "Imagem 2 de 5").
  final String? imageLabel;
}

/// Editor de legendas posicionadas em tela cheia.
///
/// A imagem aparece INTEIRA (`BoxFit.contain`): as âncoras x/y são fração da
/// imagem (§3.5.2), então marcar sobre um preview recortado geraria
/// coordenadas erradas e esconderia parte da foto.
///
/// Qualquer saída (Concluir, voltar ou gesto do sistema) devolve a lista
/// editada — o composer é a fonte da verdade do estado.
class CaptionEditorPage extends StatefulWidget {
  const CaptionEditorPage({super.key, required this.args});

  final CaptionEditorArgs args;

  @override
  State<CaptionEditorPage> createState() => _CaptionEditorPageState();
}

class _CaptionEditorPageState extends State<CaptionEditorPage> {
  late List<DogPostDraftCaption> _captions = [...widget.args.captions];

  ImageProvider? get _provider {
    final bytes = widget.args.bytes;
    if (bytes != null) return MemoryImage(bytes);
    final url = widget.args.url;
    return url == null ? null : CachedNetworkImageProvider(url);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Devolve `null` no cancelamento e string vazia quando pediram remover.
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
                  : () => Navigator.of(dialogContext).pop(value.text.trim()),
              child: const Text('Salvar'),
            ),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  Future<void> _addCaptionAt(Offset? normalized) async {
    if (normalized == null) return;
    if (_captions.length >= maxCaptionsPerImage) {
      _showSnackBar('Máximo de $maxCaptionsPerImage legendas por imagem');
      return;
    }
    final text = await _captionDialog();
    if (text == null || text.isEmpty) return;
    setState(() {
      _captions = [
        ..._captions,
        DogPostDraftCaption(text: text, x: normalized.dx, y: normalized.dy),
      ];
    });
  }

  Future<void> _editCaption(int index) async {
    final caption = _captions.elementAtOrNull(index);
    if (caption == null) return;
    final text = await _captionDialog(initialText: caption.text);
    if (text == null) return;
    setState(() {
      final captions = [..._captions];
      if (text.isEmpty) {
        captions.removeAt(index);
      } else {
        captions[index] =
            DogPostDraftCaption(text: text, x: caption.x, y: caption.y);
      }
      _captions = captions;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = _provider;
    return PopScope<List<DogPostDraftCaption>>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.pop(_captions);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text('Legendas: ${_captions.length}/$maxCaptionsPerImage'),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: () => context.pop(_captions),
              child: const Text('Concluir'),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  children: [
                    if (widget.args.imageLabel case final label?)
                      Text(
                        label,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(color: Colors.white),
                      ),
                    Text(
                      'Toque no ponto da foto onde quer a legenda.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.white70),
                    ),
                    if (_captions.isNotEmpty)
                      Text(
                        'Toque num marcador para editar ou remover.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.white54),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: provider == null
                    ? const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          size: 64,
                          color: Colors.white38,
                        ),
                      )
                    : ContainedImage(
                        provider: provider,
                        background: Colors.black,
                        placeholder: const Center(
                          child: SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                        errorWidget: const Icon(
                          Icons.broken_image_outlined,
                          size: 64,
                          color: Colors.white38,
                        ),
                        onTapAt: _addCaptionAt,
                        overlayBuilder: (context, geometry) => [
                          for (var i = 0; i < _captions.length; i++)
                            positionCaptionMarker(
                              anchor: geometry.anchorOf(
                                _captions[i].x,
                                _captions[i].y,
                              ),
                              containerSize: geometry.containerSize,
                              child: GestureDetector(
                                onTap: () => _editCaption(i),
                                child: const DogPostCaptionMarker(),
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
