part of 'owner_profile_cubit.dart';

enum OwnerProfileStatus { initial, loading, success, error }

class OwnerProfileState extends Equatable {
  const OwnerProfileState({
    this.status = OwnerProfileStatus.initial,
    this.profile,
    this.message,
  });

  final OwnerProfileStatus status;

  /// Perfil carregado (presente no status [OwnerProfileStatus.success]).
  final OwnerProfileModel? profile;

  /// Mensagem de erro pronta em PT-BR (estado de erro com retry).
  final String? message;

  OwnerProfileState copyWith({
    OwnerProfileStatus? status,
    OwnerProfileModel? profile,
    String? message,
  }) {
    return OwnerProfileState(
      status: status ?? this.status,
      profile: profile ?? this.profile,
      message: message,
    );
  }

  @override
  List<Object?> get props => [status, profile, message];
}
