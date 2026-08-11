part of 'profile_cubit.dart';

enum ProfileStatus { initial, loading, loaded, error }

class ProfileState extends Equatable {
  const ProfileState({
    this.status = ProfileStatus.initial,
    this.user,
    this.saving = false,
    this.uploadingAvatar = false,
    this.updatingLocation = false,
    this.locationSettingsPrompt = false,
    this.errorMessage,
    this.successMessage,
  });

  final ProfileStatus status;
  final UserModel? user;
  final bool saving;
  final bool uploadingAvatar;
  final bool updatingLocation;

  /// Transitório: permissão bloqueada (deniedForever) — a página abre o
  /// dialog que leva às configurações do aplicativo.
  final bool locationSettingsPrompt;

  /// Mensagens transitórias consumidas por BlocListener (SnackBar).
  final String? errorMessage;
  final String? successMessage;

  ProfileState copyWith({
    ProfileStatus? status,
    UserModel? user,
    bool? saving,
    bool? uploadingAvatar,
    bool? updatingLocation,
    bool locationSettingsPrompt = false,
    String? errorMessage,
    String? successMessage,
  }) {
    return ProfileState(
      status: status ?? this.status,
      user: user ?? this.user,
      saving: saving ?? this.saving,
      uploadingAvatar: uploadingAvatar ?? this.uploadingAvatar,
      updatingLocation: updatingLocation ?? this.updatingLocation,
      locationSettingsPrompt: locationSettingsPrompt,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        user,
        saving,
        uploadingAvatar,
        updatingLocation,
        locationSettingsPrompt,
        errorMessage,
        successMessage,
      ];
}
