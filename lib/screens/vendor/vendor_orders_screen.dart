import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../models/order_model.dart';
import '../../widgets/order_status_badge.dart';
import '../../providers/theme_provider.dart';
import '../../constants/app_colors.dart';

/// Commandes Vendeur — Faitza COLAS
/// Branch : feature/vendor-catalog
/// Path : lib/screens/vendor/vendor_orders_screen.dart
///
/// Ecran listant toutes les commandes reçues par la boutique du vendeur,
/// organisées en onglets par statut (nouvelle, acceptée, en préparation,
/// en livraison, livrée, annulée). Les données arrivent en temps réel via
/// OrderProvider qui écoute un stream Supabase (voir listenVendorOrders).
class VendorOrdersScreen extends StatefulWidget {
  const VendorOrdersScreen({super.key});

  @override
  State<VendorOrdersScreen> createState() => _VendorOrdersScreenState();
}

// `SingleTickerProviderStateMixin` fournit le `vsync` nécessaire à
// l'animation du TabController (transition entre onglets).
class _VendorOrdersScreenState extends State<VendorOrdersScreen>
    with SingleTickerProviderStateMixin {
  // Contrôleur pilotant la TabBar et la TabBarView (synchronise l'onglet
  // sélectionné avec le contenu affiché en dessous).
  late TabController _tabController;

  // Liste des statuts possibles d'une commande, avec leur libellé lisible
  // affiché dans les onglets. Chaque onglet filtrera la liste des
  // commandes selon la valeur 'value' correspondante.
  final List<Map<String, String>> _statuts = [
    {'value': 'nouvelle',    'label': 'En attente du vendeur'},
    {'value': 'acceptee',    'label': 'Acceptée'},
    {'value': 'preparation', 'label': 'En préparation'},
    {'value': 'livraison',   'label': 'En livraison'},
    {'value': 'livree',      'label': 'Livrée'},
    {'value': 'annulee',     'label': 'Annulée'},
  ];

  @override
  void initState() {
    super.initState();
    // Un onglet par statut : la longueur du TabController correspond au
    // nombre d'entrées de `_statuts`.
    _tabController = TabController(length: _statuts.length, vsync: this);
    final auth = context.read<AuthProvider>();
    if (auth.currentUser != null) {
      // Démarre l'écoute temps réel (stream Supabase) des commandes de ce
      // vendeur : dès qu'une commande est créée/modifiée côté serveur,
      // l'UI se met à jour automatiquement sans rechargement manuel.
      context.read<OrderProvider>().listenVendorOrders(auth.currentUser!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    // `watch` reconstruit ce widget à chaque nouvelle émission du stream
    // de commandes (mise à jour temps réel de la liste affichée).
    final orders = context.watch<OrderProvider>().ordresVendeur;
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(isDark),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B5E),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => context.go('/vendor/dashboard'),
        ),
        title: const Text('Commandes',
            style: TextStyle(color: Colors.white)),
        // Barre d'onglets scrollable horizontalement (6 statuts, ne
        // tiennent pas tous à l'écran sur mobile) affichant le libellé de
        // chaque statut.
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: const Color(0xFFE63946),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: _statuts.map((s) => Tab(text: s['label'])).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        // Pour chaque statut, on construit une vue filtrant la liste
        // complète des commandes sur `o.statut == s['value']`.
        children: _statuts.map((s) {
          final filtered = orders
              .where((o) => o.statut == s['value'])
              .toList();

          if (filtered.isEmpty) {
            return Center(
              child: Text('Aucune commande "${s['label']}"',
                  style: TextStyle(color: AppColors.textSecondaryFor(isDark))),
            );
          }

          // Liste des commandes filtrées pour ce statut, une carte par
          // commande via le widget privé `_OrderCard`.
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            itemBuilder: (_, i) => _OrderCard(order: filtered[i]),
          );
        }).toList(),
      ),
    );
  }

  @override
  void dispose() {
    // Libère les ressources du TabController pour éviter les fuites
    // mémoire lorsque l'écran est détruit.
    _tabController.dispose();
    super.dispose();
  }
}

// Carte résumant une commande dans la liste : identifiant court, total en
// gourdes (HTG), zone de livraison, badge de statut coloré, et un tap qui
// ouvre l'écran de détail de la commande.
class _OrderCard extends StatelessWidget {
  final OrderModel order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        // On affiche seulement les 6 premiers caractères de l'UUID de la
        // commande (en majuscules) pour un identifiant court et lisible
        // par l'utilisateur, sans exposer l'UUID complet.
        title: Text('Commande #${order.id.substring(0, 6).toUpperCase()}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${order.total.toStringAsFixed(0)} HTG · ${order.zone}'),
        trailing: OrderStatusBadge(statut: order.statut),
        // Navigue vers l'écran de détail en transmettant l'objet commande
        // entier via `extra` (évite un rechargement réseau).
        onTap: () => context.push('/vendor/order-detail', extra: order),
      ),
    );
  }
}