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

  /// Inclui as chaves nulas de propósito: no PATCH o objeto `social` é
  /// enviado completo e `null` limpa o campo correspondente.
  Map<String, dynamic> toJson() => _$DogSocialModelToJson(this);

  @override
  List<Object?> get props => [whatsapp, instagram, pinterest, telegram];
}
