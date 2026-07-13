import 'package:flutter/material.dart';

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

  final List<String> _statuts = [
    'En attente du vendeur',
    'Acceptée',
    'En préparation',
    'En livraison',
    'Livrée',
    'Annulée',
  ];

  // Valeurs Firestore correspondantes
  final List<String> _statutValues = [
    'nouvelle',
    'acceptee',
    'preparation',
    'livraison',
    'livree',
    'annulee',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: _statuts.length, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
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
          tabs: _statuts.map((s) => Tab(text: s)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _statutValues.map((statut) {
          return Center(
            child: Text(
              'Commandes "$statut" apparaîtront ici\n(StreamBuilder Firestore)',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF999999)),
            ),
          );
          // TODO : StreamBuilder filtré par statut
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