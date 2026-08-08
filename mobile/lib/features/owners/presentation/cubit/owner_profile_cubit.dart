import 'package:dogmatch/core/error/api_exception.dart';
import 'package:dogmatch/features/owners/data/models/owner_profile_model.dart';
import 'package:dogmatch/features/owners/domain/repositories/owners_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

part 'owner_profile_state.dart';

/// Carrega o perfil público de um dono (`GET /users/:id/profile`).
@injectable
class OwnerProfileCubit extends Cubit<OwnerProfileState> {
  OwnerProfileCubit(this._ownersRepository)
      : super(const OwnerProfileState());

  final OwnersRepository _ownersRepository;

  Future<void> load(String ownerId) async {
    emit(state.copyWith(status: OwnerProfileStatus.loading));
    try {
      final profile = await _ownersRepository.getOwnerProfile(ownerId);
      emit(
        state.copyWith(
          status: OwnerProfileStatus.success,
          profile: profile,
        ),
      );
    } on ApiException catch (exception) {
      emit(
        state.copyWith(
          status: OwnerProfileStatus.error,
          message: exception.message,
        ),
      );
    }
  }
}
