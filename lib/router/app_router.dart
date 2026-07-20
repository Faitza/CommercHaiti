import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

// Auth screens
import '../screens/auth/splash_screen.dart';
import '../screens/auth/onboarding_screen.dart';
import '../screens/auth/role_selection_screen.dart';
import '../screens/auth/auth_screen.dart';
import '../screens/auth/guest_home_screen.dart';
import '../screens/auth/create_shop_screen.dart';

// Vendor screens
import '../screens/vendor/vendor_dashboard_screen.dart';
import '../screens/vendor/vendor_products_screen.dart';
import '../screens/vendor/vendor_orders_screen.dart';
import '../screens/vendor/vendor_order_detail_screen.dart';
import '../screens/vendor/vendor_add_product_screen.dart';
import '../screens/vendor/vendor_edit_product_screen.dart';
import '../screens/vendor/vendor_stats_screen.dart';

// Client screens (Claudimyr — décommenter après merge)
// import '../screens/client/client_home_screen.dart';
// import '../screens/client/boutiques_screen.dart';
// import '../screens/client/boutique_detail_screen.dart';
// import '../screens/client/product_detail_screen.dart';
// import '../screens/orders/cart_screen.dart';
// import '../screens/orders/order_form_screen.dart';
// import '../screens/orders/order_tracking_screen.dart';
// import '../screens/orders/order_history_screen.dart';

// Settings screens (Falexson — décommenter après merge)
// import '../screens/settings/settings_screen.dart';
// import '../screens/settings/params_screen.dart';

import '../models/order_model.dart';

/// Router de navigation — Faitza COLAS
/// Branch : feature/auth-roles
/// Path : lib/router/app_router.dart
class AppRouter {
  static GoRouter router(AuthProvider auth) => GoRouter(
        initialLocation: '/splash',
        refreshListenable: auth,

        // ── Guard global ──
        redirect: (context, state) {
          final isLoggedIn = auth.isLoggedIn;
          final isSeller = auth.isSeller;
          final path = state.uri.path;

          // Pas connecté → retour auth
          if (!isLoggedIn) {
            if (path.startsWith('/vendor')) return '/role-selection';
            if (path.startsWith('/client')) return '/role-selection';
          }

          // Client essaie pages vendeur → redirigé
          if (isLoggedIn && !isSeller && path.startsWith('/vendor')) {
            return '/client/home';
          }

          // Vendeur essaie pages client → redirigé
          if (isLoggedIn && isSeller && path.startsWith('/client')) {
            return '/vendor/dashboard';
          }

          return null;
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
              final data = state.extra as Map<String, dynamic>?;
              return AuthScreen(role: data?['role'] ?? 'customer');
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

          // ── Vendeur ──
          GoRoute(
            path: '/vendor/dashboard',
            builder: (_, __) => const VendorDashboardScreen(),
          ),
          GoRoute(
            path: '/vendor/products',
            builder: (_, __) => const VendorProductsScreen(),
          ),
          GoRoute(
            path: '/vendor/orders',
            builder: (_, __) => const VendorOrdersScreen(),
          ),
          GoRoute(
            path: '/vendor/order-detail',
            builder: (_, state) {
              final order = state.extra as OrderModel;
              return VendorOrderDetailScreen(order: order);
            },
          ),
          GoRoute(
            path: '/vendor/add-product',
            builder: (_, __) => const VendorAddProductScreen(),
          ),
          GoRoute(
            path: '/vendor/edit-product',
            builder: (_, state) {
              final productId = state.extra as String;
              return VendorEditProductScreen(productId: productId);
            },
          ),
          GoRoute(
            path: '/vendor/stats',
            builder: (_, __) => const VendorStatsScreen(),
          ),

          // ── Client (Claudimyr — décommenter après merge) ──
          // GoRoute(path: '/client/home', builder: ...),
          // GoRoute(path: '/client/boutiques', builder: ...),
          // GoRoute(path: '/client/boutique', builder: ...),
          // GoRoute(path: '/client/product', builder: ...),
          // GoRoute(path: '/cart', builder: ...),
          // GoRoute(path: '/order-form', builder: ...),
          // GoRoute(path: '/order-tracking', builder: ...),
          // GoRoute(path: '/order-history', builder: ...),

          // ── Settings (Falexson — décommenter après merge) ──
          // GoRoute(path: '/settings', builder: ...),
          // GoRoute(path: '/params', builder: ...),
        ],

        errorBuilder: (_, state) => Scaffold(
          body: Center(
            child: Text('Page introuvable : ${state.uri}'),
          ),
        ),
      );
}