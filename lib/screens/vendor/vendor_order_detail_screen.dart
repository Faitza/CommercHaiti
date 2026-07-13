import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Détail commande Vendeur — Faitza COLAS
/// Branch : feature/vendor-catalog
/// Path : lib/screens/vendor/vendor_order_detail_screen.dart
class VendorOrderDetailScreen extends StatelessWidget {
  final String orderId;
  final String clientTelephone;
  final String clientNom;
  final String statut;

  const VendorOrderDetailScreen({
    super.key,
    required this.orderId,
    required this.clientTelephone,
    required this.clientNom,
    required this.statut,
  });

  Future<void> _contacterWhatsApp() async {
    final numero = clientTelephone.replaceAll(RegExp(r'[^\d+]'), '');
    final url = Uri.parse('https://wa.me/$numero');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  Future<void> _changerStatut(BuildContext context, String newStatut) async {
    // TODO : FirestoreService.updateOrderStatus(orderId, newStatut)
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B5E),
        foregroundColor: Colors.white,
        title: Text('Commande #${orderId.substring(0, 6).toUpperCase()}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Infos client (limitées — confidentialité)
            _card(children: [
              _row('Client', clientNom),
              _row('Téléphone', clientTelephone),
              _row('Statut', statut),
            ]),
            const SizedBox(height: 16),

            // TODO : afficher items commande

            // Bouton WhatsApp
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.chat, color: Colors.white),
                label: const Text('Contacter le client via WhatsApp',
                    style: TextStyle(color: Colors.white)),
                onPressed: _contacterWhatsApp,
              ),
            ),
            const SizedBox(height: 16),

            // Boutons changement statut
            if (statut == 'En attente du vendeur') ...[
              _boutonStatut(context, 'Accepter la commande', 'acceptee',
                  const Color(0xFF0D2B5E)),
            ],
            if (statut == 'Acceptée') ...[
              _boutonStatut(context, 'Marquer en préparation', 'preparation',
                  const Color(0xFF6B21A8)),
            ],
            if (statut == 'En préparation') ...[
              _boutonStatut(context, 'Marquer en livraison', 'livraison',
                  const Color(0xFF0891B2)),
            ],
            if (statut == 'En livraison') ...[
              _boutonStatut(context, 'Marquer comme livrée', 'livree',
                  const Color(0xFF1D9E75)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _card({required List<Widget> children}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: children),
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(color: Color(0xFF666666))),
            Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600)),
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