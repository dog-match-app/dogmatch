import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dogmatch/core/utils/telegram_text.dart';
import 'package:dogmatch/core/widgets/contained_image.dart';
import 'package:dogmatch/features/dogs/data/models/dog_post_image_model.dart';
import 'package:dogmatch/features/dogs/data/models/dog_post_model.dart';
import 'package:dogmatch/features/dogs/domain/entities/dog_post_type.dart';
import 'package:dogmatch/features/search/presentation/pages/photo_viewer_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Ícone que indica o tipo de post (chips do composer, header do manager).
IconData dogPostTypeIcon(DogPostType type) {
  switch (type) {
    case DogPostType.text:
      return Icons.notes_outlined;
    case DogPostType.image:
      return Icons.image_outlined;
    case DogPostType.imageText:
      return Icons.article_outlined;
    case DogPostType.carousel:
      return Icons.collections_outlined;
  }
}

/// Posiciona um marcador de legenda (caixa [DogPostCaptionMarker.boxSize])
/// com o centro em [anchor] (pixels do container), clampado às bordas.
///
/// [anchor] vem de `ContainedImageGeometry.anchorOf` — nunca de `x * largura`,
/// que ignora a letterbox do `BoxFit.contain`.
Positioned positionCaptionMarker({
  required Offset anchor,
  required Size containerSize,
  required Widget child,
}) {
  const box = DogPostCaptionMarker.boxSize;
  return Positioned(
    left: (anchor.dx - box / 2)
        .clamp(0.0, math.max(0.0, containerSize.width - box)),
    top: (anchor.dy - box / 2)
        .clamp(0.0, math.max(0.0, containerSize.height - box)),
    child: child,
  );
}

/// Marcador circular ⊕ semitransparente de uma legenda posicionada — usado
/// na visualização (abre o balão) e no composer (edita a legenda).
/// Cores fixas por estar SEMPRE sobre foto (mesmo racional dos dots).
class DogPostCaptionMarker extends StatelessWidget {
  const DogPostCaptionMarker({super.key, this.active = false});

  /// Lado da área de toque (o círculo visível tem 26).
  static const double boxSize = 34;

  final bool active;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: boxSize,
      height: boxSize,
      child: Center(
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.black38,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white70, width: 1.5),
          ),
          child: Icon(
            Icons.add,
            size: 16,
            color: active ? Colors.black87 : Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Card de um post da página do cão, renderizado conforme o tipo (§3.5.2):
/// TEXT (texto formatado), IMAGE (foto → viewer), IMAGE_TEXT (foto + texto)
/// e CAROUSEL (PageView com dots). Toda imagem pode ter legendas posicionadas.
class DogPostCard extends StatelessWidget {
  const DogPostCard({super.key, required this.post});

  final DogPostModel post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodyLarge;
    final images = post.sortedImages;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (post.type == DogPostType.carousel)
            _PostCarousel(images: images)
          else if (images.isNotEmpty)
            _PostImage(image: images.first),
          if (post.hasText)
            Padding(
              padding: const EdgeInsets.all(16),
              child: TelegramText(post.text!, style: textStyle),
            ),
        ],
      ),
    );
  }
}

/// Imagem única (IMAGE / IMAGE_TEXT); toque abre o [PhotoViewerPage].
class _PostImage extends StatelessWidget {
  const _PostImage({required this.image});

  final DogPostImageModel image;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: _CaptionedImage(
        image: image,
        onTap: () => context.push(
          '/photo-viewer',
          extra: PhotoViewerArgs(photos: [image.url]),
        ),
      ),
    );
  }
}

/// Carrossel com dots; cada página é uma [_CaptionedImage] e o toque na
/// imagem abre o viewer já na página atual.
class _PostCarousel extends StatefulWidget {
  const _PostCarousel({required this.images});

  final List<DogPostImageModel> images;

  @override
  State<_PostCarousel> createState() => _PostCarouselState();
}

class _PostCarouselState extends State<_PostCarousel> {
  int _page = 0;

  void _openViewer() {
    context.push(
      '/photo-viewer',
      extra: PhotoViewerArgs(
        photos: [for (final image in widget.images) image.url],
        initialIndex: _page,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            itemCount: widget.images.length,
            onPageChanged: (page) => setState(() => _page = page),
            itemBuilder: (context, index) => _CaptionedImage(
              image: widget.images[index],
              onTap: _openViewer,
            ),
          ),
          if (widget.images.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < widget.images.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: i == _page ? 20 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: i == _page ? Colors.white : Colors.white54,
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

/// Imagem de post com as legendas posicionadas: marcadores tocáveis e balão
/// da legenda ativa. A foto aparece inteira porque as âncoras x/y são fração
/// da imagem (§3.5.2) — recortar deslocaria os marcadores.
class _CaptionedImage extends StatefulWidget {
  const _CaptionedImage({required this.image, required this.onTap});

  final DogPostImageModel image;
  final VoidCallback onTap;

  @override
  State<_CaptionedImage> createState() => _CaptionedImageState();
}

class _CaptionedImageState extends State<_CaptionedImage> {
  int? _activeCaption;

  void _onImageTap(Offset? _) {
    if (_activeCaption != null) {
      setState(() => _activeCaption = null);
      return;
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final captions = widget.image.captions;
    final activeIndex = _activeCaption;
    final active = activeIndex == null || activeIndex >= captions.length
        ? null
        : captions[activeIndex];
    return ContainedImage(
      provider: CachedNetworkImageProvider(widget.image.url),
      onTapAt: _onImageTap,
      overlayBuilder: (context, geometry) => [
        for (var i = 0; i < captions.length; i++)
          positionCaptionMarker(
            anchor: geometry.anchorOf(captions[i].x, captions[i].y),
            containerSize: geometry.containerSize,
            child: GestureDetector(
              onTap: () => setState(
                () => _activeCaption = _activeCaption == i ? null : i,
              ),
              child: DogPostCaptionMarker(active: i == activeIndex),
            ),
          ),
        if (active != null)
          _captionBubble(
            anchor: geometry.anchorOf(active.x, active.y),
            containerSize: geometry.containerSize,
            text: active.text,
          ),
      ],
    );
  }

  /// Balão ancorado ao marcador: abre para baixo na metade superior da
  /// imagem (e vice-versa), com horizontal clampado às bordas.
  Widget _captionBubble({
    required Offset anchor,
    required Size containerSize,
    required String text,
  }) {
    final width = containerSize.width;
    final height = containerSize.height;
    final bubbleWidth = math.min(220.0, width - 16);
    final below = anchor.dy < height / 2;
    return Positioned(
      left: (anchor.dx - bubbleWidth / 2).clamp(8.0, width - bubbleWidth - 8.0),
      width: bubbleWidth,
      top: below ? anchor.dy + DogPostCaptionMarker.boxSize / 2 + 4 : null,
      bottom: below
          ? null
          : height - anchor.dy + DogPostCaptionMarker.boxSize / 2 + 4,
      child: GestureDetector(
        // Absorve o toque para o balão não fechar/abrir o viewer.
        onTap: () {},
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ),
      ),
    );
  }
}
