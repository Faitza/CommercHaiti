import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'constants/app_colors.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/shop_provider.dart';
import 'providers/order_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/favorite_provider.dart';
import 'router/app_router.dart';

/// Point d'entrée — Falexson MERCIVAL
/// Branch : feature/supabase-core
/// Path : lib/main.dart
// Fonction main() : point de départ de toute l'application Flutter.
// `async` car on doit attendre l'initialisation de Supabase avant de
// lancer l'interface (sinon les appels réseau au backend échoueraient).
void main() async {
  // Garantit que le moteur Flutter (bindings natifs) est prêt avant tout
  // appel asynchrone/plugin natif — requis dès qu'on fait un `await` avant
  // runApp().
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise le client Supabase (backend-as-a-service utilisé pour
  // l'authentification, la base de données et le stockage de fichiers).
  // Les identifiants (URL + clé publique) viennent de SupabaseConfig.
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.publishableKey,
  );

  // Démarre l'application Flutter une fois Supabase prêt.
  runApp(const CommercHaitiApp());
}

// Raccourci global pratique vers le client Supabase, utilisable partout
// dans l'app sans repasser par Supabase.instance.client à chaque fois.
final supabase = Supabase.instance.client;

// Widget racine de l'application. Sa seule responsabilité est de mettre en
// place l'arbre de Providers (gestion d'état globale via le package
// `provider`) avant de construire le vrai MaterialApp (délégué à
// _CommercHaitiMaterialApp ci-dessous).
class CommercHaitiApp extends StatelessWidget {
  const CommercHaitiApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MultiProvider expose tous les ChangeNotifier de l'application à
    // n'importe quel widget descendant (via context.watch/context.read),
    // sans avoir à les passer manuellement de widget en widget.
    return MultiProvider(
      providers: [
        // Authentification : session utilisateur, rôle (client/vendeur),
        // connexion/inscription/déconnexion.
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        // Panier d'achat du client.
        ChangeNotifierProvider(create: (_) => CartProvider()),
        // Liste des boutiques (chargement/écoute temps réel).
        ChangeNotifierProvider(create: (_) => ShopProvider()),
        // Commandes passées par le client / reçues par le vendeur.
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        // Thème clair/sombre de l'application.
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        // Produits mis en favoris par le client.
        ChangeNotifierProvider(create: (_) => FavoriteProvider()),
      ],
      // Le vrai MaterialApp est isolé dans un widget enfant séparé (voir
      // ci-dessous) : c'est indispensable pour la bonne gestion du
      // GoRouter, expliquée juste en dessous.
      child: const _CommercHaitiMaterialApp(),
    );
  }
}

/// Widget séparé — le GoRouter DOIT être créé une seule fois (voir
/// _CommercHaitiMaterialAppState.initState). Le recréer à chaque rebuild
/// (ex. dans un Consumer.builder) réinitialise sa navigation à
/// initialLocation à chaque notifyListeners() d'AuthProvider — c'était la
/// cause du bug "retour à l'accueil" après une action comme créer sa
/// boutique. refreshListenable: auth suffit déjà à faire réagir les guards
/// de redirection sans reconstruire le router.
//
// Explication pédagogique (pourquoi cette architecture existe) :
// Si on créait le GoRouter directement dans la méthode `build()` d'un
// widget (par exemple à l'intérieur d'un Consumer<AuthProvider> qui se
// reconstruit à chaque notifyListeners()), Flutter fabriquerait un TOUT
// NOUVEL objet GoRouter à chaque reconstruction. Or GoRouter garde son
// propre état de navigation interne (pile de routes, position actuelle) ;
// en recréer un nouveau revient à jeter cet état et à repartir de
// `initialLocation`. C'est exactement ce qui provoquait le bug observé :
// après une action qui notifiait les listeners (ex. la création d'une
// boutique appelant `notifyListeners()` dans AuthProvider), l'utilisateur
// se retrouvait renvoyé à l'écran d'accueil au lieu de rester sur l'écran
// suivant attendu.
//
// La solution retenue ici : envelopper le GoRouter dans un StatefulWidget
// et le construire une seule fois via `late final` dans `initState()` (ou
// à l'initialisation du champ, comme ci-dessous). Comme `initState()` n'est
// appelé qu'une seule fois pendant toute la durée de vie du widget, le
// GoRouter n'est jamais recréé — seul son `refreshListenable: auth` est
// utilisé pour re-déclencher la logique de redirection (`redirect:` dans
// AppRouter) sans reconstruire l'objet GoRouter lui-même. C'est le
// mécanisme prévu par go_router pour réagir aux changements d'état
// d'authentification sans perdre la navigation en cours.
class _CommercHaitiMaterialApp extends StatefulWidget {
  const _CommercHaitiMaterialApp();

  @override
  State<_CommercHaitiMaterialApp> createState() =>
      _CommercHaitiMaterialAppState();
}

class _CommercHaitiMaterialAppState extends State<_CommercHaitiMaterialApp> {
  // `late final` : initialisé une seule fois, à la première utilisation du
  // champ (ici dès la construction de l'État, avant le premier build).
  // `context.read<AuthProvider>()` (et non `watch`) car on ne veut PAS
  // reconstruire ce widget quand AuthProvider notifie ses écouteurs — seul
  // le router doit réagir (via refreshListenable), pas ce State lui-même.
  late final _router = AppRouter.router(context.read<AuthProvider>());

  @override
  Widget build(BuildContext context) {
    // Seul ThemeProvider doit déclencher une reconstruction ici (pour
    // appliquer immédiatement le changement de thème clair/sombre) — le
    // Consumer est donc limité à ThemeProvider uniquement, pas à toute
    // l'application.
    return Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          // ✅ MaterialApp.router — obligatwa pou GoRouter mache
          // MaterialApp.router (et non MaterialApp classique) est requis
          // pour déléguer toute la navigation au `routerConfig` fourni par
          // GoRouter.
          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            title: 'CommercHaiti',
            // Bascule automatiquement entre `theme` et `darkTheme` selon
            // la préférence stockée dans ThemeProvider.
            themeMode: themeProvider.themeMode,
            // Thème clair de l'application.
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.navy,
                primary: AppColors.navy,
              ),
              useMaterial3: true,
              fontFamily: 'Roboto',
              appBarTheme: const AppBarTheme(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            // Thème sombre de l'application (mêmes couleurs d'accent,
            // fonds/AppBar adaptés au mode sombre via AppColors.darkNavy).
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.navy,
                brightness: Brightness.dark,
                primary: AppColors.navy,
              ),
              useMaterial3: true,
              fontFamily: 'Roboto',
              appBarTheme: const AppBarTheme(
                backgroundColor: AppColors.darkNavy,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            // ✅ GoRouter injeckte nan tout aplikasyon an — kreye 1 sèl fwa
            // On réutilise ici l'instance unique `_router` créée une seule
            // fois dans le `late final` ci-dessus (voir l'explication
            // détaillée au-dessus de la classe).
            routerConfig: _router,
          );
        });
  }
}
