import 'package:dogmatch/features/dogs/data/models/dog_model.dart';
import 'package:dogmatch/features/dogs/data/models/dog_owner_model.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'like_received_model.g.dart';

/// `LikeReceivedDto` — item de `GET /swipes/received`: um cão que curtiu o
/// cão consultado e ainda não teve resposta recíproca (sem match).
@JsonSerializable()
class LikeReceivedModel extends Equatable {
  const LikeReceivedModel({
    required this.dog,
    this.distanceKm,
    required this.owner,
    required this.likedAt,
    this.myAction,
  });

  factory LikeReceivedModel.fromJson(Map<String, dynamic> json) =>
      _$LikeReceivedModelFromJson(json);

  final DogModel dog;

  /// `null` quando uma das partes não tem localização.
  final double? distanceKm;

  final DogOwnerModel owner;

  /// Quando o like foi dado (lista vem em `likedAt desc`).
  final DateTime likedAt;

  /// `'PASS'` quando o cão consultado passou este cão (reversível — o
  /// backend permite re-swipe PASS→LIKE, §3.6); `null` sem interação.
  final String? myAction;

  Map<String, dynamic> toJson() => _$LikeReceivedModelToJson(this);

  bool get wasPassed => myAction == 'PASS';

  /// Distância formatada em PT-BR (`"850 m"` / `"2,3 km"`) ou `null`.
  String? get distanceLabel {
    final distance = distanceKm;
    if (distance == null) return null;
    if (distance < 1) return '${(distance * 1000).round()} m';
    return '${distance.toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  /// `"Cidade · 2,3 km"`, só a cidade, só a distância, ou `null`.
  String? get locationLabel {
    final city = owner.city;
    final distance = distanceLabel;
    if (city != null && distance != null) return '$city · $distance';
    return city ?? distance;
  }

  @override
  List<Object?> get props => [dog, distanceKm, owner, likedAt, myAction];
}

/// `LikesReceivedDto` — resposta de `GET /swipes/received`.
@JsonSerializable()
class LikesReceivedModel extends Equatable {
  const LikesReceivedModel({required this.items, required this.total});

  factory LikesReceivedModel.fromJson(Map<String, dynamic> json) =>
      _$LikesReceivedModelFromJson(json);

  final List<LikeReceivedModel> items;
  final int total;

  Map<String, dynamic> toJson() => _$LikesReceivedModelToJson(this);

  @override
  List<Object?> get props => [items, total];
}
