import 'package:dogmatch/core/utils/image_geometry.dart';
import 'package:flutter/material.dart';

/// Geometria já resolvida de uma imagem exibida com `BoxFit.contain`.
class ContainedImageGeometry {
  const ContainedImageGeometry({
    required this.containerSize,
    required this.imageSize,
  });

  final Size containerSize;
  final Size imageSize;

  /// Posição em pixels do container para a âncora normalizada [x]/[y].
  Offset anchorOf(double x, double y) => imagePointToLocal(
        containerSize: containerSize,
        imageSize: imageSize,
        normalized: Offset(x, y),
      );
}

/// Imagem exibida por inteiro (`BoxFit.contain`) sobre [background], com
/// sobreposições ancoradas em coordenadas normalizadas da própria imagem.
///
/// O tamanho real é resolvido pelo `ImageStream` antes de qualquer overlay
/// ser desenhado: sem ele não dá para saber onde está o retângulo da imagem
/// dentro do container (com `contain` sobra letterbox).
class ContainedImage extends StatefulWidget {
  const ContainedImage({
    super.key,
    required this.provider,
    this.background,
    this.placeholder,
    this.errorWidget,
    this.onTapAt,
    this.overlayBuilder,
  });

  final ImageProvider provider;
  final Color? background;
  final Widget? placeholder;
  final Widget? errorWidget;

  /// Toque com a âncora normalizada; `null` quando caiu na letterbox.
  final ValueChanged<Offset?>? onTapAt;

  final List<Widget> Function(
    BuildContext context,
    ContainedImageGeometry geometry,
  )? overlayBuilder;

  @override
  State<ContainedImage> createState() => _ContainedImageState();
}

class _ContainedImageState extends State<ContainedImage> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  Size? _imageSize;
  bool _failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(ContainedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.provider != oldWidget.provider) {
      _imageSize = null;
      _failed = false;
      _resolve();
    }
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  void _resolve() {
    final stream = widget.provider.resolve(
      createLocalImageConfiguration(context),
    );
    if (stream.key == _stream?.key) return;
    _detach();
    final listener = ImageStreamListener(_onImage, onError: _onError);
    _stream = stream..addListener(listener);
    _listener = listener;
  }

  void _detach() {
    final listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
    _listener = null;
    _stream = null;
  }

  void _onImage(ImageInfo info, bool synchronousCall) {
    final size = Size(
      info.image.width.toDouble(),
      info.image.height.toDouble(),
    );
    info.dispose();
    if (_imageSize == size && !_failed) return;
    // Entrega síncrona acontece dentro de didChangeDependencies/
    // didUpdateWidget, que já reconstroem — setState ali é proibido.
    if (synchronousCall) {
      _imageSize = size;
      _failed = false;
    } else if (mounted) {
      setState(() {
        _imageSize = size;
        _failed = false;
      });
    }
  }

  void _onError(Object error, StackTrace? stackTrace) {
    if (!mounted || _failed) return;
    setState(() => _failed = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageSize = _imageSize;
    return ColoredBox(
      color: widget.background ?? theme.colorScheme.surfaceContainerHighest,
      child: switch ((imageSize, _failed)) {
        (_, true) => Center(
            child: widget.errorWidget ??
                Icon(
                  Icons.broken_image_outlined,
                  size: 48,
                  color: theme.colorScheme.outline,
                ),
          ),
        (null, _) => widget.placeholder ?? const SizedBox.expand(),
        (final Size size, _) => LayoutBuilder(
            builder: (context, constraints) {
              final containerSize = Size(
                constraints.maxWidth,
                constraints.maxHeight,
              );
              final geometry = ContainedImageGeometry(
                containerSize: containerSize,
                imageSize: size,
              );
              final content = Stack(
                fit: StackFit.expand,
                children: [
                  Image(image: widget.provider, fit: BoxFit.contain),
                  ...?widget.overlayBuilder?.call(context, geometry),
                ],
              );
              final onTapAt = widget.onTapAt;
              if (onTapAt == null) return content;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) => onTapAt(
                  normalizedPointInImage(
                    containerSize: containerSize,
                    imageSize: size,
                    localPosition: details.localPosition,
                  ),
                ),
                child: content,
              );
            },
          ),
      },
    );
  }
}
