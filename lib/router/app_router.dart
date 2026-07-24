import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
import '../screens/vendor/vendor_reviews_screen.dart';
import '../screens/vendor/vendor_edit_shop_screen.dart';

// Client screens
import '../screens/client/client_home_screen.dart';
import '../screens/client/boutiques_screen.dart';
import '../screens/client/boutique_detail_screen.dart';
import '../screens/client/subcategory_screen.dart';
import '../screens/client/product_detail_screen.dart';
import '../screens/client/product_shops_screen.dart';
import '../screens/client/favorites_screen.dart';
import '../screens/client/edit_profile_screen.dart';
import '../screens/client/all_products_screen.dart';

// Orders screens
import '../screens/orders/cart_screen.dart';
import '../screens/orders/order_form_screen.dart';
import '../screens/orders/order_tracking_screen.dart';
import '../screens/orders/order_history_screen.dart';

// Settings screens
import '../screens/settings/settings_screen.dart';
import '../screens/settings/params_screen.dart';

import '../models/order_model.dart';
import '../models/shop_model.dart';
import '../models/product_model.dart';

/// Router de navigation — Faitza COLAS
/// Branch : feature/auth-roles
/// Path : lib/router/app_router.dart
///
/// CHEMEN YO (routes) :
/// /splash          → SplashScreen
/// /onboarding      → OnboardingScreen (3 slides)
/// /role-selection  → RoleSelectionScreen (Vendeur/Client)
/// /auth            → AuthScreen (Connexion/Inscription)
/// /guest           → GuestHomeScreen (mode visiteur)
/// /create-shop     → CreateShopScreen (après inscription vendeur)
/// /vendor/dashboard    → VendorDashboardScreen
/// /vendor/products     → VendorProductsScreen
/// /vendor/orders       → VendorOrdersScreen
/// /vendor/order-detail → VendorOrderDetailScreen
/// /vendor/add-product  → VendorAddProductScreen
/// /vendor/edit-product → VendorEditProductScreen
/// /vendor/stats        → VendorStatsScreen
/// /client/home         → ClientHomeScreen
/// /client/boutiques    → BoutiquesScreen
/// /client/boutique     → BoutiqueDetailScreen
/// /client/subcategory  → SubcategoryScreen
/// /client/product      → ProductDetailScreen
/// /client/product-shops→ ProductShopsScreen
/// /cart                → CartScreen
/// /order-form          → OrderFormScreen
/// /order-tracking      → OrderTrackingScreen
/// /order-history       → OrderHistoryScreen
/// /settings            → SettingsScreen (vendeur)
/// /params              → ParamsScreen (client)

// Cette classe centralise TOUTE la configuration de navigation de
// l'application : la table des routes (quel widget afficher pour quel
// chemin), ainsi que la logique de garde/redirection (qui a le droit
// d'accéder à quoi selon son état de connexion et son rôle).
//
// Rappel important sur go_router :
//  - `context.go(path)` REMPLACE toute la pile de navigation par ce
//    chemin : l'utilisateur ne peut plus revenir en arrière avec le
//    bouton retour vers l'écran précédent. On l'utilise pour les
//    transitions "définitives" (ex: après connexion, changer de rôle,
//    etc.) où revenir en arrière n'aurait pas de sens.
//  - `context.push(path)` AJOUTE ce chemin par-dessus la pile actuelle :
//    le bouton retour fonctionne et ramène à l'écran précédent. On
//    l'utilise pour les écrans "de détail" ouverts depuis une liste (ex:
//    détail d'un produit, "voir tout" les produits) où l'on veut pouvoir
//    revenir en arrière.
class AppRouter {
  // Construit et retourne l'instance GoRouter de l'application.
  // Reçoit `auth` (AuthProvider) afin de :
  //   1) lire l'état de connexion/rôle dans la fonction `redirect`,
  //   2) s'abonner à ses changements via `refreshListenable: auth` pour
  //      relancer automatiquement la logique de redirection dès que
  //      l'utilisateur se connecte/déconnecte, sans jamais recréer
  //      l'objet GoRouter lui-même (voir lib/main.dart pour l'explication
  //      complète de pourquoi c'est important).
  static GoRouter router(AuthProvider auth) => GoRouter(
        // Premier écran affiché au démarrage de l'app.
        initialLocation: '/splash',
        // Fait réévaluer `redirect` à chaque fois qu'AuthProvider appelle
        // notifyListeners() (connexion, déconnexion, changement de rôle,
        // etc.), sans recréer le GoRouter.
        refreshListenable: auth,

        // Fonction de garde exécutée avant chaque navigation. Retourne soit
        // `null` (laisser la navigation continuer normalement), soit un
        // chemin vers lequel rediriger à la place.
        redirect: (context, state) {
          final isLoggedIn = auth.isLoggedIn;
          final isSeller = auth.isSeller;
          final path = state.uri.path;

          // Pa konekte → pa ka al sou pages proteje
          // Eksepsyon (BF-010) : vizitè ka navige librem an nan boutik/kategori/pwodui
          // san kont, men pa ka rive nan panyen/komann/kreye-boutik/accueil pèsonalize.
          // (Traduction : Non connecté → ne peut pas accéder aux pages
          // protégées. Exception (BF-010) : le visiteur peut naviguer
          // librement parmi boutiques/catégories/produits sans compte,
          // mais ne peut pas accéder au panier/commandes/création de
          // boutique/accueil personnalisé.)
          if (!isLoggedIn) {
            // BF-010 : liste blanche des écrans "client" consultables sans
            // être connecté (mode visiteur). Tout chemin commençant par
            // l'un de ces préfixes est autorisé même sans session active.
            const guestAllowed = [
              '/client/boutiques',
              '/client/boutique-detail',
              '/client/subcategory',
              '/client/product',
              '/client/product-shops',
              '/client/all-products',
            ];
            final isGuestAllowed =
                guestAllowed.any((p) => path.startsWith(p));

            // Aucune page vendeur n'est accessible sans être connecté.
            if (path.startsWith('/vendor')) return '/role-selection';
            // Pages client protégées SAUF celles listées dans guestAllowed
            // (ex: /client/home reste protégé — c'est l'accueil
            // personnalisé du client connecté, différent de /guest qui
            // est l'accueil visiteur).
            if (path.startsWith('/client') && !isGuestAllowed) {
              return '/role-selection';
            }
            // Écrans nécessitant obligatoirement un compte (panier,
            // commande, suivi, historique, création de boutique,
            // paramètres) : toujours redirigés vers le choix de rôle si
            // non connecté, même s'ils ne commencent pas par /client ou
            // /vendor.
            if (path == '/cart') return '/role-selection';
            if (path == '/order-form') return '/role-selection';
            if (path == '/order-tracking') return '/role-selection';
            if (path == '/order-history') return '/role-selection';
            if (path == '/create-shop') return '/role-selection';
            if (path == '/settings') return '/role-selection';
            if (path == '/params') return '/role-selection';
          }

          // Client → pa ka al sou pages vendeur
          // Un client connecté ne doit jamais pouvoir accéder aux écrans
          // réservés aux vendeurs → redirection vers son accueil client.
          if (isLoggedIn && !isSeller && path.startsWith('/vendor')) {
            return '/client/home';
          }

          // Vendeur → pa ka al sou pages client
          // Symétriquement, un vendeur connecté ne doit jamais accéder aux
          // écrans réservés aux clients → redirection vers son tableau de
          // bord.
          if (isLoggedIn && isSeller && path.startsWith('/client')) {
            return '/vendor/dashboard';
          }

          // Paramètres — chak rôle gen so pwòp ekran
          // (Traduction : Paramètres — chaque rôle a son propre écran.)
          // /settings est réservé au vendeur, /params au client : si l'un
          // essaie d'accéder à l'écran de l'autre, on le redirige vers le
          // sien.
          if (isLoggedIn && isSeller && path == '/params') return '/settings';
          if (isLoggedIn && !isSeller && path == '/settings') return '/params';

          // Aucune règle de redirection ne s'applique : on laisse la
          // navigation continuer normalement vers la route demandée.
          return null;
        },

        routes: [
          // ══════════════════════════════
          // AUTH
          // ══════════════════════════════
          // Routes du parcours d'authentification : démarrage (splash),
          // introduction (onboarding), choix du rôle, connexion/inscription,
          // mode visiteur, et création de boutique pour un nouveau vendeur.
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
            // `state.extra` transporte le rôle choisi (Map contenant
            // 'role') depuis l'écran précédent ; si absent, on part par
            // défaut sur 'customer' (client).
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
            // Reçoit le code boutique généré lors de l'inscription
            // vendeur ; une valeur par défaut est fournie si l'écran est
            // atteint sans passer par le flux normal.
            builder: (_, state) {
              final data = state.extra as Map<String, dynamic>?;
              return CreateShopScreen(
                shopCode: data?['shopCode'] ?? 'MFL-2026-0000',
              );
            },
          ),

          // ══════════════════════════════
          // VENDEUR
          // ══════════════════════════════
          // Écrans réservés aux comptes vendeur : tableau de bord,
          // gestion des produits/commandes, statistiques, avis clients et
          // édition de la boutique. Protégés par la logique `redirect`
          // ci-dessus (accès refusé aux non-connectés et aux clients).
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
            // Reçoit directement l'objet OrderModel complet via `extra`
            // (évite un rechargement réseau du détail de la commande).
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
            // Reçoit seulement l'ID du produit (String) : l'écran
            // d'édition se charge lui-même de récupérer les données
            // complètes du produit à modifier.
            builder: (_, state) {
              final productId = state.extra as String;
              return VendorEditProductScreen(productId: productId);
            },
          ),
          GoRoute(
            path: '/vendor/stats',
            builder: (_, __) => const VendorStatsScreen(),
          ),
          GoRoute(
            path: '/vendor/reviews',
            builder: (_, __) => const VendorReviewsScreen(),
          ),
          GoRoute(
            path: '/vendor/edit-shop',
            builder: (_, __) => const VendorEditShopScreen(),
          ),

          // ══════════════════════════════
          // CLIENT
          // ══════════════════════════════
          // Écrans du parcours client : accueil personnalisé, liste des
          // boutiques, détail boutique/sous-catégorie/produit, favoris,
          // liste complète des produits, édition du profil. Certains de
          // ces chemins sont accessibles en mode visiteur (voir
          // `guestAllowed` plus haut) ; /client/home, /client/favorites et
          // /client/edit-profile restent réservés aux clients connectés.
          GoRoute(
            path: '/client/home',
            builder: (_, __) => const ClientHomeScreen(),
          ),
          GoRoute(
            path: '/client/boutiques',
            builder: (_, __) => const BoutiquesScreen(),
          ),
          GoRoute(
            path: '/client/boutique-detail',
            // Reçoit directement l'objet ShopModel via `extra`.
            builder: (_, state) {
              final shop = state.extra as ShopModel;
              return BoutiqueDetailScreen(shop: shop);
            },
          ),
          GoRoute(
            path: '/client/favorites',
            builder: (_, __) => const FavoritesScreen(),
          ),
          GoRoute(
            path: '/client/all-products',
            builder: (_, __) => const AllProductsScreen(),
          ),
          GoRoute(
            path: '/client/edit-profile',
            builder: (_, __) => const EditProfileScreen(),
          ),
          GoRoute(
            path: '/client/subcategory',
            // `extra` est une Map contenant l'ID de la boutique et la
            // catégorie sélectionnée, pour filtrer les produits affichés.
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
            // Reçoit directement l'objet ProductModel via `extra`.
            builder: (_, state) {
              final product = state.extra as ProductModel;
              return ProductDetailScreen(product: product);
            },
          ),
          GoRoute(
            path: '/client/product-shops',
            // Reçoit le nom du produit (String) pour lister toutes les
            // boutiques qui le proposent.
            builder: (_, state) {
              final nom = state.extra as String;
              return ProductShopsScreen(productNom: nom);
            },
          ),

          // ══════════════════════════════
          // COMMANDES
          // ══════════════════════════════
          // Parcours de commande côté client : panier, formulaire de
          // commande, suivi en temps réel, historique. Tous protégés
          // (nécessitent un compte connecté — voir `redirect`).
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
            // `extra` est une Map contenant l'ID de la commande et le
            // téléphone du vendeur (pour le contact rapide, ex. WhatsApp).
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

          // ══════════════════════════════
          // SETTINGS
          // ══════════════════════════════
          // Écrans de paramètres : un par rôle (vendeur → /settings,
          // client → /params), voir la règle de redirection dédiée
          // ci-dessus qui empêche l'accès à l'écran de l'autre rôle.
          GoRoute(
            path: '/settings',
            builder: (_, __) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/params',
            builder: (_, __) => const ParamsScreen(),
          ),
        ],

        // Écran affiché lorsqu'aucune route ne correspond au chemin
        // demandé (ex: faute de frappe dans une navigation, route
        // supprimée, etc.).
        errorBuilder: (_, state) => const Scaffold(
          body: Center(child: Text('Page introuvable')),
        ),
      );
}
