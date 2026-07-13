import 'package:flutter/material.dart';

/// Modifier produit — Faitza COLAS
/// Branch : feature/vendor-catalog
/// Path : lib/screens/vendor/vendor_edit_product_screen.dart
/// Même formulaire que VendorAddProductScreen mais pré-rempli
class VendorEditProductScreen extends StatelessWidget {
  final String productId;

  const VendorEditProductScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B5E),
        foregroundColor: Colors.white,
        title: const Text('Modifier le produit'),
        actions: [
          // Bouton supprimer
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Color(0xFFE63946)),
            onPressed: () => _confirmerSuppression(context),
          ),
        ],
      ),
      body: const Center(
        child: Text(
          'Formulaire pré-rempli\n(même que VendorAddProductScreen\nmais avec données du produit)',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF999999)),
        ),
        // TODO : charger ProductModel depuis Firestore puis
        // afficher même formulaire que VendorAddProductScreen pré-rempli
      ),
    );
  }

  void _confirmerSuppression(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ce produit ?'),
        content: const Text(
            'Cette action est irréversible. Le produit sera retiré du catalogue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE63946)),
            onPressed: () {
              // TODO : FirestoreService.deleteProduct(productId)
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Supprimer',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}