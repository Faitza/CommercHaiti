import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/product_model.dart';
import '../../widgets/product_card_widget.dart';

/// Sous-catégories & produits — Claudimyr CASSIGNOL
/// Branch : feature/client-home
/// Path : lib/screens/client/subcategory_screen.dart
class SubcategoryScreen extends StatefulWidget {
  final String shopId;
  final String categorie;

  const SubcategoryScreen({
    super.key,
    required this.shopId,
    required this.categorie,
  });

  @override
  State<SubcategoryScreen> createState() => _SubcategoryScreenState();
}

class _SubcategoryScreenState extends State<SubcategoryScreen> {
  List<ProductModel> _produits = [];
  List<String> _sousCategories = [];
  String _sousCatSelectionnee = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProduits();
  }

  Future<void> _loadProduits() async {
    try {
      var query = Supabase.instance.client
          .from('products')
          .select()
          .eq('shop_id', widget.shopId)
          .eq('categorie', widget.categorie)
          .eq('disponible', true);

      if (_sousCatSelectionnee.isNotEmpty) {
        query = query.eq('sous_categorie', _sousCatSelectionnee);
      }

      final rows = await query;
      final produits = rows
          .map((row) => ProductModel.fromMap(row, row['id']))
          .toList();

      final sousCats = produits
          .map((p) => p.sousCategorie)
          .toSet()
          .toList();

      setState(() {
        _produits = produits;
        _sousCategories = sousCats;
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
        title: Text(widget.categorie),
      ),
      body: Column(
        children: [
          // Filtre sous-catégories
          if (_sousCategories.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _filterChip('Tous', ''),
                  ..._sousCategories.map((sc) => _filterChip(sc, sc)),
                ],
              ),
            ),

          // Produits
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _produits.isEmpty
                    ? const Center(
                        child: Text('Aucun produit dans cette catégorie',
                            style: TextStyle(color: Color(0xFF999999))))
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.75,
                        ),
                        itemCount: _produits.length,
                        itemBuilder: (_, i) => ProductCardWidget(
                          product: _produits[i],
                          onTap: () => Navigator.pushNamed(
                            context, '/client/product',
                            arguments: _produits[i],
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final sel = _sousCatSelectionnee == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: sel,
        onSelected: (_) {
          setState(() => _sousCatSelectionnee = value);
          _loadProduits();
        },
        selectedColor: const Color(0xFFEEF3FB),
        labelStyle: TextStyle(
          color: sel ? const Color(0xFF0D2B5E) : const Color(0xFF666666),
          fontWeight: sel ? FontWeight.bold : FontWeight.normal,
        ),
        side: BorderSide(
            color: sel ? const Color(0xFF0D2B5E) : const Color(0xFFCCCCCC)),
      ),
    );
  }
}
