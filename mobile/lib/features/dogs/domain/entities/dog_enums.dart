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
///
/// `BOTH` nunca vira o rótulo "Ambos" na UI: como tag, é exibido como DOIS
/// chips ("Cruzamento" + "Amizade" — ver [displayIntents]); como valor único,
/// por extenso ("Cruzamento e amizade").
enum DogIntent {
  @JsonValue('BREEDING')
  breeding('BREEDING', 'Cruzamento'),
  @JsonValue('FRIENDSHIP')
  friendship('FRIENDSHIP', 'Amizade'),
  @JsonValue('BOTH')
  both('BOTH', 'Cruzamento e amizade');

  const DogIntent(this.apiValue, this.labelPtBr);

  final String apiValue;
  final String labelPtBr;
}

/// Desdobra a intenção em tags individuais: `BOTH` vira as duas intenções
/// simples; as demais viram uma lista de um item.
extension DogIntentDisplay on DogIntent {
  List<DogIntent> get displayIntents => this == DogIntent.both
      ? const [DogIntent.breeding, DogIntent.friendship]
      : [this];
}
