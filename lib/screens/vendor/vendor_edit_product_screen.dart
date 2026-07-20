import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/database_service.dart';

/// Modifier produit — Faitza COLAS
/// Branch : feature/vendor-catalog
/// Path : lib/screens/vendor/vendor_edit_product_screen.dart
class VendorEditProductScreen extends StatelessWidget {
  final String productId;

  const VendorEditProductScreen({super.key, required this.productId});

  Future<void> _supprimer(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ce produit ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE63946)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseService().deleteProduct(productId);
      if (context.mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B5E),
        foregroundColor: Colors.white,
        title: const Text('Modifier le produit'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: Color(0xFFE63946)),
            onPressed: () => _supprimer(context),
          ),
        ],
      ),
      body: const Center(
        child: Text(
          'Formulaire pré-rempli\n(même que VendorAddProductScreen\navec données du produit)',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF999999)),
        ),
      ),
    );
  }
}