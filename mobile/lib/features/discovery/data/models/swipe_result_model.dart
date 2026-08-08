import 'package:dogmatch/features/matches/data/models/match_model.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'swipe_result_model.g.dart';

/// `SwipeResultDto` — resposta de `POST /swipes`.
@JsonSerializable()
class SwipeResultModel extends Equatable {
  const SwipeResultModel({
    required this.matched,
    this.match,
  });

  factory SwipeResultModel.fromJson(Map<String, dynamic> json) =>
      _$SwipeResultModelFromJson(json);

  final bool matched;

  /// Presente apenas quando `matched == true`.
  final MatchModel? match;

  Map<String, dynamic> toJson() => _$SwipeResultModelToJson(this);

  @override
  List<Object?> get props => [matched, match];
}
