import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/shop_model.dart';
import '../../models/product_model.dart';
import '../../widgets/shop_logo_widget.dart';
import '../../widgets/whatsapp_button_widget.dart';

/// Détail boutique — Claudimyr CASSIGNOL
/// Branch : feature/client-home
/// Path : lib/screens/client/boutique_detail_screen.dart
class BoutiqueDetailScreen extends StatefulWidget {
  final ShopModel shop;
  const BoutiqueDetailScreen({super.key, required this.shop});

  @override
  State<BoutiqueDetailScreen> createState() => _BoutiqueDetailScreenState();
}

class _BoutiqueDetailScreenState extends State<BoutiqueDetailScreen> {
  List<String> _categories = [];
  List<ProductModel> _produits = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Charger produits de la boutique
      final rows = await Supabase.instance.client
          .from('products')
          .select()
          .eq('shop_id', widget.shop.id)
          .eq('disponible', true);

      final produits = rows
          .map((row) => ProductModel.fromMap(row, row['id']))
          .toList();

      // Extraire catégories uniques
      final cats = produits.map((p) => p.categorie).toSet().toList();

      setState(() {
        _produits = produits;
        _categories = cats;
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
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: const Color(0xFF0D2B5E),
            foregroundColor: Colors.white,
            expandedHeight: 180,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(widget.shop.nom,
                  style: const TextStyle(color: Colors.white, fontSize: 14)),
              background: Container(
                color: const Color(0xFF0D2B5E),
                child: Center(
                  child: ShopLogoWidget(
                    logoUrl: widget.shop.logoUrl,
                    initiales: widget.shop.initiales,
                    size: 80,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Stats boutique
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statItem('Note', '⭐ ${widget.shop.rating.toStringAsFixed(1)}'),
                      _statItem('Avis', '${widget.shop.totalAvis}'),
                      _statItem('Produits', '${_produits.length}'),
                    ],
                  ),
                ),

                // Description
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(widget.shop.description,
                      style: const TextStyle(color: Color(0xFF666666))),
                ),
                const SizedBox(height: 16),

                // Bouton WhatsApp
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: WhatsAppButtonWidget(
                    telephone: '',
                    label: 'Contacter via WhatsApp',
                  ),
                ),
                const SizedBox(height: 16),

                // Catégories
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  if (_categories.isNotEmpty) ...[
                    _sectionTitle('Catégories'),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 2.5,
                      ),
                      itemCount: _categories.length,
                      itemBuilder: (_, i) => GestureDetector(
                        onTap: () => Navigator.pushNamed(
                          context, '/client/subcategory',
                          arguments: {
                            'shopId': widget.shop.id,
                            'categorie': _categories[i],
                          },
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF3FB),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF0D2B5E)),
                          ),
                          child: Text(_categories[i],
                              style: const TextStyle(
                                  color: Color(0xFF0D2B5E),
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Produits populaires boutique
                  if (_produits.isNotEmpty) ...[
                    _sectionTitle('Produits populaires'),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.75,
                      ),
                      itemCount: _produits.take(4).length,
                      itemBuilder: (_, i) {
                        final p = _produits[i];
                        return GestureDetector(
                          onTap: () => Navigator.pushNamed(
                            context, '/client/product',
                            arguments: p,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(12)),
                                    child: p.vignette != null
                                        ? Image.network(p.vignette!,
                                            fit: BoxFit.cover,
                                            width: double.infinity)
                                        : Container(
                                            color: const Color(0xFFEEF3FB),
                                            child: const Icon(
                                                Icons.image_outlined,
                                                color: Color(0xFF0D2B5E))),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(p.nom,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                      Text(
                                          '${p.prixAffiche.toStringAsFixed(0)} HTG',
                                          style: const TextStyle(
                                              color: Color(0xFF0D2B5E),
                                              fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Text(t, style: const TextStyle(fontSize: 16,
            fontWeight: FontWeight.bold, color: Color(0xFF0D2B5E))),
      );

  Widget _statItem(String label, String value) => Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 16,
              fontWeight: FontWeight.bold, color: Color(0xFF0D2B5E))),
          Text(label, style: const TextStyle(fontSize: 12,
              color: Color(0xFF666666))),
        ],
      );
}
