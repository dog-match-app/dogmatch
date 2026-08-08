import 'package:dogmatch/features/dogs/data/models/dog_model.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'user_model.g.dart';

/// `UserDto` do contrato da API.
///
/// `dogs` só vem populado em `GET /users/me`.
@JsonSerializable()
class UserModel extends Equatable {
  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.phone,
    this.bio,
    this.avatarUrl,
    this.city,
    this.latitude,
    this.longitude,
    required this.createdAt,
    this.dogs,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  final String id;
  final String email;
  final String name;
  final String? phone;
  final String? bio;
  final String? avatarUrl;
  final String? city;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;
  final List<DogModel>? dogs;

  bool get hasLocation => latitude != null && longitude != null;

  Map<String, dynamic> toJson() => _$UserModelToJson(this);

  @override
  List<Object?> get props => [
        id,
        email,
        name,
        phone,
        bio,
        avatarUrl,
        city,
        latitude,
        longitude,
        createdAt,
        dogs,
      ];
}
