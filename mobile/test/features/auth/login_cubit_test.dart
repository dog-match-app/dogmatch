import 'package:bloc_test/bloc_test.dart';
import 'package:dogmatch/core/error/api_exception.dart';
import 'package:dogmatch/features/auth/data/models/user_model.dart';
import 'package:dogmatch/features/auth/domain/repositories/auth_repository.dart';
import 'package:dogmatch/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:dogmatch/features/auth/presentation/cubit/login_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {
}

void main() {
  final user = UserModel(
    id: 'user-1',
    email: 'tutor@dogmatch.com',
    name: 'Tutor',
    createdAt: DateTime.utc(2026),
  );

  late MockAuthRepository authRepository;
  late MockAuthBloc authBloc;

  setUpAll(() {
    registerFallbackValue(AuthLoggedIn(user));
  });

  setUp(() {
    authRepository = MockAuthRepository();
    authBloc = MockAuthBloc();
  });

  LoginCubit buildCubit() => LoginCubit(authRepository, authBloc);

  group('LoginCubit', () {
    blocTest<LoginCubit, LoginState>(
      'emite [loading, success] e notifica o AuthBloc quando o login dá certo',
      build: () {
        when(
          () => authRepository.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => user);
        return buildCubit();
      },
      act: (cubit) =>
          cubit.login(email: 'tutor@dogmatch.com', password: 'senha12345'),
      expect: () => const [
        LoginState(status: LoginStatus.loading),
        LoginState(status: LoginStatus.success),
      ],
      verify: (_) {
        verify(
          () => authRepository.login(
            email: 'tutor@dogmatch.com',
            password: 'senha12345',
          ),
        ).called(1);
        verify(() => authBloc.add(AuthLoggedIn(user))).called(1);
      },
    );

    blocTest<LoginCubit, LoginState>(
      'emite [loading, error] com a mensagem da ApiException quando falha',
      build: () {
        when(
          () => authRepository.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(
          const ApiException('E-mail ou senha inválidos.', statusCode: 401),
        );
        return buildCubit();
      },
      act: (cubit) =>
          cubit.login(email: 'tutor@dogmatch.com', password: 'senha-errada'),
      expect: () => const [
        LoginState(status: LoginStatus.loading),
        LoginState(
          status: LoginStatus.error,
          errorMessage: 'E-mail ou senha inválidos.',
        ),
      ],
      verify: (_) {
        verifyNever(() => authBloc.add(any(that: isA<AuthLoggedIn>())));
      },
    );
  });
}
