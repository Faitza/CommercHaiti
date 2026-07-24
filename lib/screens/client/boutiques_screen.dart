import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/shop_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/shop_model.dart';
import '../../widgets/shop_logo_widget.dart';
import '../auth/guest_home_screen.dart';

/// Boutiques Screen — Claudimyr CASSIGNOL
/// Path : lib/screens/client/boutiques_screen.dart
/// Demo : s-boutiques-list → s-boutique-detail → /client/boutique
///
/// Ekran ki montre lis tout boutik (vendors) ki disponib nan app la.
/// Kliyan an ka filtre boutik yo pa zòn, epi klike sou yon boutik pou
/// wè detay li (s-boutique-detail).
///
/// Cet écran affiche la liste de toutes les boutiques (vendeurs)
/// disponibles dans l'application. Le client peut filtrer les boutiques
/// par zone géographique, puis cliquer sur une boutique pour voir ses
/// détails (s-boutique-detail).
class BoutiquesScreen extends StatefulWidget {
  const BoutiquesScreen({super.key});
  @override
  State<BoutiquesScreen> createState() => _BoutiquesScreenState();
}

class _BoutiquesScreenState extends State<BoutiquesScreen> {
  @override
  void initState() {
    super.initState();
    // Dès que l'écran est monté, on demande au ShopProvider de commencer
    // à écouter les boutiques (probablement un flux temps réel / stream
    // Supabase côté provider). Cela permet à la liste de se mettre à jour
    // automatiquement si un vendeur ajoute/modifie/supprime sa boutique
    // pendant que l'écran est ouvert, sans avoir besoin de rafraîchir
    // manuellement.
    context.read<ShopProvider>().listenShops();
  }

  @override
  Widget build(BuildContext context) {
    // context.watch() abonne ce widget aux changements du provider :
    // à chaque notifyListeners() dans ShopProvider, ce build() est
    // ré-exécuté automatiquement pour refléter les nouvelles données.
    final shopProvider = context.watch<ShopProvider>();
    final shops = shopProvider.shops;
    // isGuest = true si l'utilisateur n'est pas connecté (mode invité).
    // Sert à adapter la navigation (retour vers /guest au lieu de
    // /client/home) et à bloquer certaines actions (panier, commandes)
    // pour les invités.
    final isGuest = !context.watch<AuthProvider>().isLoggedIn;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      body: Column(
        children: [
          // TopBar
          // Bandeau bleu en haut de l'écran : bouton retour, titre
          // "Boutiques", bouton filtre (icône tune) et barre de recherche
          // (actuellement affichage statique, sans logique de recherche
          // branchée ici).
          Container(
            color: const Color(0xFF0D2B5E),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              bottom: 12, left: 4, right: 16,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 20),
                      // context.go() REMPLACE toute la pile de navigation
                      // par la route indiquée : l'utilisateur ne pourra
                      // pas revenir en arrière avec le bouton "retour" du
                      // téléphone vers cet écran Boutiques après ce clic.
                      // C'est voulu ici : on retourne à l'accueil (invité
                      // ou client) qui doit devenir le nouveau point de
                      // départ de la pile.
                      onPressed: () =>
                          context.go(isGuest ? '/guest' : '/client/home'),
                    ),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Boutiques',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    // Icône "tune" (filtre) — purement décorative ici,
                    // aucun onTap n'est branché dessus.
                    Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.tune,
                          color: Colors.white, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Barre rechèch
                // Barre de recherche visuelle (créole : "Barre rechèch").
                // Elle est statique : pas de TextField, donc pas encore de
                // recherche fonctionnelle branchée sur cet écran.
                Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(children: const [
                    Icon(Icons.search, color: Colors.white54, size: 16),
                    SizedBox(width: 8),
                    Text('Rechercher une boutique…',
                        style: TextStyle(
                            color: Colors.white54, fontSize: 12)),
                  ]),
                ),
              ],
            ),
          ),

          // Chips filtre zòn
          // Rangée horizontale scrollable de "chips" (pastilles) pour
          // filtrer les boutiques par zone géographique (Cayes Centre,
          // Cayes Nord, etc.). "Tous" réinitialise le filtre.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            child: Row(
              children: ['Tous', 'Cayes Centre', 'Cayes Nord',
                'Cayes Sud', 'Torbeck'].map((zone) {
                // Détermine si ce chip doit apparaître "sélectionné".
                // Pour "Tous" : sélectionné si le nombre de boutiques
                // filtrées égale le nombre total de boutiques (donc
                // aucun filtre de zone actif). Pour les autres zones,
                // "sel" reste toujours false ici (l'état sélectionné
                // visuel des chips de zone n'est pas recalculé après
                // clic — limitation actuelle de l'UI).
                final sel = zone == 'Tous'
                    ? shopProvider.shopsFiltres.length == shops.length
                    : false;
                return GestureDetector(
                  onTap: () {
                    if (zone == 'Tous') {
                      // Retire tout filtre de zone -> affiche toutes
                      // les boutiques.
                      shopProvider.clearFiltre();
                    } else {
                      // Applique un filtre de zone dans le provider ;
                      // shopProvider.shopsFiltres sera recalculé et le
                      // build() se relance via notifyListeners().
                      shopProvider.setFiltreZone(zone);
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: sel
                          ? const Color(0xFF0D2B5E)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sel
                            ? const Color(0xFF0D2B5E)
                            : const Color(0xFFDDDDDD),
                      ),
                    ),
                    child: Text(zone,
                        style: TextStyle(
                            fontSize: 12,
                            color: sel
                                ? Colors.white
                                : const Color(0xFF444444),
                            fontWeight: sel
                                ? FontWeight.bold
                                : FontWeight.normal)),
                  ),
                );
              }).toList(),
            ),
          ),

          // Nimewo boutiques
          // Compteur textuel affichant combien de boutiques correspondent
          // au filtre actuel (créole : "Nimewo boutiques" = "Numéro/
          // Nombre de boutiques").
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Row(children: [
              Text('${shopProvider.shopsFiltres.length} boutique(s) disponible(s)',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF666666))),
            ]),
          ),

          // Liste boutiques
          // Zone principale scrollable : affiche soit un loader pendant
          // le chargement initial, soit un état vide si aucune boutique
          // ne correspond au filtre, soit la liste des boutiques (cartes
          // _ShopCard) dans le cas normal.
          Expanded(
            child: shopProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : shopProvider.shopsFiltres.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.storefront_outlined,
                                size: 56, color: Color(0xFFCCCCCC)),
                            SizedBox(height: 12),
                            Text('Aucune boutique disponible',
                                style: TextStyle(
                                    color: Color(0xFF999999))),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14),
                        itemCount: shopProvider.shopsFiltres.length,
                        itemBuilder: (_, i) {
                          final shop = shopProvider.shopsFiltres[i];
                          return _ShopCard(
                            shop: shop,
                            // context.push() AJOUTE la route détail à la
                            // pile de navigation (contrairement à go()
                            // plus haut) : le bouton retour natif/AppBar
                            // permettra bien de revenir à cette liste de
                            // boutiques. On utilise push() ici car
                            // "Boutique détail" est un écran secondaire
                            // consulté puis quitté, pas un nouveau point
                            // d'ancrage de navigation.
                            // "extra" transmet directement l'objet
                            // ShopModel déjà chargé en mémoire à l'écran
                            // suivant, évitant un rechargement réseau.
                            onTap: () => context.push(
                                '/client/boutique-detail', extra: shop),
                          );
                        },
                      ),
          ),
        ],
      ),

      // Bottom Nav
      // Barre de navigation basse commune (Accueil / Panier / Commandes).
      // Pour un invité (isGuest), Panier et Commandes ouvrent une feuille
      // d'incitation à l'inscription au lieu de naviguer directement,
      // car ces fonctionnalités nécessitent un compte.
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
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
                _NavItem(icon: Icons.home_outlined, label: 'Accueil',
                    // Retour à l'accueil : on utilise go() car l'accueil
                    // doit redevenir la racine de la navigation (pas
                    // d'empilement de pages d'accueil successives).
                    onTap: () =>
                        context.go(isGuest ? '/guest' : '/client/home')),
                _NavItem(icon: Icons.shopping_cart_outlined,
                    label: 'Panier',
                    onTap: () => isGuest
                        ? GuestHomeScreen.showInscriptionSheet(context)
                        : context.go('/cart')),
                _NavItem(icon: Icons.inventory_2_outlined,
                    label: 'Commandes',
                    onTap: () => isGuest
                        ? GuestHomeScreen.showInscriptionSheet(context)
                        : context.go('/order-history')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Carte affichant une boutique dans la liste : logo, nom, zone, note
/// (rating + nombre d'avis), badge Ouvert/Fermé, description tronquée et
/// info de livraison. Purement visuelle (StatelessWidget) : reçoit le
/// modèle "shop" déjà construit et un callback onTap pour la navigation.
class _ShopCard extends StatelessWidget {
  final ShopModel shop;
  final VoidCallback onTap;
  const _ShopCard({required this.shop, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8, offset: const Offset(0, 2),
          )],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Logo de la boutique : si logoUrl est vide/null, le
                // widget affiche probablement les initiales à la place
                // (voir ShopLogoWidget).
                ShopLogoWidget(
                    logoURL: shop.logoUrl,
                    initiales: shop.initiales,
                    size: 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(shop.nom,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      // Zone affichée en dur ("Les Cayes") : ne reflète
                      // pas forcément la vraie zone du modèle shop, à
                      // surveiller si le modèle a un champ zone/ville.
                      Row(children: const [
                        Icon(Icons.location_on,
                            size: 10, color: Color(0xFF888888)),
                        SizedBox(width: 2),
                        Text('Les Cayes',
                            style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF888888))),
                      ]),
                      const SizedBox(height: 2),
                      // Note moyenne (rating) formatée à 1 décimale et
                      // nombre total d'avis.
                      Row(children: [
                        const Icon(Icons.star,
                            size: 11, color: Color(0xFFF5A623)),
                        const SizedBox(width: 2),
                        Text(
                          '${shop.rating.toStringAsFixed(1)} · ${shop.totalAvis} avis',
                          style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFFF5A623)),
                        ),
                      ]),
                    ],
                  ),
                ),
                // Badge Ouvert/Fermé : couleur et texte dépendent de
                // shop.isOpen (probablement calculé côté modèle/provider
                // à partir des horaires de la boutique).
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: shop.isOpen
                        ? const Color(0xFFE8F5EE)
                        : const Color(0xFFFDEAEA),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(shop.isOpen ? 'Ouvert' : 'Fermé',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: shop.isOpen
                              ? const Color(0xFF1D9E75)
                              : const Color(0xFFE63946))),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Description courte de la boutique, limitée à 2 lignes avec
            // "..." si trop longue.
            Text(shop.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF666666),
                    height: 1.5)),
            const SizedBox(height: 6),
            // Information de livraison affichée en dur (texte statique,
            // pas de champ dynamique du modèle shop utilisé ici).
            Row(children: const [
              Icon(Icons.access_time,
                  size: 10, color: Color(0xFF1D9E75)),
              SizedBox(width: 4),
              Text('Livraison 30-45 min · Gratuite',
                  style: TextStyle(
                      fontSize: 10, color: Color(0xFF1D9E75))),
            ]),
          ],
        ),
      ),
    );
  }
}

/// Élément individuel de la barre de navigation basse : une icône +
/// un libellé, avec une couleur qui change selon l'état "active"
/// (actuellement jamais mis à true explicitement dans cet écran, donc
/// visuellement toujours affiché en gris "inactif").
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon, required this.label,
    this.active = false, required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon,
          color: active
              ? const Color(0xFF0D2B5E)
              : const Color(0xFF999999),
          size: 22),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(
          fontSize: 10,
          color: active
              ? const Color(0xFF0D2B5E)
              : const Color(0xFF999999))),
    ]),
  );
}
