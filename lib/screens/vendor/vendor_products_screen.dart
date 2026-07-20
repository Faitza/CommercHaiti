import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../models/product_model.dart';
import '../../widgets/product_card_widget.dart';
import '../../services/database_service.dart';

/// Liste produits Vendeur — Faitza COLAS
/// Branch : feature/vendor-catalog
/// Path : lib/screens/vendor/vendor_products_screen.dart
class VendorProductsScreen extends StatelessWidget {
  const VendorProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final shopId = auth.currentUser?.shopCode ?? '';

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
      body: StreamBuilder(
        stream: Supabase.instance.client
            .from('products')
            .stream(primaryKey: ['id'])
            .eq('shop_id', shopId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('Aucun produit — appuyez sur + pour en ajouter',
                  style: TextStyle(color: Color(0xFF999999))),
            );
          }
          final products = snapshot.data!
              .map((row) => ProductModel.fromMap(row, row['id']))
              .toList();

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.75,
            ),
            itemCount: products.length,
            itemBuilder: (_, i) => ProductCardWidget(
              product: products[i],
              onTap: () => Navigator.pushNamed(
                context, '/vendor/edit-product',
                arguments: products[i].id,
              ),
            ),
          );
        },
      ),
    );
  }
}