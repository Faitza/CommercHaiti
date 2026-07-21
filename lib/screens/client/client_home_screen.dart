import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shop_provider.dart';
import '../../models/product_model.dart';
import '../../models/shop_model.dart';

/// Accueil Client — Claudimyr CASSIGNOL
/// Branch : feature/client-home
/// Path : lib/screens/client/client_home_screen.dart
class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  List<ProductModel> _topProduits = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    context.read<ShopProvider>().listenShops();
  }

  Future<void> _loadData() async {
    try {
      final rows = await Supabase.instance.client
          .from('products')
          .select()
          .eq('disponible', true)
          .order('total_commandes', ascending: false)
          .limit(10);

      setState(() {
        _topProduits = rows
            .map((row) => ProductModel.fromMap(row, row['id']))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final shops = context.watch<ShopProvider>().shops;
    final prenom = auth.prenom;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B5E),
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bonjour $prenom,',
                style: const TextStyle(color: Colors.white,
                    fontSize: 14, fontWeight: FontWeight.bold)),
            const Text('que voulez-vous aujourd\'hui ?',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () {},
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher produits ou boutiques...',
                hintStyle: const TextStyle(fontSize: 13),
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bannière promo
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE63946),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('🎉 Promotions du jour !',
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ),

              // Top produits
              _sectionTitle('Produits populaires'),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SizedBox(
                      height: 200,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _topProduits.length,
                        itemBuilder: (_, i) =>
                            _ProduitCard(product: _topProduits[i]),
                      ),
                    ),
              const SizedBox(height: 16),

              // Boutiques ouvertes
              _sectionTitle('Boutiques ouvertes'),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: shops.length,
                itemBuilder: (_, i) => _BoutiqueCard(shop: shops[i]),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Text(t, style: const TextStyle(fontSize: 16,
            fontWeight: FontWeight.bold, color: Color(0xFF0D2B5E))),
      );
}

class _ProduitCard extends StatelessWidget {
  final ProductModel product;
  const _ProduitCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context, '/client/product-shops',
        arguments: product.nom,
      ),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: SizedBox(
                height: 110, width: double.infinity,
                child: product.vignette != null
                    ? Image.network(product.vignette!, fit: BoxFit.cover)
                    : Container(color: const Color(0xFFEEF3FB),
                        child: const Icon(Icons.image_outlined,
                            color: Color(0xFF0D2B5E), size: 40)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.nom, style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('${product.prixAffiche.toStringAsFixed(0)} HTG',
                      style: const TextStyle(color: Color(0xFF0D2B5E),
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoutiqueCard extends StatelessWidget {
  final ShopModel shop;
  const _BoutiqueCard({required this.shop});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context, '/client/boutique',
        arguments: shop,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF0D2B5E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(child: Text(shop.initiales,
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(shop.nom, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('⭐ ${shop.rating.toStringAsFixed(1)} · ${shop.totalAvis} avis',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF666666))),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: shop.isOpen ? const Color(0xFFE8F5EE) : const Color(0xFFFDEAEA),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(shop.isOpen ? 'Ouvert' : 'Fermé',
                  style: TextStyle(
                      color: shop.isOpen ? const Color(0xFF1D9E75) : const Color(0xFFE63946),
                      fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
