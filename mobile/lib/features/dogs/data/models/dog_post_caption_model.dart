import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'dog_post_caption_model.g.dart';

/// `DogPostCaptionDto` — legenda posicionada de uma imagem de post:
/// âncora normalizada `x`/`y` ∈ [0,1] (fração da largura/altura da imagem).
@JsonSerializable()
class DogPostCaptionModel extends Equatable {
  const DogPostCaptionModel({
    required this.id,
    required this.text,
    required this.x,
    required this.y,
  });

  factory DogPostCaptionModel.fromJson(Map<String, dynamic> json) =>
      _$DogPostCaptionModelFromJson(json);

  final String id;
  final String text;
  final double x;
  final double y;

  Map<String, dynamic> toJson() => _$DogPostCaptionModelToJson(this);

  @override
  List<Object?> get props => [id, text, x, y];
}
