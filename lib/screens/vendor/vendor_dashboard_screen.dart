import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../services/database_service.dart';
import '../../models/product_model.dart';
import '../../widgets/order_status_badge.dart';

/// Dashboard Vendeur — Faitza COLAS
/// Branch : feature/vendor-catalog
/// Path : lib/screens/vendor/vendor_dashboard_screen.dart
class VendorDashboardScreen extends StatefulWidget {
  const VendorDashboardScreen({super.key});

  @override
  State<VendorDashboardScreen> createState() => _VendorDashboardScreenState();
}

class _VendorDashboardScreenState extends State<VendorDashboardScreen> {
  final _db = DatabaseService();
  List<ProductModel> _stockBas = [];
  List<ProductModel> _top5 = [];
  List<ProductModel> _flop5 = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
    _initOrders();
  }

  Future<void> _loadStats() async {
    final auth = context.read<AuthProvider>();
    if (auth.currentUser == null) return;
    final shopId = auth.currentUser!.shopCode ?? '';

    final stockBas = await _db.getLowStockProducts(shopId);
    final top5 = await _db.getTopProducts(limit: 5);
    final flop5 = await _db.getFlop5Products(shopId);

    setState(() {
      _stockBas = stockBas;
      _top5 = top5;
      _flop5 = flop5;
    });
  }

  void _initOrders() {
    final auth = context.read<AuthProvider>();
    if (auth.currentUser == null) return;
    context.read<OrderProvider>().listenVendorOrders(auth.currentUser!.id);
  }

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrderProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B5E),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mon Dashboard',
                style: TextStyle(color: Colors.white, fontSize: 16,
                    fontWeight: FontWeight.bold)),
            Text('Boutique ouverte',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── CA Cards ──
              Row(children: [
                _caCard('Aujourd\'hui', '0 HTG'),
                const SizedBox(width: 12),
                _caCard('Semaine', '0 HTG'),
                const SizedBox(width: 12),
                _caCard('Mois', '0 HTG'),
              ]),
              const SizedBox(height: 20),

              // ── Commandes en attente ──
              _sectionTitle('En attente du vendeur (${orders.enAttente.length})'),
              orders.enAttente.isEmpty
                  ? _emptyState('Aucune commande en attente')
                  : Column(
                      children: orders.enAttente.map((o) => Card(
                        child: ListTile(
                          title: Text('Commande #${o.id.substring(0, 6).toUpperCase()}'),
                          subtitle: Text('${o.total.toStringAsFixed(0)} HTG'),
                          trailing: OrderStatusBadge(statut: o.statut),
                          onTap: () => Navigator.pushNamed(
                            context, '/vendor/order-detail',
                            arguments: o,
                          ),
                        ),
                      )).toList(),
                    ),
              const SizedBox(height: 20),

              // ── Alertes stock bas ──
              _sectionTitle('Alertes stock ≤ 5 (${_stockBas.length})'),
              _stockBas.isEmpty
                  ? _emptyState('Tous les stocks sont OK')
                  : Column(
                      children: _stockBas.map((p) => Card(
                        child: ListTile(
                          title: Text(p.nom),
                          subtitle: Text('Stock : ${p.stock} unités',
                              style: const TextStyle(
                                  color: Color(0xFFF5A623))),
                          trailing: TextButton(
                            onPressed: () => Navigator.pushNamed(
                              context, '/vendor/edit-product',
                              arguments: p.id,
                            ),
                            child: const Text('Modifier'),
                          ),
                        ),
                      )).toList(),
                    ),
              const SizedBox(height: 20),

              // ── Top 5 ──
              _sectionTitle('Top 5 produits'),
              _top5.isEmpty
                  ? _emptyState('Pas encore de données')
                  : Column(
                      children: _top5.asMap().entries.map((e) => Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF0D2B5E),
                            child: Text('${e.key + 1}',
                                style: const TextStyle(color: Colors.white)),
                          ),
                          title: Text(e.value.nom),
                          trailing: Text('${e.value.totalCommandes} cmd',
                              style: const TextStyle(
                                  color: Color(0xFF1D9E75),
                                  fontWeight: FontWeight.bold)),
                        ),
                      )).toList(),
                    ),
              const SizedBox(height: 20),

              // ── Flop 5 ──
              _sectionTitle('Flop 5 — À promouvoir'),
              _flop5.isEmpty
                  ? _emptyState('Pas encore de données')
                  : Column(
                      children: _flop5.map((p) => Card(
                        child: ListTile(
                          title: Text(p.nom),
                          subtitle: Text('${p.totalCommandes} commandes'),
                          trailing: TextButton(
                            onPressed: () {},
                            child: const Text('Promo rapide',
                                style: TextStyle(color: Color(0xFFE63946))),
                          ),
                        ),
                      )).toList(),
                    ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _caCard(String label, String valeur) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: [
            Text(label, style: const TextStyle(fontSize: 11,
                color: Color(0xFF666666))),
            const SizedBox(height: 4),
            Text(valeur, style: const TextStyle(fontSize: 13,
                fontWeight: FontWeight.bold, color: Color(0xFF0D2B5E))),
          ]),
        ),
      );

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: const TextStyle(fontSize: 15,
            fontWeight: FontWeight.bold, color: Color(0xFF0D2B5E))),
      );

  Widget _emptyState(String msg) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(12)),
        child: Text(msg, textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF999999))),
      );
}