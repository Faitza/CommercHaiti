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

// Client screens
import '../screens/client/client_home_screen.dart';
import '../screens/client/boutiques_screen.dart';
import '../screens/client/boutique_detail_screen.dart';
import '../screens/client/subcategory_screen.dart';
import '../screens/client/product_detail_screen.dart';
import '../screens/client/product_shops_screen.dart';

// Orders screens
import '../screens/orders/cart_screen.dart';
import '../screens/orders/order_form_screen.dart';
import '../screens/orders/order_tracking_screen.dart';
import '../screens/orders/order_history_screen.dart';

// Settings screens
import '../screens/settings/settings_screen.dart';
import '../screens/settings/params_screen.dart';

import '../models/shop_model.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';

/// Router de navigation — Faitza COLAS
/// Branch : feature/auth-roles
/// Path : lib/router/app_router.dart
class AppRouter {
  static GoRouter router(AuthProvider auth) => GoRouter(
        initialLocation: '/splash',
        refreshListenable: auth,

        redirect: (context, state) {
          final isLoggedIn = auth.isLoggedIn;
          final isSeller = auth.isSeller;
          final path = state.uri.path;

          // Pa konekte → pa ka al sou pages proteje yo
          if (!isLoggedIn) {
            if (path.startsWith('/vendor')) return '/role-selection';
            if (path.startsWith('/client')) return '/role-selection';
            if (path.startsWith('/cart')) return '/role-selection';
            if (path.startsWith('/order')) return '/role-selection';
          }

          // Client → pa ka al sou pages vendeur
          if (isLoggedIn && !isSeller && path.startsWith('/vendor')) {
            return '/client/home';
          }

          // Vendeur → pa ka al sou pages client
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

          // ── Client ──
          GoRoute(
            path: '/client/home',
            builder: (_, __) => const ClientHomeScreen(),
          ),
          GoRoute(
            path: '/client/boutiques',
            builder: (_, __) => const BoutiquesScreen(),
          ),
          GoRoute(
            path: '/client/boutique',
            builder: (_, state) {
              final shop = state.extra as ShopModel;
              return BoutiqueDetailScreen(shop: shop);
            },
          ),
          GoRoute(
            path: '/client/subcategory',
            builder: (_, state) {
              final data = state.extra as Map<String, dynamic>;
              return SubcategoryScreen(
                shopId: data['shopId'],
                categorie: data['categorie'],
              );
            },
          ),
          GoRoute(
            path: '/client/product',
            builder: (_, state) {
              final product = state.extra as ProductModel;
              return ProductDetailScreen(product: product);
            },
          ),
          GoRoute(
            path: '/client/product-shops',
            builder: (_, state) {
              final nom = state.extra as String;
              return ProductShopsScreen(productNom: nom);
            },
          ),

          // ── Commandes ──
          GoRoute(
            path: '/cart',
            builder: (_, __) => const CartScreen(),
          ),
          GoRoute(
            path: '/order-form',
            builder: (_, __) => const OrderFormScreen(),
          ),
          GoRoute(
            path: '/order-tracking',
            builder: (_, state) {
              final data = state.extra as Map<String, dynamic>;
              return OrderTrackingScreen(
                orderId: data['orderId'],
                vendeurTelephone: data['vendeurTelephone'] ?? '',
              );
            },
          ),
          GoRoute(
            path: '/order-history',
            builder: (_, __) => const OrderHistoryScreen(),
          ),

          // ── Settings ──
          GoRoute(
            path: '/settings',
            builder: (_, __) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/params',
            builder: (_, __) => const ParamsScreen(),
          ),
        ],

        errorBuilder: (_, state) => const Scaffold(
          body: Center(child: Text('Page introuvable')),
        ),
      );
}