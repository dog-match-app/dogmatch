import 'package:dogmatch/features/dogs/data/models/dog_model.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'discovery_card_model.g.dart';

/// Resumo do dono no card de discovery (`DiscoveryCardDto.owner`).
@JsonSerializable()
class DiscoveryOwnerModel extends Equatable {
  const DiscoveryOwnerModel({
    required this.id,
    required this.name,
    this.city,
    this.avatarUrl,
  });

  factory DiscoveryOwnerModel.fromJson(Map<String, dynamic> json) =>
      _$DiscoveryOwnerModelFromJson(json);

  final String id;
  final String name;
  final String? city;
  final String? avatarUrl;

  Map<String, dynamic> toJson() => _$DiscoveryOwnerModelToJson(this);

  @override
  List<Object?> get props => [id, name, city, avatarUrl];
}

/// `DiscoveryCardDto` — item do feed `GET /discovery`.
@JsonSerializable()
class DiscoveryCardModel extends Equatable {
  const DiscoveryCardModel({
    required this.dog,
    required this.distanceKm,
    required this.owner,
  });

  factory DiscoveryCardModel.fromJson(Map<String, dynamic> json) =>
      _$DiscoveryCardModelFromJson(json);

  final DogModel dog;
  final double distanceKm;
  final DiscoveryOwnerModel owner;

  /// Distância formatada em PT-BR: `"850 m"` ou `"2,3 km"`.
  String get distanceLabel {
    if (distanceKm < 1) return '${(distanceKm * 1000).round()} m';
    return '${distanceKm.toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  Map<String, dynamic> toJson() => _$DiscoveryCardModelToJson(this);

  @override
  List<Object?> get props => [dog, distanceKm, owner];
}
