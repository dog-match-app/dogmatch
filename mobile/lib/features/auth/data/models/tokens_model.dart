import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'tokens_model.g.dart';

/// `TokensDto` — resposta de `POST /auth/refresh`.
@JsonSerializable()
class TokensModel extends Equatable {
  const TokensModel({
    required this.accessToken,
    required this.refreshToken,
  });

  factory TokensModel.fromJson(Map<String, dynamic> json) =>
      _$TokensModelFromJson(json);

  final String accessToken;
  final String refreshToken;

  Map<String, dynamic> toJson() => _$TokensModelToJson(this);

  @override
  List<Object?> get props => [accessToken, refreshToken];
}
