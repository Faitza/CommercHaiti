import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
// import 'package:provider/provider.dart';
// import '../providers/auth_provider.dart';

import '../screens/auth/splash_screen.dart';
import '../screens/auth/onboarding_screen.dart';
import '../screens/auth/role_selection_screen.dart';
import '../screens/auth/auth_screen.dart';
import '../screens/auth/guest_home_screen.dart';
import '../screens/auth/create_shop_screen.dart';

/// Router de navigation — Faitza COLAS
/// Branch : feature/auth-roles
/// Path : lib/router/app_router.dart
/// Guards : vérifie rôle avant chaque route protégée
class AppRouter {
  static GoRouter get router => GoRouter(
        initialLocation: '/splash',

        // Guard global — vérifie auth à chaque navigation
        redirect: (context, state) {
          // TODO : décommenter quand AuthProvider sera prêt
          // final auth = context.read<AuthProvider>();
          // final isLoggedIn = auth.isLoggedIn;
          // final role = auth.currentUser?.role;
          // final path = state.uri.path;

          // if (!isLoggedIn) {
          //   if (path.startsWith('/vendor')) return '/role-selection';
          //   if (path.startsWith('/client')) return '/role-selection';
          // }
          // if (role == 'customer' && path.startsWith('/vendor'))
          //   return '/client/home';
          // if (role == 'seller' && path.startsWith('/client'))
          //   return '/vendor/dashboard';

          return null; // null = accès autorisé
        },

        routes: [
          // ── Auth ──
          GoRoute(
            path: '/splash',
            builder: (_, __) => const SplashScreen(),
          ),
          GoRoute(
            path: '/onboarding',
            builder: (_, __) => const OnboardingScreen(),
          ),
          GoRoute(
            path: '/role-selection',
            builder: (_, __) => const RoleSelectionScreen(),
          ),
          GoRoute(
            path: '/auth',
            builder: (_, state) {
              final role = state.extra as Map<String, dynamic>?;
              return AuthScreen(role: role?['role'] ?? 'customer');
            },
          ),
          GoRoute(
            path: '/guest',
            builder: (_, __) => const GuestHomeScreen(),
          ),
          GoRoute(
            path: '/create-shop',
            builder: (_, state) {
              final data = state.extra as Map<String, dynamic>?;
              return CreateShopScreen(
                shopCode: data?['shopCode'] ?? 'MFL-2026-0000',
              );
            },
          ),

          // ── Client (Claudimyr) ──
          // TODO : ajouter routes client quand feature/client-home sera mergé
          // GoRoute(path: '/client/home', builder: ...),
          // GoRoute(path: '/client/boutiques', builder: ...),

          // ── Vendor (Faitza) ──
          // TODO : ajouter routes vendeur quand feature/vendor-catalog sera mergé
          // GoRoute(path: '/vendor/dashboard', builder: ...),
          // GoRoute(path: '/vendor/products', builder: ...),
        ],

        // Page 404
        errorBuilder: (_, state) => Scaffold(
          body: Center(
            child: Text('Page introuvable: ${state.uri}'),
          ),
        ),
      );
}