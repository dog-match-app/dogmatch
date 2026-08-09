import 'package:dogmatch/features/dogs/data/models/dog_model.dart';
import 'package:dogmatch/features/dogs/data/models/dog_owner_model.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'search_card_model.g.dart';

/// `SearchCardDto` — item de `GET /discovery/search`.
@JsonSerializable()
class SearchCardModel extends Equatable {
  const SearchCardModel({
    required this.dog,
    this.distanceKm,
    required this.owner,
    this.myAction,
    this.matched,
    this.isMine = false,
  });

  factory SearchCardModel.fromJson(Map<String, dynamic> json) =>
      _$SearchCardModelFromJson(json);

  /// Valor de [myAction] quando o cão ativo já curtiu este cão.
  static const String likeAction = 'LIKE';

  final DogModel dog;

  /// `null` quando uma das partes não tem localização.
  final double? distanceKm;

  final DogOwnerModel owner;

  /// `'LIKE' | 'PASS'` — presente apenas quando a busca foi feita com a
  /// perspectiva de um cão (`dogId`).
  final String? myAction;

  final bool? matched;

  @JsonKey(defaultValue: false)
  final bool isMine;

  bool get isMatched => matched ?? false;

  bool get isLiked => myAction == likeAction;

  /// O cão ativo já interagiu (like ou pass) com este cão.
  bool get hasMyAction => myAction != null;

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

  /// Cópia com a interação local atualizada (após like/pass no detalhe).
  SearchCardModel copyWith({String? myAction, bool? matched}) {
    return SearchCardModel(
      dog: dog,
      distanceKm: distanceKm,
      owner: owner,
      myAction: myAction ?? this.myAction,
      matched: matched ?? this.matched,
      isMine: isMine,
    );
  }

  /// Cópia sem os badges de perspectiva, usada ao trocar o cão ativo:
  /// `myAction`/`matched` só valem para o cão que fez a busca.
  SearchCardModel withoutMyPerspective() {
    return SearchCardModel(
      dog: dog,
      distanceKm: distanceKm,
      owner: owner,
      isMine: isMine,
    );
  }

  Map<String, dynamic> toJson() => _$SearchCardModelToJson(this);

  @override
  List<Object?> get props => [dog, distanceKm, owner, myAction, matched, isMine];
}
