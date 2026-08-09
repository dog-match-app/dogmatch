import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'dog_social_model.g.dart';

/// `DogDto.social` — redes sociais opcionais do cão (ARCHITECTURE §3.5.3).
/// Valores livres (≤100): handle, número ou URL; o deep link é montado na UI.
@JsonSerializable()
class DogSocialModel extends Equatable {
  const DogSocialModel({
    this.whatsapp,
    this.instagram,
    this.pinterest,
    this.telegram,
  });

  factory DogSocialModel.fromJson(Map<String, dynamic> json) =>
      _$DogSocialModelFromJson(json);

  final String? whatsapp;
  final String? instagram;
  final String? pinterest;
  final String? telegram;

  /// Ao menos uma rede preenchida (a seção só aparece nesse caso).
  bool get hasAny => [whatsapp, instagram, pinterest, telegram]
      .any((value) => value != null && value.trim().isNotEmpty);

  Map<String, dynamic> toJson() => _$DogSocialModelToJson(this);

  /// Campos soltos do corpo de `POST /dogs` e `PATCH /dogs/:id`: a API recusa
  /// um objeto `social` aninhado (400). No PATCH, `null` limpa a rede.
  Map<String, dynamic> toRequestFields() => <String, dynamic>{
        'whatsapp': whatsapp,
        'instagram': instagram,
        'pinterest': pinterest,
        'telegram': telegram,
      };

  @override
  List<Object?> get props => [whatsapp, instagram, pinterest, telegram];
}
