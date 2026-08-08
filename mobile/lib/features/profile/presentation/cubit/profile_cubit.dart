import 'dart:typed_data';

import 'package:dogmatch/core/error/api_exception.dart';
import 'package:dogmatch/features/auth/data/models/user_model.dart';
import 'package:dogmatch/features/profile/domain/repositories/profile_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:injectable/injectable.dart';

part 'profile_state.dart';

@injectable
class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit(this._profileRepository) : super(const ProfileState());

  final ProfileRepository _profileRepository;

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

  /// Lê a posição atual (geolocator) e envia `PATCH /users/me` só com
  /// latitude/longitude.
  Future<void> useMyLocation() async {
    emit(state.copyWith(updatingLocation: true));
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        emit(
          state.copyWith(
            updatingLocation: false,
            errorMessage:
                'Ative o serviço de localização (GPS) e tente novamente.',
          ),
        );
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        emit(
          state.copyWith(
            updatingLocation: false,
            errorMessage:
                'Permissão de localização negada. Habilite nas configurações.',
          ),
        );
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      final user = await _profileRepository.updateProfile(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      emit(
        state.copyWith(
          status: ProfileStatus.loaded,
          user: user,
          updatingLocation: false,
          successMessage: 'Localização atualizada!',
        ),
      );
    } on ApiException catch (exception) {
      emit(
        state.copyWith(
          updatingLocation: false,
          errorMessage: exception.message,
        ),
      );
    } on Exception {
      emit(
        state.copyWith(
          updatingLocation: false,
          errorMessage: 'Não foi possível obter sua localização.',
        ),
      );
    }
  }
}
