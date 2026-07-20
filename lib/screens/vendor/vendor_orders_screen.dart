import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../models/order_model.dart';
import '../../widgets/order_status_badge.dart';

/// Commandes Vendeur — Faitza COLAS
/// Branch : feature/vendor-catalog
/// Path : lib/screens/vendor/vendor_orders_screen.dart
class VendorOrdersScreen extends StatefulWidget {
  const VendorOrdersScreen({super.key});

  @override
  State<VendorOrdersScreen> createState() => _VendorOrdersScreenState();
}

class _VendorOrdersScreenState extends State<VendorOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
    _tabController = TabController(length: _statuts.length, vsync: this);
    final auth = context.read<AuthProvider>();
    if (auth.currentUser != null) {
      context.read<OrderProvider>().listenVendorOrders(auth.currentUser!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrderProvider>().ordresVendeur;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B5E),
        title: const Text('Commandes',
            style: TextStyle(color: Colors.white)),
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
        children: _statuts.map((s) {
          final filtered = orders
              .where((o) => o.statut == s['value'])
              .toList();

          if (filtered.isEmpty) {
            return Center(
              child: Text('Aucune commande "${s['label']}"',
                  style: const TextStyle(color: Color(0xFF999999))),
            );
          }

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
    _tabController.dispose();
    super.dispose();
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text('Commande #${order.id.substring(0, 6).toUpperCase()}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${order.total.toStringAsFixed(0)} HTG · ${order.zone}'),
        trailing: OrderStatusBadge(statut: order.statut),
        onTap: () => Navigator.pushNamed(
          context, '/vendor/order-detail',
          arguments: order,
        ),
      ),
    );
  }
}