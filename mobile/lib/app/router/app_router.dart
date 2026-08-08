import 'dart:async';

import 'package:dogmatch/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:dogmatch/features/auth/presentation/pages/login_page.dart';
import 'package:dogmatch/features/auth/presentation/pages/register_page.dart';
import 'package:dogmatch/features/auth/presentation/pages/splash_page.dart';
import 'package:dogmatch/features/chat/presentation/pages/chat_page.dart';
import 'package:dogmatch/features/discovery/presentation/pages/discovery_page.dart';
import 'package:dogmatch/features/dogs/data/models/dog_model.dart';
import 'package:dogmatch/features/dogs/data/models/dog_post_model.dart';
import 'package:dogmatch/features/dogs/presentation/pages/dog_form_page.dart';
import 'package:dogmatch/features/dogs/presentation/pages/dog_post_composer_page.dart';
import 'package:dogmatch/features/dogs/presentation/pages/dog_posts_manager_page.dart';
import 'package:dogmatch/features/matches/data/models/match_model.dart';
import 'package:dogmatch/features/matches/presentation/pages/matches_page.dart';
import 'package:dogmatch/features/owners/presentation/pages/owner_profile_page.dart';
import 'package:dogmatch/features/profile/presentation/pages/profile_page.dart';
import 'package:dogmatch/features/search/data/models/search_card_model.dart';
import 'package:dogmatch/features/search/presentation/pages/dog_detail_page.dart';
import 'package:dogmatch/features/search/presentation/pages/photo_viewer_page.dart';
import 'package:dogmatch/features/search/presentation/pages/search_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Adapta o stream do AuthBloc para o `refreshListenable` do go_router.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription =
        stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// Router com guards por estado de autenticação:
/// - [AuthUnknown] ⇒ `/splash`;
/// - [AuthUnauthenticated] ⇒ `/login` (permite `/register`);
/// - [AuthAuthenticated] saindo de login/register/splash ⇒ `/discovery`.
GoRouter buildAppRouter(AuthBloc authBloc) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: GoRouterRefreshStream(authBloc.stream),
    redirect: (context, state) {
      final authState = authBloc.state;
      final location = state.matchedLocation;
      final isSplash = location == '/splash';
      final isAuthRoute = location == '/login' || location == '/register';

      if (authState is AuthUnknown) return isSplash ? null : '/splash';
      if (authState is AuthUnauthenticated) {
        return isAuthRoute ? null : '/login';
      }
      // Autenticado.
      if (isSplash || isAuthRoute) return '/discovery';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/dogs/new',
        builder: (context, state) => const DogFormPage(),
      ),
      GoRoute(
        path: '/dogs/:id/edit',
        builder: (context, state) => DogFormPage(
          dogId: state.pathParameters['id']!,
          initialDog: state.extra as DogModel?,
        ),
      ),
      // Página do cão (posts): gerência pelo dono (extra: DogModel opcional).
      GoRoute(
        path: '/dogs/:id/posts',
        builder: (context, state) => DogPostsManagerPage(
          dogId: state.pathParameters['id']!,
          dog: state.extra as DogModel?,
        ),
      ),
      GoRoute(
        path: '/dogs/:id/posts/new',
        builder: (context, state) => DogPostComposerPage(
          dogId: state.pathParameters['id']!,
        ),
      ),
      // Edição de um post (extra: DogPostModel; sem extra, busca na lista).
      GoRoute(
        path: '/dogs/:id/posts/:postId/edit',
        builder: (context, state) => DogPostComposerPage(
          dogId: state.pathParameters['id']!,
          postId: state.pathParameters['postId']!,
          initialPost: state.extra as DogPostModel?,
        ),
      ),
      GoRoute(
        path: '/chat/:matchId',
        builder: (context, state) => ChatPage(
          matchId: state.pathParameters['matchId']!,
          match: state.extra as MatchModel?,
        ),
      ),
      // Detalhe de um cão da busca (fora do shell, em tela cheia).
      GoRoute(
        path: '/search/dogs/:id',
        builder: (context, state) => DogDetailPage(
          dogId: state.pathParameters['id']!,
          card: state.extra as SearchCardModel?,
        ),
      ),
      // Perfil público do dono de um cão.
      GoRoute(
        path: '/owners/:id',
        builder: (context, state) => OwnerProfilePage(
          ownerId: state.pathParameters['id']!,
        ),
      ),
      // Fotos em tela cheia com zoom (extra: PhotoViewerArgs).
      GoRoute(
        path: '/photo-viewer',
        builder: (context, state) => PhotoViewerPage(
          args: state.extra as PhotoViewerArgs? ??
              const PhotoViewerArgs(photos: []),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            _HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/discovery',
                builder: (context, state) => const DiscoveryPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                builder: (context, state) => const SearchPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/matches',
                builder: (context, state) => const MatchesPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// Shell com a bottom navigation das 4 abas.
class _HomeShell extends StatelessWidget {
  const _HomeShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.pets_outlined),
            selectedIcon: Icon(Icons.pets),
            label: 'Descobrir',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Buscar',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
            label: 'Matches',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
