import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/shop_model.dart';
import '../../models/product_model.dart';
import '../../widgets/shop_logo_widget.dart';

/// Boutiques proposant un produit — Claudimyr CASSIGNOL
/// Branch : feature/client-home
/// Path : lib/screens/client/product_shops_screen.dart
/// Affiché quand client clique sur un produit populaire depuis l'accueil
class ProductShopsScreen extends StatefulWidget {
  final String productNom;

  const ProductShopsScreen({super.key, required this.productNom});

  @override
  State<ProductShopsScreen> createState() => _ProductShopsScreenState();
}

class _ProductShopsScreenState extends State<ProductShopsScreen> {
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBoutiques();
  }

  Future<void> _loadBoutiques() async {
    try {
      // Chercher produits avec ce nom dans toutes les boutiques
      final rows = await Supabase.instance.client
          .from('products')
          .select('*, shops(*)')
          .ilike('nom', '%${widget.productNom}%')
          .eq('disponible', true);

      setState(() {
        _results = List<Map<String, dynamic>>.from(rows);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B5E),
        foregroundColor: Colors.white,
        title: Text(widget.productNom),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(24),
          child: Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Boutiques disponibles',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty
              ? const Center(
                  child: Text('Aucune boutique ne propose ce produit',
                      style: TextStyle(color: Color(0xFF999999))))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _results.length,
                  itemBuilder: (_, i) {
                    final row = _results[i];
                    final product = ProductModel.fromMap(row, row['id']);
                    final shopData = row['shops'] as Map<String, dynamic>?;

                    if (shopData == null) return const SizedBox();

                    final shop = ShopModel.fromMap(shopData, shopData['id']);

                    return GestureDetector(
                      onTap: () => Navigator.pushNamed(
                        context, '/client/boutique',
                        arguments: shop,
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            ShopLogoWidget(
                              logoURL: shop.logoUrl,
                              initiales: shop.initiales,
                              size: 50,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(shop.nom,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  Text('⭐ ${shop.rating.toStringAsFixed(1)}',
                                      style: const TextStyle(fontSize: 12,
                                          color: Color(0xFF666666))),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${product.prixAffiche.toStringAsFixed(0)} HTG',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0D2B5E),
                                      fontSize: 16),
                                ),
                                if (product.hasPromo)
                                  Text(
                                    '${product.prix.toStringAsFixed(0)} HTG',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF999999),
                                        decoration: TextDecoration.lineThrough),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
