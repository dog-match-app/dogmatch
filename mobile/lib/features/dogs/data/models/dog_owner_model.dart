import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'dog_owner_model.g.dart';

/// Resumo do dono de um cão (`{ id, name, city?, avatarUrl? }`) — usado em
/// `GET /dogs/:id` (`DogDto.owner`) e nos cards da busca (`SearchCardDto.owner`).
@JsonSerializable()
class DogOwnerModel extends Equatable {
  const DogOwnerModel({
    required this.id,
    required this.name,
    this.city,
    this.avatarUrl,
  });

  factory DogOwnerModel.fromJson(Map<String, dynamic> json) =>
      _$DogOwnerModelFromJson(json);

  final String id;
  final String name;
  final String? city;
  final String? avatarUrl;

  Map<String, dynamic> toJson() => _$DogOwnerModelToJson(this);

  @override
  List<Object?> get props => [id, name, city, avatarUrl];
}
