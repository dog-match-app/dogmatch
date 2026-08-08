import 'package:dogmatch/core/error/api_exception.dart';
import 'package:dogmatch/features/auth/domain/repositories/auth_repository.dart';
import 'package:dogmatch/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

part 'register_state.dart';

@injectable
class RegisterCubit extends Cubit<RegisterState> {
  RegisterCubit(this._authRepository, this._authBloc)
      : super(const RegisterState());

  final AuthRepository _authRepository;
  final AuthBloc _authBloc;

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    emit(state.copyWith(status: RegisterStatus.loading));
    try {
      final user = await _authRepository.register(
        name: name,
        email: email,
        password: password,
      );
      _authBloc.add(AuthLoggedIn(user));
      emit(state.copyWith(status: RegisterStatus.success));
    } on ApiException catch (exception) {
      emit(
        state.copyWith(
          status: RegisterStatus.error,
          errorMessage: exception.message,
        ),
      );
    }
  }
}
