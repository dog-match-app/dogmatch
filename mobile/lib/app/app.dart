import 'package:dogmatch/app/di/injection.dart';
import 'package:dogmatch/app/router/app_router.dart';
import 'package:dogmatch/app/session/session_reset.dart';
import 'package:dogmatch/app/theme/app_theme.dart';
import 'package:dogmatch/core/services/location_service.dart';
import 'package:dogmatch/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

class DogMatchApp extends StatefulWidget {
  const DogMatchApp({super.key});

  @override
  State<DogMatchApp> createState() => _DogMatchAppState();
}

class _DogMatchAppState extends State<DogMatchApp> {
  late final AuthBloc _authBloc;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authBloc = getIt<AuthBloc>()..add(const AuthAppStarted());
    _router = buildAppRouter(_authBloc);
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _authBloc,
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            getIt<LocationService>().startSession();
          } else if (state is AuthUnauthenticated) {
            // Fim de sessão: limpeza central de TODO estado por-conta dos
            // singletons (cães da conta anterior, flags de localização...).
            getIt<SessionReset>().resetSession();
          }
        },
        child: MaterialApp.router(
          title: 'DogMatch',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          locale: const Locale('pt', 'BR'),
          supportedLocales: const [Locale('pt', 'BR'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: _router,
        ),
      ),
    );
  }
}
