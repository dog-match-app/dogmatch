import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Argumentos da rota `/photo-viewer` (via `extra`).
class PhotoViewerArgs {
  const PhotoViewerArgs({required this.photos, this.initialIndex = 0});

  /// URLs das fotos, na ordem do carousel de origem.
  final List<String> photos;

  /// Foto exibida ao abrir.
  final int initialIndex;
}

/// Visualizador de fotos em tela cheia: fundo preto, paginação por arrasto,
/// pinça até 5x e duplo-toque alternando 1x ↔ 2.5x. Com zoom ativo o
/// PageView não pagina (o arrasto vira pan da foto).
class PhotoViewerPage extends StatefulWidget {
  const PhotoViewerPage({super.key, required this.args});

  final PhotoViewerArgs args;

  @override
  State<PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<PhotoViewerPage> {
  static const double _maxScale = 5;
  static const double _doubleTapScale = 2.5;

  /// Acima disso a foto é considerada "com zoom" (trava a paginação).
  static const double _zoomThreshold = 1.05;

  late final PageController _pageController;
  late final List<TransformationController> _transformationControllers;
  late int _index;
  bool _zoomed = false;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    final photoCount = widget.args.photos.length;
    _index = photoCount == 0
        ? 0
        : widget.args.initialIndex.clamp(0, photoCount - 1);
    _pageController = PageController(initialPage: _index);
    _transformationControllers = [
      for (var i = 0; i < photoCount; i++)
        TransformationController()..addListener(_onTransformChanged),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _transformationControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _currentPageZoomed =>
      _transformationControllers.isNotEmpty &&
      _transformationControllers[_index].value.getMaxScaleOnAxis() >
          _zoomThreshold;

  void _onTransformChanged() {
    final zoomed = _currentPageZoomed;
    if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
  }

  void _onPageChanged(int index) {
    setState(() {
      _index = index;
      _zoomed = _currentPageZoomed;
    });
  }

  void _handleDoubleTap(int index) {
    final controller = _transformationControllers[index];
    if (controller.value.getMaxScaleOnAxis() > _zoomThreshold) {
      controller.value = Matrix4.identity();
      return;
    }
    final position = _doubleTapDetails?.localPosition;
    final matrix =
        Matrix4.diagonal3Values(_doubleTapScale, _doubleTapScale, 1);
    if (position != null) {
      // Mantém o ponto tocado fixo na tela após o zoom.
      matrix.setTranslationRaw(
        -position.dx * (_doubleTapScale - 1),
        -position.dy * (_doubleTapScale - 1),
        0,
      );
    }
    controller.value = matrix;
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.args.photos;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: photos.isEmpty
                ? const Center(
                    child: Icon(Icons.pets, size: 96, color: Colors.white38),
                  )
                : PageView.builder(
                    controller: _pageController,
                    physics: _zoomed
                        ? const NeverScrollableScrollPhysics()
                        : null,
                    itemCount: photos.length,
                    onPageChanged: _onPageChanged,
                    itemBuilder: (context, index) => GestureDetector(
                      onDoubleTapDown: (details) =>
                          _doubleTapDetails = details,
                      onDoubleTap: () => _handleDoubleTap(index),
                      child: InteractiveViewer(
                        transformationController:
                            _transformationControllers[index],
                        maxScale: _maxScale,
                        child: Center(
                          child: CachedNetworkImage(
                            imageUrl: photos[index],
                            fit: BoxFit.contain,
                            placeholder: (_, _) => const SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white70,
                              ),
                            ),
                            errorWidget: (_, _, _) => const Icon(
                              Icons.broken_image_outlined,
                              size: 96,
                              color: Colors.white38,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Fechar',
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: photos.length > 1
                        ? Center(
                            child: Text(
                              '${_index + 1}/${photos.length}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(color: Colors.white),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  // Contrapeso do botão fechar para centralizar o contador.
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
