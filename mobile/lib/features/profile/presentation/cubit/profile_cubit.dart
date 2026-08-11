import 'dart:async';
import 'dart:typed_data';

import 'package:dogmatch/core/error/api_exception.dart';
import 'package:dogmatch/core/services/location_service.dart';
import 'package:dogmatch/features/auth/data/models/user_model.dart';
import 'package:dogmatch/features/profile/domain/repositories/profile_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

part 'profile_state.dart';

@injectable
class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit(this._profileRepository, this._locationService)
      : super(const ProfileState()) {
    _locationSyncSubscription =
        _locationService.onLocationSynced.listen((user) {
      emit(state.copyWith(status: ProfileStatus.loaded, user: user));
    });
  }

  final ProfileRepository _profileRepository;
  final LocationService _locationService;

  late final StreamSubscription<UserModel> _locationSyncSubscription;

  Future<void> load() async {
    emit(state.copyWith(status: ProfileStatus.loading));
    try {
      final user = await _profileRepository.getMe();
      emit(state.copyWith(status: ProfileStatus.loaded, user: user));
    } on ApiException catch (exception) {
      emit(
        state.copyWith(
          status: ProfileStatus.error,
          errorMessage: exception.message,
        ),
      );
    }
  }

  Future<void> saveProfile({
    required String name,
    required String city,
    required String bio,
  }) async {
    emit(state.copyWith(saving: true));
    try {
      final user = await _profileRepository.updateProfile(
        name: name,
        city: city,
        bio: bio,
      );
      emit(
        state.copyWith(
          status: ProfileStatus.loaded,
          user: user,
          saving: false,
          successMessage: 'Perfil atualizado!',
        ),
      );
    } on ApiException catch (exception) {
      emit(state.copyWith(saving: false, errorMessage: exception.message));
    }
  }

  Future<void> uploadAvatar({
    required Uint8List bytes,
    required String contentType,
  }) async {
    emit(state.copyWith(uploadingAvatar: true));
    try {
      final user = await _profileRepository.uploadAvatar(
        bytes: bytes,
        contentType: contentType,
      );
      emit(
        state.copyWith(
          status: ProfileStatus.loaded,
          user: user,
          uploadingAvatar: false,
          successMessage: 'Foto de perfil atualizada!',
        ),
      );
    } on ApiException catch (exception) {
      emit(
        state.copyWith(uploadingAvatar: false, errorMessage: exception.message),
      );
    }
  }

  /// Refresh manual do botão "Usar minha localização": todo o fluxo (pedido
  /// de permissão + `PATCH /users/me`) vive no [LocationService].
  Future<void> useMyLocation() async {
    emit(state.copyWith(updatingLocation: true));
    final result = await _locationService.ensurePermission(forceSync: true);
    if (result.synced) {
      emit(
        state.copyWith(
          status: ProfileStatus.loaded,
          user: result.user,
          updatingLocation: false,
          successMessage: 'Localização atualizada!',
        ),
      );
    } else if (result.status == LocationSyncStatus.permissionDeniedForever) {
      // O cubit não tem BuildContext: a página mostra o dialog que leva às
      // configurações ao ver esta flag transitória.
      emit(
        state.copyWith(updatingLocation: false, locationSettingsPrompt: true),
      );
    } else {
      emit(
        state.copyWith(
          updatingLocation: false,
          errorMessage: result.errorMessage,
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    await _locationSyncSubscription.cancel();
    return super.close();
  }
}
