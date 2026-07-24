import 'package:flutter/material.dart';
import '../models/product_model.dart';

/// Carte produit réutilisable — Falexson MERCIVAL
/// Branch : feature/ui-settings
/// Path : lib/widgets/product_card_widget.dart
///
/// Widget "carte" affichant un produit dans une grille (catalogue,
/// résultats de recherche, page boutique...) : photo, badge promo
/// éventuel, overlay "Non disponible" si le produit ne peut pas être
/// commandé, nom, prix (avec prix barré si promo), et alerte de stock bas.
class ProductCardWidget extends StatelessWidget {
  // Le produit à afficher (contient nom, prix, stock, image, etc.).
  final ProductModel product;
  // Callback appelé au clic sur la carte (ex. ouvrir la fiche détaillée
  // du produit) ; optionnel pour permettre un affichage non cliquable.
  final VoidCallback? onTap;

  const ProductCardWidget({
    super.key,
    required this.product,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // GestureDetector englobe toute la carte pour la rendre cliquable ;
    // Container donne le fond blanc, les coins arrondis et une légère
    // ombre portée pour un effet "carte" surélevée.
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
            // Photo + badges — Expanded (pa AspectRatio fiks) pou l pran
            // rès espas selil gri a bay, e pou tèks anba a pa janm debòde
            // (BOTTOM OVERFLOWED) lè non an long oswa gen pwomo/stock ba.
            // (Traduction : la zone photo utilise Expanded plutôt qu'un
            // ratio fixe pour occuper tout l'espace restant laissé par la
            // cellule de la grille, afin que le texte en dessous ne
            // déborde jamais (erreur "BOTTOM OVERFLOWED") quand le nom du
            // produit est long ou qu'il y a une promo/alerte de stock.)
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Image du produit (ou icône placeholder grise si aucune
                  // vignette n'est disponible), coins du haut arrondis
                  // pour épouser la forme de la carte.
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12)),
                    child: product.vignette != null
                        ? Image.network(product.vignette!,
                            fit: BoxFit.cover)
                        : Container(
                            color: const Color(0xFFEEF3FB),
                            child: const Icon(Icons.image_outlined,
                                color: Color(0xFF0D2B5E), size: 40)),
                  ),
                // Badge promo — affiché uniquement si le produit a une
                // réduction active, en haut à gauche de la photo, avec le
                // pourcentage de réduction.
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
                // Overlay non disponible (stock épuisé OU désactivé par le vendeur — BF-019)
                // Assombrit toute la photo et affiche "Non disponible" si
                // le vendeur a désactivé le produit OU si le stock est à
                // zéro — dans les deux cas, le client ne doit pas pouvoir
                // le commander, d'où ce voile visuel superposé (opacity 0.45).
                if (!product.disponible ||
                    product.stockStatus == StockStatus.epuise)
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
            ),

            // Infos
            // ── Zone texte sous la photo : nom, prix, alerte stock ──
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nom du produit, limité à 2 lignes ; si plus long, le
                  // texte est coupé avec "..." (ellipsis) pour ne jamais
                  // faire déborder la carte.
                  Text(product.nom,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  // Prix affiché (déjà réduit si promo) en gras bleu marine,
                  // suivi du prix original barré si une promotion est active
                  // — permet au client de voir immédiatement l'économie.
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
                  // N'apparaît que si le statut calculé du stock est
                  // "faible" (quelques unités restantes mais pas épuisé) —
                  // incite le client à commander rapidement.
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