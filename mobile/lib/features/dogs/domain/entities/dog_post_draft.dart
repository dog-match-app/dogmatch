import 'package:dogmatch/features/dogs/domain/entities/dog_post_type.dart';
import 'package:equatable/equatable.dart';

/// Payload de escrita de um post (`POST`/`PATCH /dogs/:id/posts` — §4):
/// `{ type, text?, images?: [{ key, position?, captions?: [{text,x,y}] }] }`.
///
/// O `PATCH` substitui o conteúdo por inteiro e não envia `type` (imutável).
class DogPostDraft extends Equatable {
  const DogPostDraft({required this.type, this.text, this.images = const []});

  final DogPostType type;
  final String? text;
  final List<DogPostDraftImage> images;

  /// Corpo da request. [includeType] = true no create; false no update.
  /// Texto vazio é omitido (a substituição do PATCH o torna nulo no backend).
  Map<String, dynamic> toPayload({required bool includeType}) {
    final trimmed = text?.trim();
    return {
      if (includeType) 'type': type.apiValue,
      if (trimmed != null && trimmed.isNotEmpty) 'text': trimmed,
      if (images.isNotEmpty)
        'images': [for (final image in images) image.toPayload()],
    };
  }

  @override
  List<Object?> get props => [type, text, images];
}

/// Imagem do draft: referencia a `key` do storage (fluxo presigned §3.4).
class DogPostDraftImage extends Equatable {
  const DogPostDraftImage({
    required this.key,
    required this.position,
    this.captions = const [],
  });

  final String key;
  final int position;
  final List<DogPostDraftCaption> captions;

  Map<String, dynamic> toPayload() => {
        'key': key,
        'position': position,
        if (captions.isNotEmpty)
          'captions': [for (final caption in captions) caption.toPayload()],
      };

  @override
  List<Object?> get props => [key, position, captions];
}

/// Legenda posicionada: âncora normalizada `x`/`y` ∈ [0,1] (§3.5.2).
class DogPostDraftCaption extends Equatable {
  const DogPostDraftCaption({
    required this.text,
    required this.x,
    required this.y,
  });

  final String text;
  final double x;
  final double y;

  Map<String, dynamic> toPayload() => {'text': text, 'x': x, 'y': y};

  @override
  List<Object?> get props => [text, x, y];
}

/// Deriva a `key` de storage (`folder/uuid.ext` — §3.4) a partir da URL
/// pública (`S3_PUBLIC_URL/key`). Necessário porque o `DogPostImageDto` não
/// expõe a key, mas o `PATCH` substitui o conteúdo e precisa reenviá-la para
/// as imagens mantidas na edição.
String dogPostKeyFromUrl(String url) {
  final segments =
      Uri.parse(url).pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.length >= 2) {
    return '${segments[segments.length - 2]}/${segments.last}';
  }
  return segments.isEmpty ? url : segments.last;
}
