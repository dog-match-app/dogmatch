import 'package:dogmatch/features/dogs/domain/entities/dog_post_rules.dart';
import 'package:json_annotation/json_annotation.dart';

/// Tipo de um post da página do cão (`DogPostDto.type` — ARCHITECTURE §3.5.2).
enum DogPostType {
  @JsonValue('TEXT')
  text('TEXT', 'Só texto'),
  @JsonValue('IMAGE')
  image('IMAGE', 'Só imagem'),
  @JsonValue('IMAGE_TEXT')
  imageText('IMAGE_TEXT', 'Imagem e texto'),
  @JsonValue('CAROUSEL')
  carousel('CAROUSEL', 'Carrossel');

  const DogPostType(this.apiValue, this.labelPtBr);

  /// Valor enviado/recebido pela API.
  final String apiValue;

  /// Rótulo exibido na UI.
  final String labelPtBr;
}

/// Regras de conteúdo por tipo (validações do §3.5.2).
extension DogPostTypeRules on DogPostType {
  /// O tipo aceita campo de texto (obrigatório ou opcional).
  bool get allowsText => this != DogPostType.image;

  /// O texto é obrigatório (no CAROUSEL ele é opcional).
  bool get requiresText =>
      this == DogPostType.text || this == DogPostType.imageText;

  int get minImages {
    switch (this) {
      case DogPostType.text:
        return 0;
      case DogPostType.image:
      case DogPostType.imageText:
        return 1;
      case DogPostType.carousel:
        return minCarouselImages;
    }
  }

  int get maxImages {
    switch (this) {
      case DogPostType.text:
        return 0;
      case DogPostType.image:
      case DogPostType.imageText:
        return 1;
      case DogPostType.carousel:
        return maxCarouselImages;
    }
  }
}
