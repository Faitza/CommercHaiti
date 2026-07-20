import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../models/product_model.dart';

/// Stats Vendeur — Faitza COLAS
/// Branch : feature/vendor-catalog
/// Path : lib/screens/vendor/vendor_stats_screen.dart
class VendorStatsScreen extends StatefulWidget {
  const VendorStatsScreen({super.key});

  @override
  State<VendorStatsScreen> createState() => _VendorStatsScreenState();
}

class _VendorStatsScreenState extends State<VendorStatsScreen> {
  final _db = DatabaseService();
  List<ProductModel> _top5 = [];
  List<ProductModel> _flop5 = [];
  List<ProductModel> _stockBas = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final auth = context.read<AuthProvider>();
    final shopId = auth.currentUser?.shopCode ?? '';

    final top5 = await _db.getTopProducts(limit: 5);
    final flop5 = await _db.getFlop5Products(shopId);
    final stockBas = await _db.getLowStockProducts(shopId);

    setState(() {
      _top5 = top5;
      _flop5 = flop5;
      _stockBas = stockBas;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B5E),
        foregroundColor: Colors.white,
        title: const Text('Statistiques'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Top 5 produits les plus demandés'),
                    _top5.isEmpty
                        ? _emptyState('Pas encore de données')
                        : Column(
                            children: _top5.asMap().entries.map((e) =>
                              _produitRow(e.key + 1, e.value,
                                  suffix: '${e.value.totalCommandes} cmd')).toList(),
                          ),
                    const SizedBox(height: 20),

                    _sectionTitle('Flop 5 — Produits à promouvoir'),
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
                                      style: TextStyle(
                                          color: Color(0xFFE63946))),
                                ),
                              ),
                            )).toList(),
                          ),
                    const SizedBox(height: 20),

                    _sectionTitle('Alertes stock bas (≤ 5 unités)'),
                    _stockBas.isEmpty
                        ? _emptyState('Tous les stocks sont OK')
                        : Column(
                            children: _stockBas.map((p) => Card(
                              child: ListTile(
                                title: Text(p.nom),
                                subtitle: Text('Stock : ${p.stock}',
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
                  ],
                ),
              ),
            ),
    );
  }

  Widget _produitRow(int rang, ProductModel p, {String? suffix}) => Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF0D2B5E),
            child: Text('$rang',
                style: const TextStyle(color: Colors.white)),
          ),
          title: Text(p.nom),
          trailing: suffix != null
              ? Text(suffix,
                  style: const TextStyle(
                      color: Color(0xFF1D9E75),
                      fontWeight: FontWeight.bold))
              : null,
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
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(12)),
        child: Text(msg, textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF999999))),
      );
}