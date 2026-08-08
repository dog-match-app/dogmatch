import 'package:dogmatch/features/dogs/data/models/dog_post_image_model.dart';
import 'package:dogmatch/features/dogs/domain/entities/dog_post_type.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'dog_post_model.g.dart';

/// `DogPostDto` — post da página do cão (ARCHITECTURE §3.5.2/§4).
@JsonSerializable()
class DogPostModel extends Equatable {
  const DogPostModel({
    required this.id,
    required this.dogId,
    required this.type,
    this.text,
    this.images = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory DogPostModel.fromJson(Map<String, dynamic> json) =>
      _$DogPostModelFromJson(json);

  final String id;
  final String dogId;
  final DogPostType type;
  final String? text;
  final List<DogPostImageModel> images;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => _$DogPostModelToJson(this);

  /// Imagens ordenadas por `position`.
  List<DogPostImageModel> get sortedImages {
    final sorted = [...images]
      ..sort((a, b) => a.position.compareTo(b.position));
    return sorted;
  }

  /// Texto presente e não vazio (no CAROUSEL ele é opcional).
  bool get hasText => text != null && text!.trim().isNotEmpty;

  @override
  List<Object?> get props =>
      [id, dogId, type, text, images, createdAt, updatedAt];
}
