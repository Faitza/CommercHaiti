import 'package:flutter/material.dart';
import '../models/order_model.dart';

/// Rendu visuel du reçu — utilisé pour la capture en image (PNG) à
/// partager sur WhatsApp, en complément du reçu PDF (BF-030).
/// Path : lib/widgets/receipt_image_widget.dart
///
/// IMPORTANT : ce widget n'est JAMAIS affiché directement à l'écran comme
/// une page normale. Il est dessiné hors-écran par `ReceiptButtonsWidget`
/// (voir receipt_buttons_widget.dart) puis "photographié" via un
/// RepaintBoundary pour produire une image PNG partageable sur WhatsApp —
/// WhatsApp affiche mieux une image qu'un PDF en aperçu de conversation.
/// Sa mise en page est donc pensée comme une image fixe de largeur 360px
/// (largeur d'écran de téléphone typique), pas comme un widget responsive.
class ReceiptImageWidget extends StatelessWidget {
  // Commande complète (avec ses articles) à afficher sur le reçu.
  final OrderModel order;
  // Nom de la boutique, affiché en en-tête.
  final String shopNom;

  const ReceiptImageWidget({
    super.key,
    required this.order,
    required this.shopNom,
  });

  @override
  Widget build(BuildContext context) {
    // `Material` est nécessaire même hors d'un Scaffold classique car ce
    // widget est inséré directement dans un Overlay (voir
    // receipt_buttons_widget.dart) : sans ancêtre Material, certains
    // widgets Material Design (Text avec styles par défaut, etc.)
    // lèveraient une erreur ou s'afficheraient mal.
    return Material(
      color: Colors.white,
      child: Container(
        // Largeur fixe en pixels logiques : le reçu doit avoir une taille
        // cohérente quel que soit l'appareil, puisqu'il sera exporté en
        // image PNG et non affiché "en vrai" à l'écran.
        width: 360,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── En-tête : icône panier + nom boutique + sous-titre ──
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE63946),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.shopping_cart,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shopNom,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D2B5E))),
                    const Text('CommercHaiti — Reçu de commande',
                        style: TextStyle(fontSize: 10, color: Color(0xFF999999))),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFE0E0E0)),
            const SizedBox(height: 14),
            // ── Informations générales de la commande ──
            _ligne('N° commande', '#${order.id.substring(0, 6).toUpperCase()}'),
            _ligne('Date', _formatDate(order.createdAt)),
            _ligne('Client', order.telephoneClient),
            _ligne('Adresse', order.adresseLivraison),
            _ligne('Zone', order.zone),
            const SizedBox(height: 14),
            // ── Liste des articles commandés (générée dynamiquement) ──
            const Text('Articles',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text('${item.nom}  ×${item.quantite}',
                            style: const TextStyle(fontSize: 12)),
                      ),
                      Text('${item.sousTotal.toStringAsFixed(0)} HTG',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                )),
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFE0E0E0)),
            const SizedBox(height: 10),
            // ── Total de la commande, mis en évidence ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text('${order.total.toStringAsFixed(0)} HTG',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF0D2B5E))),
              ],
            ),
            const SizedBox(height: 4),
            // Mode de paiement fixe (l'app ne gère que le paiement cash à
            // la livraison, comme dans receipt_service.dart).
            const Align(
              alignment: Alignment.centerRight,
              child: Text('Paiement à la livraison',
                  style: TextStyle(fontSize: 10, color: Color(0xFF999999))),
            ),
            const SizedBox(height: 16),
            // ── Pied de page : message de remerciement ──
            const Center(
              child: Text('Merci d\'avoir commandé sur CommercHaiti !',
                  style: TextStyle(fontSize: 10, color: Color(0xFF999999))),
            ),
          ],
        ),
      ),
    );
  }

  /// Helper : ligne "label / valeur" (ex. "Client" à gauche, le numéro à
  /// droite). `Flexible` sur la valeur permet au texte de passer à la
  /// ligne ou de se réduire si l'adresse/le contenu est trop long pour la
  /// largeur fixe de 360px du reçu.
  Widget _ligne(String label, String valeur) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(
                fontSize: 12, color: Color(0xFF666666))),
            Flexible(
              child: Text(valeur,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  /// Formate une date au format jour/mois/année avec zéros de tête
  /// (identique à la version utilisée dans receipt_service.dart, pour que
  /// le reçu PDF et le reçu image affichent la même date de la même
  /// façon).
  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
