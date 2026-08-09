import 'dart:ui';

import 'package:dogmatch/core/utils/image_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Container 400x300 (4:3). Imagem 800x400 (2:1) é mais "larga" que ele:
  // escala 0.5, desenha 400x200 e sobram 50px de letterbox em cima e embaixo.
  const wideContainer = Size(400, 300);
  const wideImage = Size(800, 400);

  // Mesma ideia com a imagem mais "alta" (400x800, 1:2): escala 0.375,
  // desenha 150x300 e sobram 125px de barra em cada lado.
  const tallImage = Size(400, 800);

  group('containedImageRect', () {
    test('imagem mais larga: letterbox em cima e embaixo', () {
      final rect = containedImageRect(
        containerSize: wideContainer,
        imageSize: wideImage,
      );
      expect(rect, const Rect.fromLTWH(0, 50, 400, 200));
    });

    test('imagem mais alta: barras laterais', () {
      final rect = containedImageRect(
        containerSize: wideContainer,
        imageSize: tallImage,
      );
      expect(rect, const Rect.fromLTWH(125, 0, 150, 300));
    });

    test('mesma proporção preenche o container inteiro', () {
      final rect = containedImageRect(
        containerSize: wideContainer,
        imageSize: const Size(1200, 900),
      );
      expect(rect, const Rect.fromLTWH(0, 0, 400, 300));
    });

    test('tamanhos degenerados devolvem Rect.zero', () {
      expect(
        containedImageRect(
          containerSize: Size.zero,
          imageSize: wideImage,
        ),
        Rect.zero,
      );
      expect(
        containedImageRect(
          containerSize: wideContainer,
          imageSize: const Size(0, 400),
        ),
        Rect.zero,
      );
    });
  });

  group('normalizedPointInImage', () {
    Offset? point(Size imageSize, Offset localPosition) =>
        normalizedPointInImage(
          containerSize: wideContainer,
          imageSize: imageSize,
          localPosition: localPosition,
        );

    test('centro do container é o centro da imagem', () {
      expect(point(wideImage, const Offset(200, 150)), const Offset(0.5, 0.5));
      expect(point(tallImage, const Offset(200, 150)), const Offset(0.5, 0.5));
    });

    test('imagem mais larga: toque desconta a letterbox vertical', () {
      // y=100 está a 50px do topo da imagem (que começa em 50) — 1/4 dela.
      expect(point(wideImage, const Offset(100, 100)), const Offset(0.25, 0.25));
    });

    test('imagem mais alta: toque desconta as barras laterais', () {
      // x=162.5 está a 37.5px do início da imagem (que começa em 125) — 1/4.
      expect(
        point(tallImage, const Offset(162.5, 75)),
        const Offset(0.25, 0.25),
      );
    });

    test('toque na letterbox devolve null', () {
      expect(point(wideImage, const Offset(200, 10)), isNull);
      expect(point(wideImage, const Offset(200, 290)), isNull);
      expect(point(tallImage, const Offset(10, 150)), isNull);
      expect(point(tallImage, const Offset(390, 150)), isNull);
    });

    test('cantos da imagem viram 0.0 e 1.0', () {
      expect(point(wideImage, const Offset(0, 50)), Offset.zero);
      expect(point(wideImage, const Offset(400, 250)), const Offset(1, 1));
      expect(point(tallImage, const Offset(125, 0)), Offset.zero);
      expect(point(tallImage, const Offset(275, 300)), const Offset(1, 1));
    });

    test('container ou imagem degenerados devolvem null', () {
      expect(
        normalizedPointInImage(
          containerSize: Size.zero,
          imageSize: wideImage,
          localPosition: Offset.zero,
        ),
        isNull,
      );
      expect(
        normalizedPointInImage(
          containerSize: wideContainer,
          imageSize: Size.zero,
          localPosition: const Offset(200, 150),
        ),
        isNull,
      );
    });
  });

  group('imagePointToLocal', () {
    Offset local(Size imageSize, Offset normalized) => imagePointToLocal(
          containerSize: wideContainer,
          imageSize: imageSize,
          normalized: normalized,
        );

    test('desfaz normalizedPointInImage (ida e volta)', () {
      for (final imageSize in [wideImage, tallImage]) {
        for (final position in [
          const Offset(200, 150),
          const Offset(100, 100),
          const Offset(260, 200),
        ]) {
          final normalized = normalizedPointInImage(
            containerSize: wideContainer,
            imageSize: imageSize,
            localPosition: position,
          );
          if (normalized == null) continue;
          final back = local(imageSize, normalized);
          expect(back.dx, closeTo(position.dx, 0.0001));
          expect(back.dy, closeTo(position.dy, 0.0001));
        }
      }
    });

    test('âncoras fora de [0,1] são clampadas ao retângulo da imagem', () {
      expect(local(wideImage, const Offset(-1, 2)), const Offset(0, 250));
      expect(local(tallImage, const Offset(3, -0.5)), const Offset(275, 0));
    });
  });
}
