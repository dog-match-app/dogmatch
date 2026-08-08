import 'package:json_annotation/json_annotation.dart';

/// Sexo do cão (`DogDto.sex`).
enum DogSex {
  @JsonValue('MALE')
  male('MALE', 'Macho'),
  @JsonValue('FEMALE')
  female('FEMALE', 'Fêmea');

  const DogSex(this.apiValue, this.labelPtBr);

  /// Valor enviado/recebido pela API.
  final String apiValue;

  /// Rótulo exibido na UI.
  final String labelPtBr;
}

/// Porte do cão (`DogDto.size`).
enum DogSize {
  @JsonValue('SMALL')
  small('SMALL', 'Pequeno'),
  @JsonValue('MEDIUM')
  medium('MEDIUM', 'Médio'),
  @JsonValue('LARGE')
  large('LARGE', 'Grande'),
  @JsonValue('GIANT')
  giant('GIANT', 'Gigante');

  const DogSize(this.apiValue, this.labelPtBr);

  final String apiValue;
  final String labelPtBr;
}

/// Intenção do perfil do cão (`DogDto.intent`).
enum DogIntent {
  @JsonValue('BREEDING')
  breeding('BREEDING', 'Cruzamento'),
  @JsonValue('FRIENDSHIP')
  friendship('FRIENDSHIP', 'Amizade'),
  @JsonValue('BOTH')
  both('BOTH', 'Ambos');

  const DogIntent(this.apiValue, this.labelPtBr);

  final String apiValue;
  final String labelPtBr;
}
