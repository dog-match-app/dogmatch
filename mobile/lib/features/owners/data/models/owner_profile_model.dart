import 'package:dogmatch/features/dogs/data/models/dog_model.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'owner_profile_model.g.dart';

/// Estatísticas do perfil público (`OwnerProfileDto.stats`).
@JsonSerializable()
class OwnerStatsModel extends Equatable {
  const OwnerStatsModel({required this.dogs, required this.matches});

  factory OwnerStatsModel.fromJson(Map<String, dynamic> json) =>
      _$OwnerStatsModelFromJson(json);

  final int dogs;
  final int matches;

  Map<String, dynamic> toJson() => _$OwnerStatsModelToJson(this);

  @override
  List<Object?> get props => [dogs, matches];
}

/// `OwnerProfileDto` — perfil público do dono (`GET /users/:id/profile`).
///
/// Nunca inclui e-mail, telefone ou coordenadas (contrato §4).
@JsonSerializable()
class OwnerProfileModel extends Equatable {
  const OwnerProfileModel({
    required this.id,
    required this.name,
    this.bio,
    this.avatarUrl,
    this.city,
    required this.memberSince,
    this.distanceKm,
    required this.stats,
    this.dogs = const [],
  });

  factory OwnerProfileModel.fromJson(Map<String, dynamic> json) =>
      _$OwnerProfileModelFromJson(json);

  final String id;
  final String name;
  final String? bio;
  final String? avatarUrl;
  final String? city;
  final DateTime memberSince;

  /// `null` quando uma das partes não tem localização.
  final double? distanceKm;

  final OwnerStatsModel stats;

  /// Cães ativos do dono.
  final List<DogModel> dogs;

  /// Primeiro nome (para títulos como "Cães de Ana").
  String get firstName {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return name;
    return trimmed.split(RegExp(r'\s+')).first;
  }

  /// Distância formatada em PT-BR (`"850 m"` / `"4,6 km"`) ou `null`.
  String? get distanceLabel {
    final distance = distanceKm;
    if (distance == null) return null;
    if (distance < 1) return '${(distance * 1000).round()} m';
    return '${distance.toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  Map<String, dynamic> toJson() => _$OwnerProfileModelToJson(this);

  @override
  List<Object?> get props => [
        id,
        name,
        bio,
        avatarUrl,
        city,
        memberSince,
        distanceKm,
        stats,
        dogs,
      ];
}
