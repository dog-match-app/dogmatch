import 'package:dogmatch/features/dogs/data/models/dog_post_caption_model.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'dog_post_image_model.g.dart';

/// `DogPostImageDto` — imagem de um post da página do cão.
@JsonSerializable()
class DogPostImageModel extends Equatable {
  const DogPostImageModel({
    required this.id,
    required this.url,
    this.position = 0,
    this.captions = const [],
  });

  factory DogPostImageModel.fromJson(Map<String, dynamic> json) =>
      _$DogPostImageModelFromJson(json);

  final String id;
  final String url;
  final int position;
  final List<DogPostCaptionModel> captions;

  Map<String, dynamic> toJson() => _$DogPostImageModelToJson(this);

  @override
  List<Object?> get props => [id, url, position, captions];
}
