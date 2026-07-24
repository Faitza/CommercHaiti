import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/order_model.dart';
import '../../providers/order_provider.dart';
import '../../widgets/order_status_badge.dart';
import '../../widgets/whatsapp_button_widget.dart';
import '../../widgets/receipt_buttons_widget.dart';

/// Détail commande Vendeur — Faitza COLAS
/// Branch : feature/vendor-catalog
/// Path : lib/screens/vendor/vendor_order_detail_screen.dart
///
/// Ecran affichant le détail d'une commande côté vendeur : informations
/// client, articles commandés, bouton WhatsApp pour contacter le client,
/// bouton de génération de reçu PDF (si livrée), et boutons pour faire
/// avancer le statut de la commande dans le workflow
/// (nouvelle -> acceptée -> préparation -> livraison -> livrée), ou
/// l'annuler. `order` est reçu directement en paramètre du widget (passé
/// via `extra:` du routeur go_router depuis l'écran précédent), donc pas
/// besoin de requête Supabase ici : l'objet OrderModel est déjà chargé.
class VendorOrderDetailScreen extends StatelessWidget {
  // La commande à afficher, transmise par l'écran appelant.
  final OrderModel order;

  const VendorOrderDetailScreen({super.key, required this.order});

  /// Change le statut de la commande via OrderProvider (qui fait un UPDATE
  /// Supabase sur la colonne `statut` de la table `orders`), puis referme
  /// cet écran de détail pour revenir à la liste des commandes.
  Future<void> _changerStatut(
      BuildContext context, String newStatut) async {
    await context.read<OrderProvider>().updateStatut(order.id, newStatut);
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B5E),
        foregroundColor: Colors.white,
        title: Text(
            'Commande #${order.id.substring(0, 6).toUpperCase()}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Si la commande a déjà été traitée (pas "nouvelle" ni
            // "annulée"), on affiche un gros bandeau de confirmation avec
            // une icône et le titre correspondant au statut actuel.
            // Sinon (nouvelle ou annulée), on affiche simplement le badge
            // de statut standard (OrderStatusBadge) centré.
            if (order.statut != 'nouvelle' && order.statut != 'annulee') ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14)),
                child: Column(children: [
                  const Icon(Icons.check_circle,
                      color: Color(0xFF1D9E75), size: 40),
                  const SizedBox(height: 8),
                  Text(_titreStatut(order.statut),
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('Le client a été notifié',
                      style: TextStyle(color: Color(0xFF999999))),
                ]),
              ),
              const SizedBox(height: 16),
            ] else
              Center(child: OrderStatusBadge(statut: order.statut)),
            const SizedBox(height: 16),

            // Infos client : téléphone, adresse et zone de livraison,
            // total de la commande, et éventuelle note laissée par le
            // client. Chaque ligne est affichée via le helper `_row`.
            _card(children: [
              _row('Téléphone', order.telephoneClient),
              _row('Adresse', order.adresseLivraison),
              _row('Zone', order.zone),
              _row('Total', '${order.total.toStringAsFixed(0)} HTG'),
              if (order.noteVendeur != null)
                _row('Note client', order.noteVendeur!),
            ]),
            const SizedBox(height: 16),

            // Articles : liste des produits commandés (nom, quantité,
            // sous-total) — `order.items` est déjà chargé en mémoire dans
            // l'objet OrderModel (pas de requête supplémentaire ici).
            _card(children: order.items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(item.nom)),
                  Text('x${item.quantite}'),
                  const SizedBox(width: 8),
                  Text('${item.sousTotal.toStringAsFixed(0)} HTG',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            )).toList()),
            const SizedBox(height: 16),

            // Bouton WhatsApp : ouvre une conversation WhatsApp
            // pré-remplie vers le numéro du client (voir
            // widgets/whatsapp_button_widget.dart) pour un contact direct.
            WhatsAppButtonWidget(telephone: order.telephoneClient,
                label: 'Contacter le client via WhatsApp'),
            const SizedBox(height: 12),

            // Reçu PDF — BF-030 : uniquement affiché quand la commande est
            // livrée ; permet au vendeur de générer/partager un reçu PDF
            // de la commande (voir widgets/receipt_buttons_widget.dart).
            if (order.statut == 'livree') ...[
              ReceiptButtonsWidget(orderId: order.id),
              const SizedBox(height: 12),
            ],

            // Boutons changement statut — rouge pour l'action principale
            // (maquette). Un seul bouton est visible à la fois, celui qui
            // correspond à l'étape suivante logique du workflow de
            // commande. Chaque bouton appelle `_boutonStatut` qui déclenche
            // `_changerStatut` avec le nouveau statut cible.
            if (order.statut == 'nouvelle') ...[
              _boutonStatut(context, 'Accepter la commande', 'acceptee',
                  icon: Icons.check_circle_outline),
            ],
            if (order.statut == 'acceptee') ...[
              _boutonStatut(context, 'Marquer en préparation', 'preparation',
                  icon: Icons.inventory_2_outlined),
            ],
            if (order.statut == 'preparation') ...[
              _boutonStatut(context, 'Marquer en livraison', 'livraison',
                  icon: Icons.local_shipping_outlined),
            ],
            if (order.statut == 'livraison') ...[
              _boutonStatut(context, 'Marquer comme livrée', 'livree',
                  icon: Icons.celebration_outlined),
            ],
            // Bouton "Annuler la commande" : uniquement disponible tant que
            // la commande n'est pas encore en livraison/livrée (sécurité
            // métier — on ne peut plus annuler une fois le colis parti).
            if (order.statut == 'acceptee' || order.statut == 'preparation')
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFFFCE9E9),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _changerStatut(context, 'annulee'),
                  icon: const Icon(Icons.close, size: 16, color: Color(0xFFE63946)),
                  label: const Text('Annuler la commande',
                      style: TextStyle(color: Color(0xFFE63946))),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Retourne le titre à afficher dans le bandeau de confirmation selon
  /// le statut courant de la commande (simple correspondance texte).
  String _titreStatut(String statut) {
    switch (statut) {
      case 'acceptee': return 'Commande acceptée !';
      case 'preparation': return 'En préparation !';
      case 'livraison': return 'En livraison !';
      case 'livree': return 'Commande livrée !';
      default: return 'Commande mise à jour';
    }
  }

  // Carte blanche générique avec coins arrondis, utilisée pour regrouper
  // des sections d'informations (infos client, liste d'articles, etc.).
  Widget _card({required List<Widget> children}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(12)),
        child: Column(children: children),
      );

  // Ligne "label : valeur" alignée à gauche/droite, utilisée dans la
  // section infos client.
  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFF666666))),
            Flexible(child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600),
                textAlign: TextAlign.right)),
          ],
        ),
      );

  // Bouton d'action pleine largeur pour faire avancer le statut de la
  // commande. `newStatut` est la valeur qui sera écrite en base via
  // `_changerStatut` lors du tap.
  Widget _boutonStatut(BuildContext ctx, String label, String newStatut,
          {required IconData icon}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE63946),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => _changerStatut(ctx, newStatut),
            icon: Icon(icon, color: Colors.white, size: 18),
            label: Text(label,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      );
}