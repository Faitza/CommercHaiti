import 'package:flutter/material.dart';

/// Dashboard Vendeur — Faitza COLAS
/// Branch : feature/vendor-catalog
/// Path : lib/screens/vendor/vendor_dashboard_screen.dart
class VendorDashboardScreen extends StatelessWidget {
  const VendorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () {}, // TODO : ouvrir hamburger menu
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── CA Cards ──
            Row(
              children: [
                _caCard('Aujourd\'hui', '0 HTG'),
                const SizedBox(width: 12),
                _caCard('Semaine', '0 HTG'),
                const SizedBox(width: 12),
                _caCard('Mois', '0 HTG'),
              ],
            ),
            const SizedBox(height: 20),

            // ── Nouvelles commandes (Stream) ──
            _sectionTitle('En attente du vendeur'),
            // TODO : StreamBuilder sur FirestoreService.getOrdersForVendor()
            _emptyState('Aucune commande en attente'),
            const SizedBox(height: 20),

            // ── Alertes stock bas ──
            _sectionTitle('Alertes stock ≤ 5'),
            // TODO : StreamBuilder produits avec stock <= 5
            _emptyState('Tous les stocks sont OK'),
            const SizedBox(height: 20),

            // ── Top 5 produits ──
            _sectionTitle('Top 5 produits'),
            // TODO : query produits orderBy totalCommandes desc limit 5
            _emptyState('Pas encore de données'),
            const SizedBox(height: 20),

            // ── Flop 5 produits ──
            _sectionTitle('Flop 5 — À promouvoir'),
            _emptyState('Pas encore de données'),
          ],
        ),
      ),
    );
  }

  Widget _caCard(String label, String valeur) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
              blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(fontSize: 11,
                    color: Color(0xFF666666))),
            const SizedBox(height: 4),
            Text(valeur,
                style: const TextStyle(fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D2B5E))),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title,
            style: const TextStyle(fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D2B5E))),
      );

  Widget _emptyState(String msg) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(msg,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF999999))),
      );
}