import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/shop_provider.dart';
import '../../providers/theme_provider.dart';
import '../../constants/app_colors.dart';
import '../../models/product_model.dart';
import '../../models/shop_model.dart';
import '../../widgets/shop_logo_widget.dart';

/// Accueil Visiteur — Faitza COLAS
/// Branch : feature/auth-roles
/// Path : lib/screens/auth/guest_home_screen.dart
/// Visiteur peut naviguer librement (BF-010) — bottom sheet à panier/commande (BF-011)
// Écran d'accueil pour les visiteurs non connectés (mode "guest"). Permet
// de parcourir les produits et boutiques sans créer de compte (règle
// métier BF-010, voir aussi la liste `guestAllowed` dans
// lib/router/app_router.dart). Dès qu'un visiteur tente une action
// nécessitant un compte (panier, commande, favoris...), on lui affiche une
// invite d'inscription (BF-011) plutôt que de bloquer silencieusement.
class GuestHomeScreen extends StatefulWidget {
  const GuestHomeScreen({super.key});

  /// Affiche bottom sheet d'inscription quand visiteur tente d'acheter
  // Bottom sheet réutilisable (méthode statique) appelée depuis plusieurs
  // endroits de l'écran (icône favori, navigation panier/commande...) dès
  // qu'une action réservée aux comptes enregistrés est déclenchée par un
  // visiteur. Propose de s'inscrire, de se connecter, ou de continuer à
  // naviguer sans compte.
  static void showInscriptionSheet(BuildContext context) {
    // `read` (et non `watch`) : appelé depuis un callback (onTap), pas
    // pendant un build — `watch` lèverait une erreur hors build.
    final isDark = context.read<ThemeProvider>().isDarkMode;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Petite barre grise décorative (indique visuellement que la
            // feuille peut être glissée/fermée).
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.borderColor(isDark),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Créez un compte pour commander',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.accentFor(isDark),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Inscrivez-vous pour passer commande et suivre vos livraisons.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondaryFor(isDark)),
            ),
            const SizedBox(height: 24),
            // Bouton principal : ferme la feuille puis envoie vers le
            // choix de rôle (point d'entrée de l'inscription).
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D2B5E),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  context.go('/role-selection');
                },
                child: const Text('S\'inscrire',
                    style: TextStyle(color: Colors.white, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 12),
            // Bouton secondaire "Se connecter" — mène aussi vers
            // /role-selection (l'écran d'authentification gère ensuite les
            // deux cas via ses onglets Connexion/Inscription).
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.accentFor(isDark)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  context.go('/role-selection');
                },
                child: Text('Se connecter',
                    style: TextStyle(
                        color: AppColors.accentFor(isDark), fontSize: 15)),
              ),
            ),
            const SizedBox(height: 12),
            // Permet simplement de fermer la feuille et de continuer à
            // naviguer en mode visiteur, sans forcer l'inscription.
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Continuer à naviguer',
                style: TextStyle(color: AppColors.textSecondaryFor(isDark)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  State<GuestHomeScreen> createState() => _GuestHomeScreenState();
}

class _GuestHomeScreenState extends State<GuestHomeScreen> {
  // Liste des produits les plus commandés, affichée en scroll horizontal.
  List<ProductModel> _topProduits = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Démarre l'écoute en temps réel des boutiques (stream Supabase géré
    // par ShopProvider) et charge les produits populaires.
    context.read<ShopProvider>().listenShops();
    _chargerProduits();
  }

  // Récupère depuis Supabase les 10 produits disponibles les plus
  // commandés (triés par `total_commandes` décroissant). Utilisé aussi
  // bien au chargement initial que lors du "pull to refresh"
  // (RefreshIndicator plus bas).
  Future<void> _chargerProduits() async {
    try {
      final rows = await Supabase.instance.client
          .from('products')
          .select()
          .eq('disponible', true)
          .order('total_commandes', ascending: false)
          .limit(10);
      if (mounted) {
        setState(() {
          _topProduits = rows.map((r) => ProductModel.fromMap(r, r['id'])).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      // En cas d'erreur réseau/serveur, on arrête simplement le
      // chargement (la liste reste vide) sans bloquer l'écran.
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Liste des boutiques mise à jour en temps réel via ShopProvider.
    final shops = context.watch<ShopProvider>().shops;
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(isDark),
      body: Column(
        children: [
          // TopBar
          // Barre supérieure bleu marine : logo/nom de l'app, indication
          // "Mode visiteur", bouton "Se connecter" et barre de recherche
          // (redirige vers la liste des boutiques).
          Container(
            color: const Color(0xFF0D2B5E),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              bottom: 8, left: 16, right: 16,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE63946),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.shopping_cart,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CommercHaiti',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800)),
                          Row(children: [
                            Icon(Icons.location_on,
                                size: 10, color: Colors.white54),
                            SizedBox(width: 2),
                            Text('Les Cayes · Mode visiteur',
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 10)),
                          ]),
                        ],
                      ),
                    ),
                    // Ces deux actions renvoient toutes les deux vers le
                    // choix de rôle : c'est le point d'entrée commun pour
                    // quitter le mode visiteur et créer/rejoindre un compte.
                    TextButton(
                      onPressed: () => context.go('/role-selection'),
                      child: const Text('Se connecter',
                          style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                    GestureDetector(
                      onTap: () => context.go('/role-selection'),
                      child: Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.menu,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Barre de recherche factice (non interactive elle-même) :
                // au clic, redirige vers l'écran des boutiques où la
                // recherche réelle a lieu. `context.go` remplace la pile
                // (le visiteur peut ensuite revenir en arrière normalement
                // depuis l'écran des boutiques via son propre bouton retour).
                GestureDetector(
                  onTap: () => context.go('/client/boutiques'),
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: const Row(children: [
                      Icon(Icons.search, color: Colors.white54, size: 16),
                      SizedBox(width: 8),
                      Text('Rechercher produits ou boutiques…',
                          style: TextStyle(color: Colors.white54, fontSize: 12)),
                    ]),
                  ),
                ),
              ],
            ),
          ),

          // Contenu principal scrollable, avec "pull to refresh" qui
          // relance le chargement des produits populaires.
          Expanded(
            child: RefreshIndicator(
              onRefresh: _chargerProduits,
              child: SingleChildScrollView(
                // Permet le "pull to refresh" même si le contenu est trop
                // court pour remplir l'écran (scroll toujours activé).
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Bannière bienvenue visiteur
                    // Bandeau incitant à l'inscription, affiché en haut du
                    // contenu.
                    Container(
                      margin: const EdgeInsets.all(14),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D2B5E),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Bienvenue visiteur !',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15)),
                              SizedBox(height: 2),
                              Text('Inscrivez-vous pour commander',
                                  style: TextStyle(
                                      color: Colors.white54, fontSize: 11)),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE63946),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => context.go('/role-selection'),
                          child: const Text('S\'inscrire',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ]),
                    ),

                    // Produits les plus demandés
                    // Section horizontale des produits populaires — "Voir
                    // tout" utilise `context.push` (et non `go`) car on
                    // veut garder l'accueil visiteur dans la pile pour
                    // pouvoir y revenir avec le bouton retour.
                    _sectionTitle('Produits les plus demandés', isDark,
                        onTap: () => context.push('/client/all-products')),
                    SizedBox(
                      height: 180,
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              itemCount: _topProduits.length,
                              itemBuilder: (_, i) => _GuestProduitCard(
                                product: _topProduits[i],
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),

                    // Boutiques ouvertes
                    // Liste verticale des boutiques (imbriquée dans un
                    // SingleChildScrollView : `shrinkWrap` + physics
                    // désactivées car le scroll parent gère déjà le
                    // défilement global).
                    _sectionTitle('Boutiques ouvertes', isDark,
                        onTap: () => context.go('/client/boutiques')),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      itemCount: shops.length,
                      itemBuilder: (_, i) => _GuestBoutiqueCard(shop: shops[i]),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

      // Bottom Navigation — Panier/Commande déclenchent l'inscription (BF-011)
      // Barre de navigation basse : "Accueil" reste sur place (onTap
      // vide), tandis que "Panier" et "Commande" — actions réservées aux
      // comptes — ouvrent la bottom sheet d'inscription au lieu de
      // naviguer réellement.
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface(isDark),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12, offset: const Offset(0, -2),
          )],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(icon: Icons.home, label: 'Accueil', active: true,
                    onTap: () {}),
                _NavItem(icon: Icons.shopping_cart_outlined, label: 'Panier',
                    onTap: () => GuestHomeScreen.showInscriptionSheet(context)),
                _NavItem(icon: Icons.inventory_2_outlined, label: 'Commande',
                    onTap: () => GuestHomeScreen.showInscriptionSheet(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // En-tête de section réutilisable : titre à gauche, lien "Voir tout"
  // optionnel à droite (affiché seulement si `onTap` est fourni).
  Widget _sectionTitle(String t, bool isDark, {VoidCallback? onTap}) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(t, style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.bold,
            color: AppColors.textPrimaryFor(isDark))),
        if (onTap != null)
          GestureDetector(
            onTap: onTap,
            child: Text('Voir tout',
                style: TextStyle(fontSize: 12, color: AppColors.accentFor(isDark))),
          ),
      ],
    ),
  );
}

// Carte produit affichée dans la liste horizontale "Produits les plus
// demandés". Au clic, ouvre le détail du produit (context.push : garde la
// pile pour pouvoir revenir en arrière). L'icône cœur (favoris) déclenche
// directement l'invite d'inscription puisqu'un visiteur ne peut pas avoir
// de favoris.
class _GuestProduitCard extends StatelessWidget {
  final ProductModel product;
  const _GuestProduitCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    return GestureDetector(
      onTap: () => context.push('/client/product', extra: product),
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: AppColors.surface(isDark),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6, offset: const Offset(0, 2),
          )],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                // Image du produit (ou icône de remplacement si absente).
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: SizedBox(
                    height: 100, width: double.infinity,
                    child: product.vignette != null
                        ? Image.network(product.vignette!, fit: BoxFit.cover)
                        : Container(
                            color: const Color(0xFFEEF3FB),
                            child: const Icon(Icons.image_outlined,
                                color: Color(0xFF0D2B5E), size: 36)),
                  ),
                ),
                // Icône favori (cœur) : pour un visiteur, tout clic ouvre
                // directement l'invite d'inscription (BF-011).
                Positioned(
                  top: 4, right: 4,
                  child: GestureDetector(
                    onTap: () => GuestHomeScreen.showInscriptionSheet(context),
                    child: Container(
                      width: 26, height: 26,
                      decoration: const BoxDecoration(
                          color: Colors.white70, shape: BoxShape.circle),
                      child: Icon(Icons.favorite_border,
                          size: 14, color: AppColors.textSecondaryFor(isDark)),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.nom, maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text('${product.prixAffiche.toStringAsFixed(0)} HTG',
                      style: TextStyle(
                          color: AppColors.accentFor(isDark),
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Carte boutique affichée dans la liste "Boutiques ouvertes". Au clic,
// ouvre le détail de la boutique. Affiche aussi un badge Ouvert/Fermé
// selon `shop.isOpen`.
class _GuestBoutiqueCard extends StatelessWidget {
  final ShopModel shop;
  const _GuestBoutiqueCard({required this.shop});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    return GestureDetector(
      onTap: () => context.push('/client/boutique-detail', extra: shop),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface(isDark),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6, offset: const Offset(0, 2),
          )],
        ),
        child: Row(
          children: [
            // Logo de la boutique (ou initiales si le logo est absent —
            // voir ShopLogoWidget).
            ShopLogoWidget(
                logoURL: shop.logoUrl, initiales: shop.initiales, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(shop.nom, style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.star_rounded, size: 11, color: Color(0xFFF5A623)),
                    const SizedBox(width: 2),
                    Text('${shop.rating.toStringAsFixed(1)} · ${shop.totalAvis} avis',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondaryFor(isDark))),
                  ]),
                ],
              ),
            ),
            // Badge Ouvert (vert) / Fermé (rouge) selon l'état de la boutique.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: shop.isOpen
                    ? const Color(0xFFE8F5EE)
                    : const Color(0xFFFDEAEA),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(shop.isOpen ? 'Ouvert' : 'Fermé',
                  style: TextStyle(
                      color: shop.isOpen
                          ? const Color(0xFF1D9E75)
                          : const Color(0xFFE63946),
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// Élément de la barre de navigation basse (icône + libellé). `active`
// détermine la couleur (bleu marine si actif, gris sinon).
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    this.active = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              color: active
                  ? AppColors.accentFor(isDark)
                  : AppColors.textSecondaryFor(isDark),
              size: 22),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: active
                      ? AppColors.accentFor(isDark)
                      : AppColors.textSecondaryFor(isDark),
                  fontWeight: active
                      ? FontWeight.bold
                      : FontWeight.normal)),
        ],
      ),
    );
  }
}
