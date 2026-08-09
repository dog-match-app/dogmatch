import 'dart:math' as math;
import 'dart:ui';

/// Retângulo ocupado pela imagem dentro do container quando exibida com
/// `BoxFit.contain`: a imagem é centralizada e sobram barras (letterbox) no
/// eixo em que ela é mais "curta". `Rect.zero` para tamanhos degenerados.
Rect containedImageRect({
  required Size containerSize,
  required Size imageSize,
}) {
  if (containerSize.isEmpty || imageSize.isEmpty) return Rect.zero;
  final scale = math.min(
    containerSize.width / imageSize.width,
    containerSize.height / imageSize.height,
  );
  final width = imageSize.width * scale;
  final height = imageSize.height * scale;
  return Rect.fromLTWH(
    (containerSize.width - width) / 2,
    (containerSize.height - height) / 2,
    width,
    height,
  );
}

/// Converte [localPosition] (pixels do container) na âncora normalizada
/// x/y ∈ [0,1] **da imagem** (§3.5.2), não do container.
///
/// Devolve `null` quando o toque caiu na letterbox — ali não existe ponto da
/// imagem, então não há legenda a criar.
Offset? normalizedPointInImage({
  required Size containerSize,
  required Size imageSize,
  required Offset localPosition,
}) {
  final rect = containedImageRect(
    containerSize: containerSize,
    imageSize: imageSize,
  );
  if (rect.isEmpty) return null;
  if (localPosition.dx < rect.left ||
      localPosition.dx > rect.right ||
      localPosition.dy < rect.top ||
      localPosition.dy > rect.bottom) {
    return null;
  }
  return Offset(
    ((localPosition.dx - rect.left) / rect.width).clamp(0.0, 1.0),
    ((localPosition.dy - rect.top) / rect.height).clamp(0.0, 1.0),
  );
}

/// Inverso de [normalizedPointInImage]: posição em pixels do container para a
/// âncora [normalized]. Marcar e desenhar precisam da MESMA geometria, senão
/// o marcador aparece deslocado do ponto tocado.
Offset imagePointToLocal({
  required Size containerSize,
  required Size imageSize,
  required Offset normalized,
}) {
  final rect = containedImageRect(
    containerSize: containerSize,
    imageSize: imageSize,
  );
  return Offset(
    rect.left + normalized.dx.clamp(0.0, 1.0) * rect.width,
    rect.top + normalized.dy.clamp(0.0, 1.0) * rect.height,
  );
}
