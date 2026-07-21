import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/cart_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/product_model.dart';
import '../auth/guest_home_screen.dart';

/// Détail produit — Claudimyr CASSIGNOL
/// Branch : feature/client-home
/// Path : lib/screens/client/product_detail_screen.dart
class ProductDetailScreen extends StatefulWidget {
  final ProductModel product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _photoIndex = 0;
  String? _couleurSelectionnee;
  String? _tailleSelectionnee;
  int _quantite = 1;
  ProductModel? _productLive; // Stock temps réel

  @override
  void initState() {
    super.initState();
    _productLive = widget.product;
  }

  bool get _selectionComplete {
    if (widget.product.couleurs.isNotEmpty && _couleurSelectionnee == null)
      return false;
    if (widget.product.tailles.isNotEmpty && _tailleSelectionnee == null)
      return false;
    return true;
  }

  void _ajouterAuPanier() {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      GuestHomeScreen.showInscriptionSheet(context);
      return;
    }
    context.read<CartProvider>().addItem(
      product: _productLive ?? widget.product,
      quantite: _quantite,
      couleur: _couleurSelectionnee,
      taille: _tailleSelectionnee,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ajouté au panier !'),
          backgroundColor: Color(0xFF1D9E75),
          duration: Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _productLive ?? widget.product;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B5E),
        foregroundColor: Colors.white,
        title: Text(p.nom, overflow: TextOverflow.ellipsis),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Carrousel photos avec stock temps réel
            StreamBuilder(
              stream: Supabase.instance.client
                  .from('products')
                  .stream(primaryKey: ['id'])
                  .eq('id', widget.product.id),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  _productLive = ProductModel.fromMap(
                      snapshot.data!.first, snapshot.data!.first['id']);
                }
                final prod = _productLive ?? widget.product;

                return Stack(
                  children: [
                    SizedBox(
                      height: 280,
                      child: PageView.builder(
                        itemCount: prod.photos.isEmpty ? 1 : prod.photos.length,
                        onPageChanged: (i) => setState(() => _photoIndex = i),
                        itemBuilder: (_, i) => prod.photos.isEmpty
                            ? Container(color: const Color(0xFFEEF3FB),
                                child: const Icon(Icons.image_outlined,
                                    size: 60, color: Color(0xFF0D2B5E)))
                            : Image.network(prod.photos[i], fit: BoxFit.cover),
                      ),
                    ),
                    if (prod.hasPromo)
                      Positioned(top: 12, left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: const Color(0xFFE63946),
                              borderRadius: BorderRadius.circular(6)),
                          child: Text('-${prod.pourcentageReduction}%',
                              style: const TextStyle(color: Colors.white,
                                  fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                    if (prod.stockStatus == StockStatus.epuise)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withOpacity(0.5),
                          child: const Center(
                            child: Text('Non disponible',
                                style: TextStyle(color: Colors.white,
                                    fontSize: 20, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Prix
                  Row(children: [
                    Text('${p.prixAffiche.toStringAsFixed(0)} HTG',
                        style: const TextStyle(fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D2B5E))),
                    if (p.hasPromo) ...[
                      const SizedBox(width: 8),
                      Text('${p.prix.toStringAsFixed(0)} HTG',
                          style: const TextStyle(fontSize: 14,
                              color: Color(0xFF999999),
                              decoration: TextDecoration.lineThrough)),
                    ],
                  ]),

                  // Stock bas
                  if (p.stockStatus == StockStatus.faible)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Plus que ${p.stock} en stock !',
                          style: const TextStyle(color: Color(0xFFF5A623),
                              fontWeight: FontWeight.w600)),
                    ),
                  const SizedBox(height: 16),

                  // Sélecteur couleur
                  if (p.couleurs.isNotEmpty) ...[
                    const Text('Couleur', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: p.couleurs.map((c) {
                        final sel = _couleurSelectionnee == c;
                        return GestureDetector(
                          onTap: () => setState(() => _couleurSelectionnee = c),
                          child: Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: Color(int.parse('0xFF${c.replaceAll('#', '')}')),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: sel ? const Color(0xFF0D2B5E) : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Sélecteur taille
                  if (p.tailles.isNotEmpty) ...[
                    const Text('Taille', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: p.tailles.map((t) {
                        final sel = _tailleSelectionnee == t;
                        return GestureDetector(
                          onTap: () => setState(() => _tailleSelectionnee = t),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: sel ? const Color(0xFF0D2B5E) : const Color(0xFFF2F4F8),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: sel
                                  ? const Color(0xFF0D2B5E)
                                  : const Color(0xFFCCCCCC)),
                            ),
                            child: Text(t, style: TextStyle(
                                color: sel ? Colors.white : const Color(0xFF1A1F36),
                                fontWeight: FontWeight.w600)),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Quantité
                  Row(children: [
                    const Text('Quantité', style: TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    IconButton(
                      onPressed: _quantite > 1
                          ? () => setState(() => _quantite--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                      color: const Color(0xFF0D2B5E),
                    ),
                    Text('$_quantite', style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                    IconButton(
                      onPressed: _quantite < p.stock
                          ? () => setState(() => _quantite++)
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                      color: const Color(0xFF0D2B5E),
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // Bouton panier
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectionComplete &&
                                p.stockStatus != StockStatus.epuise
                            ? const Color(0xFF0D2B5E)
                            : const Color(0xFFCCCCCC),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _selectionComplete &&
                              p.stockStatus != StockStatus.epuise
                          ? _ajouterAuPanier
                          : null,
                      child: const Text('Ajouter au panier',
                          style: TextStyle(color: Colors.white,
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),

                  if (!_selectionComplete)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Sélectionnez couleur et taille avant d\'ajouter',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF999999), fontSize: 12)),
                    ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
