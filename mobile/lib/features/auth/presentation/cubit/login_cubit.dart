import 'package:dogmatch/core/error/api_exception.dart';
import 'package:dogmatch/features/auth/domain/repositories/auth_repository.dart';
import 'package:dogmatch/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

part 'login_state.dart';

@injectable
class LoginCubit extends Cubit<LoginState> {
  LoginCubit(this._authRepository, this._authBloc) : super(const LoginState());

  final AuthRepository _authRepository;
  final AuthBloc _authBloc;

  Future<void> login({required String email, required String password}) async {
    emit(state.copyWith(status: LoginStatus.loading));
    try {
      final user = await _authRepository.login(
        email: email,
        password: password,
      );
      _authBloc.add(AuthLoggedIn(user));
      emit(state.copyWith(status: LoginStatus.success));
    } on ApiException catch (exception) {
      emit(
        state.copyWith(
          status: LoginStatus.error,
          errorMessage: exception.message,
        ),
      );
    }
  }
}
