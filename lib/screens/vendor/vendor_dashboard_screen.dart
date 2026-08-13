import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../services/database_service.dart';
import '../../models/product_model.dart';
import '../../models/order_model.dart';
import '../../models/shop_model.dart';
import '../../widgets/shop_logo_widget.dart';
import '../../widgets/app_drawer_widget.dart';
import '../../providers/theme_provider.dart';
import '../../constants/app_colors.dart';

/// Vendor Dashboard Screen — Faitza COLAS
/// Path : lib/screens/vendor/vendor_dashboard_screen.dart
///
/// Ecran d'accueil du vendeur après connexion : chiffre d'affaires
/// (aujourd'hui / mois — BF-031), commandes en attente d'acceptation,
/// alertes de stock bas (≤ 5 unités — BF-033), Top 5 des produits les
/// plus vendus et Flop 5 des produits à promouvoir (BF-032), ainsi qu'une
/// barre de navigation basse vers les autres écrans vendeur (produits,
/// commandes). Les commandes sont reçues en temps réel via un stream
/// Supabase (voir OrderProvider.listenVendorOrders), tandis que les
/// statistiques agrégées (stock bas, Top5/Flop5) sont chargées
/// ponctuellement (pas de stream) et peuvent être rafraîchies en tirant
/// vers le bas (RefreshIndicator).
class VendorDashboardScreen extends StatefulWidget {
  const VendorDashboardScreen({super.key});
  @override
  State<VendorDashboardScreen> createState() => _VendorDashboardScreenState();
}

class _VendorDashboardScreenState extends State<VendorDashboardScreen> {
  // Service centralisant les requêtes/agrégations Supabase (produits,
  // boutique). Voir lib/services/database_service.dart.
  final _db = DatabaseService();
  // Clé permettant d'ouvrir/fermer le drawer (menu latéral) du Scaffold
  // par code, via `_scaffoldKey.currentState?.openEndDrawer()`.
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  // Produits dont le stock est ≤ 5 unités (BF-033 — alerte stock bas).
  List<ProductModel> _stockBas = [];
  // Les 5 produits les plus commandés de la boutique (BF-031).
  List<ProductModel> _top5 = [];
  // Les 5 produits les moins commandés — candidats à une promotion
  // (BF-032).
  List<ProductModel> _flop5 = [];
  // Infos de la boutique du vendeur (nom, logo, statut ouvert/fermé),
  // chargées séparément des statistiques produits.
  ShopModel? _shop;

  @override
  void initState() {
    super.initState();
    // Chargement initial des statistiques (stock bas, Top5/Flop5) et des
    // infos de la boutique dès l'ouverture de l'écran.
    _loadStats();
    _loadShop();
    final auth = context.read<AuthProvider>();
    if (auth.currentUser != null) {
      // Démarre l'écoute temps réel (stream Supabase Realtime) des
      // commandes de ce vendeur : toute nouvelle commande ou changement de
      // statut met à jour automatiquement les sections "En attente" et le
      // badge de notification, sans rechargement manuel.
      context.read<OrderProvider>().listenVendorOrders(auth.currentUser!.id);
    }
  }

  /// Charge les informations de la boutique (nom, logo, statut
  /// ouvert/fermé) via une requête Supabase ponctuelle sur la table
  /// `shops`, ciblée sur l'UUID réel de la boutique (`shopId`).
  Future<void> _loadShop() async {
    // IMPORTANT : `auth.shopId` est l'UUID réel de la boutique (résolu via
    // `shops.proprietaire_id`), à utiliser pour toute requête Supabase —
    // ne jamais confondre avec `shopCode` (ex. "MFL-2026-4892"), qui n'est
    // qu'un code d'affichage lisible par l'utilisateur, pas un identifiant
    // de base de données. Cette confusion a été la source de bugs réels
    // plus tôt dans le projet.
    final shopId = context.read<AuthProvider>().shopId;
    if (shopId == null) return;
    final shop = await _db.getShop(shopId);
    if (mounted) setState(() => _shop = shop);
  }

  /// Recharge les trois listes de statistiques (stock bas, Top5, Flop5)
  /// depuis Supabase via DatabaseService. Utilisée à la fois à
  /// l'ouverture de l'écran et lors d'un "pull to refresh"
  /// (RefreshIndicator plus bas dans `build`).
  Future<void> _loadStats() async {
    final auth = context.read<AuthProvider>();
    if (auth.currentUser == null || auth.shopId == null) return;
    // Encore une fois : on utilise l'UUID réel `shopId`, jamais le
    // `shopCode` d'affichage, pour filtrer les requêtes Supabase.
    final shopId = auth.shopId!;
    // Produits en stock bas (seuil ≤ 5, BF-033).
    final stockBas = await _db.getLowStockProducts(shopId);
    // Top 5 : produits les plus commandés, limité à 5 résultats (BF-031).
    final top5 = await _db.getTopProductsForShop(shopId, limit: 5);
    // Flop 5 : produits les moins commandés, à promouvoir (BF-032).
    final flop5 = await _db.getFlop5Products(shopId);
    if (mounted) setState(() {
      _stockBas = stockBas;
      _top5 = top5;
      _flop5 = flop5;
    });
  }

  @override
  Widget build(BuildContext context) {
    // `watch` reconstruit ce widget à chaque changement d'AuthProvider
    // (ex : résolution du shopId) ou d'OrderProvider (ex : nouvelle
    // commande reçue via le stream temps réel).
    final auth = context.watch<AuthProvider>();
    final orders = context.watch<OrderProvider>();
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.scaffoldBg(isDark),
      // Menu latéral (drawer) ouvert via l'icône "menu" du header — noter
      // que `headerSubtitle` affiche volontairement le `shopCode` humain
      // (ex. "MFL-2026-4892") car c'est un affichage destiné à
      // l'utilisateur, pas une requête base de données ; les requêtes
      // Supabase, elles, doivent toujours utiliser `auth.shopId` (UUID).
      endDrawer: AppDrawerWidget(
        headerTitle: _shop?.nom ?? 'Ma Boutique',
        headerSubtitle: auth.currentUser?.shopCode ?? '',
        settingsRoute: '/settings',
        items: [
          DrawerMenuItem(Icons.inventory_2_outlined, 'Mes produits',
              onTap: () {
            Navigator.pop(context);
            context.push('/vendor/products');
          }),
          DrawerMenuItem(Icons.bar_chart_outlined, 'Stats', onTap: () {
            Navigator.pop(context);
            context.push('/vendor/stats');
          }),
          const DrawerMenuItem(Icons.local_offer_outlined, 'Promotions'),
          DrawerMenuItem(Icons.star_border, 'Avis', onTap: () {
            Navigator.pop(context);
            context.push('/vendor/reviews');
          }),
        ],
      ),
      body: Column(
        children: [
          // TopBar fonce (bandeau bleu marine en haut de l'écran) : contient
          // DEUX rangées — l'info boutique, PUIS les cartes CA — toutes les
          // deux peintes sur le même fond bleu marine, jan maket la montre.
          Container(
            color: const Color(0xFF061A3A),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              bottom: 16, left: 16, right: 16,
            ),
            child: Column(
              // min : sans ça, ce Column (dans un Container à hauteur non
              // bornée) essaierait de remplir une hauteur infinie — c'est
              // ce qui causait le crash "Cannot hit test a render box that
              // has never been laid out" la première fois.
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    // Logo de la boutique (ou initiales générées à partir du
                    // shopCode si aucun logo n'a été téléversé).
                    ShopLogoWidget(
                      logoURL: _shop?.logoUrl,
                      initiales: _shop?.initiales ??
                          auth.currentUser?.shopCode?.substring(0, 2) ?? 'CH',
                      size: 36,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_shop?.nom ?? 'Ma Boutique',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700)),
                          Row(children: [
                            Icon(Icons.circle, size: 7,
                                color: (_shop?.isOpen ?? true)
                                    ? const Color(0xFF1D9E75)
                                    : const Color(0xFFE63946)),
                            const SizedBox(width: 4),
                            Text((_shop?.isOpen ?? true)
                                    ? 'Boutique ouverte' : 'Boutique fermée',
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 9)),
                          ]),
                        ],
                      ),
                    ),
                    // Icône cloche de notification : englobée dans un
                    // GestureDetector qui navigue directement vers l'écran des
                    // commandes (`/vendor/orders`) au tap, pour permettre au
                    // vendeur d'accéder rapidement à ses commandes en attente
                    // (BF-031, réactivité vendeur). Un badge rouge avec le
                    // nombre de commandes en attente est superposé (Stack +
                    // Positioned) tant que `orders.enAttente` n'est pas vide.
                    GestureDetector(
                      onTap: () => context.push('/vendor/orders'),
                      child: Stack(
                        children: [
                          Container(
                            width: 34, height: 34,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.notifications_outlined,
                                color: Colors.white, size: 18),
                          ),
                          // Badge numéroté affiché seulement s'il y a au moins
                          // une commande en attente de traitement.
                          if (orders.enAttente.isNotEmpty)
                            Positioned(
                              top: 4, right: 4,
                              child: Container(
                                width: 14, height: 14,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE63946),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text('${orders.enAttente.length}',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Bouton menu (icône hamburger) : ouvre le drawer latéral
                    // (endDrawer défini plus haut) via la `_scaffoldKey`.
                    GestureDetector(
                      onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
                      child: Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.menu,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // Cartes chiffre d'affaires (CA) — BF-031 : les montants ne
                // viennent pas d'une requête d'agrégation SQL côté serveur,
                // mais sont recalculés côté client (Dart) à partir de la liste
                // complète des commandes du vendeur déjà en mémoire
                // (`orders.ordresVendeur`, reçue via le stream temps réel).
                // Voir `_calculerCA` plus bas.
                Row(children: [
                  _caCard('CA Aujourd\'hui',
                      '${_calculerCA(orders.ordresVendeur, jours: 1).toStringAsFixed(0)} HTG'),
                  const SizedBox(width: 10),
                  _caCardEnAttente(orders.enAttente.length),
                  const SizedBox(width: 10),
                  _caCard('Ce mois',
                      _formatCourt(_calculerCA(orders.ordresVendeur, jours: 30))),
                ]),
              ],
            ),
          ),

          // Contenu principal (scrollable) du tableau de bord : section
          // commandes en attente, alertes stock, Top5/Flop5.
          Expanded(
            child: RefreshIndicator(
              // Tirer vers le bas relance `_loadStats` pour rafraîchir
              // manuellement stock bas / Top5 / Flop5 (les commandes,
              // elles, sont déjà à jour en temps réel via le stream).
              onRefresh: _loadStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section "Commandes en attente" : liste des commandes
                    // dont le vendeur doit encore accepter ou refuser la
                    // demande. Le badge affiche leur nombre.
                    _sectionTitle(
                      'En attente du vendeur',
                      badge: orders.enAttente.length,
                    ),
                    orders.enAttente.isEmpty
                        ? _emptyCard('Aucune commande en attente')
                        // Une carte par commande en attente, construite
                        // directement depuis la liste `orders.enAttente`
                        // (déjà filtrée par OrderProvider).
                        : Column(
                            children: orders.enAttente.map((o) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Zone cliquable (numéro de commande,
                                  // téléphone, adresse, articles) qui ouvre
                                  // l'écran de détail complet de la
                                  // commande en lui transmettant l'objet
                                  // `o` déjà chargé (pas de requête
                                  // supplémentaire).
                                  GestureDetector(
                                    onTap: () => context.push(
                                        '/vendor/order-detail', extra: o),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            'Commande #${o.id.substring(0, 6).toUpperCase()}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13)),
                                        const SizedBox(height: 4),
                                        Row(children: [
                                          const Icon(Icons.phone_iphone,
                                              size: 12, color: Color(0xFF666666)),
                                          const SizedBox(width: 4),
                                          Text(o.telephoneClient,
                                              style: const TextStyle(
                                                  color: Color(0xFF666666),
                                                  fontSize: 11)),
                                        ]),
                                        const SizedBox(height: 2),
                                        Row(children: [
                                          const Icon(Icons.location_on_outlined,
                                              size: 12, color: Color(0xFF666666)),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                                '${o.adresseLivraison}, ${o.zone}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    color: Color(0xFF666666),
                                                    fontSize: 11)),
                                          ),
                                        ]),
                                        const SizedBox(height: 4),
                                        Text(
                                            '${o.items.map((i) => "${i.nom} ×${i.quantite}").join(" · ")} · ${o.total.toStringAsFixed(0)} HTG',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  // Deux boutons d'action rapide,
                                  // directement depuis le tableau de bord
                                  // (sans passer par l'écran de détail) :
                                  // "Accepter" change le statut en
                                  // 'acceptee', "Refuser" en 'annulee'. Les
                                  // deux appellent
                                  // `OrderProvider.updateStatut`, qui fait
                                  // un UPDATE Supabase sur la colonne
                                  // `statut` de la table `orders` — la
                                  // commande disparaîtra automatiquement de
                                  // cette section "en attente" dès que le
                                  // stream renverra la mise à jour.
                                  Row(children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(
                                              color: Color(0xFF1D9E75)),
                                          backgroundColor:
                                              const Color(0xFFE8F5EE),
                                        ),
                                        onPressed: () => context
                                            .read<OrderProvider>()
                                            .updateStatut(o.id, 'acceptee'),
                                        icon: const Icon(Icons.check,
                                            size: 16, color: Color(0xFF1D9E75)),
                                        label: const Text('Accepter',
                                            style: TextStyle(
                                                color: Color(0xFF1D9E75),
                                                fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(
                                              color: Color(0xFFE63946)),
                                          backgroundColor:
                                              const Color(0xFFFDEAEA),
                                        ),
                                        onPressed: () => context
                                            .read<OrderProvider>()
                                            .updateStatut(o.id, 'annulee'),
                                        icon: const Icon(Icons.close,
                                            size: 16, color: Color(0xFFE63946)),
                                        label: const Text('Refuser',
                                            style: TextStyle(
                                                color: Color(0xFFE63946),
                                                fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  ]),
                                ],
                              ),
                            )).toList(),
                          ),
                    const SizedBox(height: 18),

                    // Section "Alertes stock bas" (BF-033) : produits dont
                    // le stock est descendu à 5 unités ou moins,
                    // pré-chargés dans `_stockBas` par `_loadStats`.
                    _sectionTitle('Alertes stock ≤ 5',
                        badge: _stockBas.length),
                    _stockBas.isEmpty
                        ? _emptyCard('Tous les stocks sont OK')
                        : Column(
                            children: _stockBas.map((p) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3E0),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(children: [
                                const Icon(Icons.warning_amber_rounded,
                                    color: Color(0xFFB8860B), size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${p.nom} — ${p.stock} unités',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF7A5C00),
                                              fontSize: 13)),
                                      const Text('Stock bas',
                                          style: TextStyle(
                                              color: Color(0xFF7A5C00),
                                              fontSize: 11)),
                                    ],
                                  ),
                                ),
                                // Bouton "Modifier" — navigue directement
                                // vers l'écran d'édition du produit (avec
                                // son id en `extra`) pour permettre au
                                // vendeur de réapprovisionner rapidement le
                                // stock.
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFF5A623),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8)),
                                  ),
                                  onPressed: () => context.push(
                                      '/vendor/edit-product', extra: p.id),
                                  child: const Text('Modifier',
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.white)),
                                ),
                              ]),
                            )).toList(),
                          ),
                    const SizedBox(height: 18),

                    // Section "Top 5 produits" (BF-031) : classement des 5
                    // produits ayant le plus de commandes, avec un badge
                    // numéroté (1 à 5) devant chaque nom.
                    _sectionTitle('Top 5 produits'),
                    _top5.isEmpty
                        ? _emptyCard('Pas encore de données')
                        : Column(
                            children: _top5.asMap().entries.map((e) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(children: [
                                Container(
                                  width: 28, height: 28,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0D2B5E),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text('${e.key + 1}',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(e.value.nom,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13))),
                                Text('${e.value.totalCommandes} cmd',
                                    style: const TextStyle(
                                        color: Color(0xFF1D9E75),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12)),
                              ]),
                            )).toList(),
                          ),
                    const SizedBox(height: 18),

                    // Section "Flop 5" (BF-032) : les 5 produits les moins
                    // commandés, avec un bouton "Promo rapide" menant à
                    // l'écran de modification du produit (pour y baisser
                    // le prix, par exemple).
                    _sectionTitle('Flop 5 — à promouvoir'),
                    _flop5.isEmpty
                        ? _emptyCard('Pas encore de données')
                        : Column(
                            children: _flop5.map((p) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(p.nom, style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                      Text('${p.totalCommandes} commandes',
                                          style: const TextStyle(
                                              color: Color(0xFF999999),
                                              fontSize: 11)),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => context.push(
                                      '/vendor/edit-product', extra: p.id),
                                  child: const Text('Promo rapide',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFFE63946))),
                                ),
                              ]),
                            )).toList(),
                          ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

      // Barre de navigation basse du vendeur : Dashboard (écran courant,
      // actif), Produits, Commandes. Utilise `context.go` (remplace la
      // route courante, pas d'empilement) pour se comporter comme une
      // vraie navigation par onglets.
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
                _NavItem(icon: Icons.dashboard_outlined,
                    label: 'Dashboard', active: true, onTap: () {}),
                _NavItem(icon: Icons.inventory_2_outlined,
                    label: 'Produits',
                    onTap: () => context.go('/vendor/products')),
                _NavItem(icon: Icons.receipt_long_outlined,
                    label: 'Commandes',
                    onTap: () => context.go('/vendor/orders')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Calcule le chiffre d'affaires (CA) sur les [jours] derniers jours
  /// (BF-031), en agrégeant côté client (Dart) la liste des commandes déjà
  /// chargée en mémoire — pas de requête Supabase supplémentaire. On
  /// exclut les commandes annulées (elles ne représentent pas un revenu
  /// réel) et on ne garde que celles créées après le seuil de date calculé
  /// (`now - jours`). Utilisée avec `jours: 1` pour le CA du jour et
  /// `jours: 30` pour le CA du mois.
  double _calculerCA(List<OrderModel> ordres, {required int jours}) {
    final seuil = DateTime.now().subtract(Duration(days: jours));
    return ordres
        .where((o) => o.statut != 'annulee' && o.createdAt.isAfter(seuil))
        .fold(0.0, (sum, o) => sum + o.total);
  }

  // Formate un montant en HTG de façon compacte : au-delà de 1000 HTG, on
  // affiche en milliers arrondis avec un "K" (ex : 2500 -> "3K HTG") pour
  // que la carte "Ce mois" reste lisible sur un petit espace.
  String _formatCourt(double v) =>
      v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}K HTG' : '${v.toStringAsFixed(0)} HTG';

  // Carte rouge mettant en avant le nombre de commandes en attente
  // (élément visuellement distinct des cartes CA classiques, pour attirer
  // l'attention du vendeur).
  Widget _caCardEnAttente(int nb) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFE63946),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
        Text('En attente', style: const TextStyle(
            fontSize: 10, color: Colors.white70)),
        const SizedBox(height: 4),
        Text('$nb', style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const Text('Commandes', style: TextStyle(
            fontSize: 9, color: Colors.white70)),
      ]),
    ),
  );

  // Carte blanche générique affichant un libellé et une valeur (ex : "CA
  // Aujourd'hui" / "1500 HTG"), réutilisée pour les cartes CA du jour et
  // du mois.
  Widget _caCard(String label, String valeur) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 6, offset: const Offset(0, 2),
        )],
      ),
      child: Column(children: [
        Text(label, style: const TextStyle(
            fontSize: 10, color: Color(0xFF666666))),
        const SizedBox(height: 4),
        Text(valeur, style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold,
            color: Color(0xFF0D2B5E))),
      ]),
    ),
  );

  // Titre de section avec un badge numéroté optionnel (ex : "En attente du
  // vendeur" + badge rouge "3") affiché seulement si `badge > 0`.
  Widget _sectionTitle(String t, {int badge = 0}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Text(t, style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.bold,
          color: Color(0xFF1A1F36))),
      if (badge > 0) ...[
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFE63946),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$badge',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
        ),
      ],
    ]),
  );

  // Message d'état vide affiché quand une section n'a pas encore de
  // données (ex : aucune commande en attente, aucune alerte de stock).
  Widget _emptyCard(String msg) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    margin: const EdgeInsets.only(bottom: 4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(msg,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFF999999), fontSize: 13)),
  );
}

// Un item de la barre de navigation basse (icône + libellé), dont la
// couleur change selon `active` (onglet courant en bleu marine, sinon
// gris) pour indiquer visuellement l'écran actif.
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
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            color: active ? const Color(0xFF0D2B5E) : const Color(0xFF999999),
            size: 22),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(
            fontSize: 10,
            color: active ? const Color(0xFF0D2B5E) : const Color(0xFF999999),
            fontWeight: active ? FontWeight.bold : FontWeight.normal)),
      ],
    ),
  );
}