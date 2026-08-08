import 'package:dogmatch/features/auth/data/models/user_model.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'auth_response_model.g.dart';

/// `AuthResponseDto` — resposta de `POST /auth/register` e `POST /auth/login`.
@JsonSerializable()
class AuthResponseModel extends Equatable {
  const AuthResponseModel({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) =>
      _$AuthResponseModelFromJson(json);

  final UserModel user;
  final String accessToken;
  final String refreshToken;

  Map<String, dynamic> toJson() => _$AuthResponseModelToJson(this);

  @override
  List<Object?> get props => [user, accessToken, refreshToken];
}
