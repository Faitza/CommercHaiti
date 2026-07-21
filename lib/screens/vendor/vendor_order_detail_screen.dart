import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/order_model.dart';
import '../../providers/order_provider.dart';
import '../../widgets/order_status_badge.dart';
import '../../widgets/whatsapp_button_widget.dart';

/// Détail commande Vendeur — Faitza COLAS
/// Branch : feature/vendor-catalog
/// Path : lib/screens/vendor/vendor_order_detail_screen.dart
class VendorOrderDetailScreen extends StatelessWidget {
  final OrderModel order;

  const VendorOrderDetailScreen({super.key, required this.order});

  Future<void> _changerStatut(
      BuildContext context, String newStatut) async {
    await context.read<OrderProvider>().updateStatut(order.id, newStatut);
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            // Statut
            Center(child: OrderStatusBadge(statut: order.statut)),
            const SizedBox(height: 16),

            // Infos client
            _card(children: [
              _row('Téléphone', order.telephoneClient),
              _row('Adresse', order.adresseLivraison),
              _row('Zone', order.zone),
              _row('Total', '${order.total.toStringAsFixed(0)} HTG'),
              if (order.noteVendeur != null)
                _row('Note client', order.noteVendeur!),
            ]),
            const SizedBox(height: 16),

            // Articles
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

            // Bouton WhatsApp
            WhatsAppButtonWidget(telephone: order.telephoneClient,
                label: 'Contacter le client via WhatsApp'),
            const SizedBox(height: 12),

            // Boutons changement statut
            if (order.statut == 'nouvelle') ...[
              _boutonStatut(context, 'Accepter la commande',
                  'acceptee', const Color(0xFF0D2B5E)),
            ],
            if (order.statut == 'acceptee') ...[
              _boutonStatut(context, 'Marquer en préparation',
                  'preparation', const Color(0xFF6B21A8)),
            ],
            if (order.statut == 'preparation') ...[
              _boutonStatut(context, 'Marquer en livraison',
                  'livraison', const Color(0xFF0891B2)),
            ],
            if (order.statut == 'livraison') ...[
              _boutonStatut(context, 'Marquer comme livrée',
                  'livree', const Color(0xFF1D9E75)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _card({required List<Widget> children}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(12)),
        child: Column(children: children),
      );

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

  Widget _boutonStatut(BuildContext ctx, String label,
      String newStatut, Color color) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => _changerStatut(ctx, newStatut),
            child: Text(label,
                style: const TextStyle(color: Colors.white)),
          ),
        ),
      );
}