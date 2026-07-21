import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/shop_provider.dart';
import '../../models/shop_model.dart';

/// Liste boutiques — Claudimyr CASSIGNOL
/// Branch : feature/client-home
/// Path : lib/screens/client/boutiques_screen.dart
class BoutiquesScreen extends StatefulWidget {
  const BoutiquesScreen({super.key});

  @override
  State<BoutiquesScreen> createState() => _BoutiquesScreenState();
}

class _BoutiquesScreenState extends State<BoutiquesScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ShopProvider>().listenShops();
  }

  @override
  Widget build(BuildContext context) {
    final shopProvider = context.watch<ShopProvider>();
    final shops = shopProvider.shopsFiltres;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B5E),
        foregroundColor: Colors.white,
        title: const Text('Boutiques'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFiltres(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: Text('${shops.length} boutique(s) disponible(s)',
                style: const TextStyle(color: Color(0xFF666666), fontSize: 13)),
          ),
          shopProvider.isLoading
              ? const Expanded(
                  child: Center(child: CircularProgressIndicator()))
              : shops.isEmpty
                  ? const Expanded(
                      child: Center(
                        child: Text('Aucune boutique disponible',
                            style: TextStyle(color: Color(0xFF999999))),
                      ))
                  : Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: shops.length,
                        itemBuilder: (_, i) => _BoutiqueItem(shop: shops[i]),
                      ),
                    ),
        ],
      ),
    );
  }

  void _showFiltres(BuildContext context) {
    final shopProvider = context.read<ShopProvider>();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filtres', style: TextStyle(fontSize: 18,
                fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Zone de livraison',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['Cayes Centre', 'Cayes Nord', 'Cayes Sud',
                'Torbeck', 'Camp-Perrin'].map((zone) =>
                ChoiceChip(
                  label: Text(zone),
                  selected: shopProvider.shopsFiltres.isNotEmpty,
                  onSelected: (_) {
                    shopProvider.setFiltreZone(zone);
                    Navigator.pop(context);
                  },
                )).toList(),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                shopProvider.clearFiltre();
                Navigator.pop(context);
              },
              child: const Text('Effacer filtres'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoutiqueItem extends StatelessWidget {
  final ShopModel shop;
  const _BoutiqueItem({required this.shop});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context, '/client/boutique', arguments: shop),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF0D2B5E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: shop.logoUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(shop.logoUrl!, fit: BoxFit.cover))
                  : Center(child: Text(shop.initiales,
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold, fontSize: 18))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(shop.nom, style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(shop.description, maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12,
                          color: Color(0xFF666666))),
                  const SizedBox(height: 4),
                  Text('⭐ ${shop.rating.toStringAsFixed(1)} · ${shop.totalAvis} avis',
                      style: const TextStyle(fontSize: 12,
                          color: Color(0xFF666666))),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: shop.isOpen
                    ? const Color(0xFFE8F5EE)
                    : const Color(0xFFFDEAEA),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(shop.isOpen ? 'Ouvert' : 'Fermé',
                  style: TextStyle(
                      color: shop.isOpen
                          ? const Color(0xFF1D9E75)
                          : const Color(0xFFE63946),
                      fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
