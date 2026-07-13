import 'package:flutter/material.dart';

/// Liste produits Vendeur — Faitza COLAS
/// Branch : feature/vendor-catalog
/// Path : lib/screens/vendor/vendor_products_screen.dart
class VendorProductsScreen extends StatelessWidget {
  const VendorProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B5E),
        title: const Text('Mes produits',
            style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () =>
                Navigator.pushNamed(context, '/vendor/add-product'),
          ),
        ],
      ),
      // TODO : StreamBuilder sur products où shopId == currentUser.shopId
      body: const Center(
        child: Text('Vos produits apparaîtront ici',
            style: TextStyle(color: Color(0xFF999999))),
      ),
    );
  }
}