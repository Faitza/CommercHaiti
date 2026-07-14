import 'package:flutter/material.dart';

/// Stats Vendeur — Faitza COLAS
/// Branch : feature/vendor-catalog
/// Path : lib/screens/vendor/vendor_stats_screen.dart
class VendorStatsScreen extends StatelessWidget {
  const VendorStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B5E),
        foregroundColor: Colors.white,
        title: const Text('Statistiques'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('CA de la semaine'),
            // TODO : graphique barres par jour (fl_chart package)
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text('Graphique CA semaine\n(fl_chart)',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF999999))),
              ),
            ),
            const SizedBox(height: 20),

            _sectionTitle('Top 5 produits les plus demandés'),
            // TODO : query orderBy totalCommandes desc limit 5
            _emptyState('Données à venir'),
            const SizedBox(height: 20),

            _sectionTitle('Flop 5 — Produits à promouvoir'),
            // TODO : query orderBy totalCommandes asc limit 5
            // + bouton "Promo rapide" sur chaque item
            _emptyState('Données à venir'),
            const SizedBox(height: 20),

            _sectionTitle('Alertes stock bas (≤ 5 unités)'),
            // TODO : query stock <= 5
            _emptyState('Tous les stocks sont OK'),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t,
            style: const TextStyle(fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D2B5E))),
      );

  Widget _emptyState(String msg) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(msg,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF999999))),
      );
}