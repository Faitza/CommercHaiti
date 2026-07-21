import 'package:flutter/material.dart';
import '../models/product_model.dart';

/// Carte produit réutilisable — Falexson MERCIVAL
/// Branch : feature/ui-settings
/// Path : lib/widgets/product_card_widget.dart
class ProductCardWidget extends StatelessWidget {
  final ProductModel product;
  final VoidCallback? onTap;

  const ProductCardWidget({
    super.key,
    required this.product,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo + badges
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12)),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: product.vignette != null
                        ? Image.network(product.vignette!,
                            fit: BoxFit.cover)
                        : Container(
                            color: const Color(0xFFEEF3FB),
                            child: const Icon(Icons.image_outlined,
                                color: Color(0xFF0D2B5E), size: 40)),
                  ),
                ),
                // Badge promo
                if (product.hasPromo)
                  Positioned(
                    top: 8, left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE63946),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '-${product.pourcentageReduction}%',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                // Overlay non disponible
                if (product.stockStatus == StockStatus.epuise)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12)),
                      child: Container(
                        color: Colors.black.withOpacity(0.45),
                        child: const Center(
                          child: Text('Non disponible',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // Infos
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.nom,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${product.prixAffiche.toStringAsFixed(0)} HTG',
                        style: const TextStyle(
                            color: Color(0xFF0D2B5E),
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                      if (product.hasPromo) ...[
                        const SizedBox(width: 4),
                        Text(
                          '${product.prix.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF999999),
                              decoration: TextDecoration.lineThrough),
                        ),
                      ],
                    ],
                  ),
                  // Indicateur stock bas
                  if (product.stockStatus == StockStatus.faible)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Plus que ${product.stock} en stock !',
                        style: const TextStyle(
                            color: Color(0xFFF5A623),
                            fontSize: 10,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}