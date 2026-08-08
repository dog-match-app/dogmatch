import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'dog_photo_model.g.dart';

/// Foto de um cão (`DogDto.photos[]`).
@JsonSerializable()
class DogPhotoModel extends Equatable {
  const DogPhotoModel({
    required this.id,
    required this.url,
    this.position = 0,
  });

  factory DogPhotoModel.fromJson(Map<String, dynamic> json) =>
      _$DogPhotoModelFromJson(json);

  final String id;
  final String url;
  final int position;

  Map<String, dynamic> toJson() => _$DogPhotoModelToJson(this);

  @override
  List<Object?> get props => [id, url, position];
}
