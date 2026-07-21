import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/order_provider.dart';
import '../../models/order_model.dart';
import '../../widgets/order_status_badge.dart';
import '../../widgets/whatsapp_button_widget.dart';

/// Suivi commande — Claudimyr CASSIGNOL
/// Branch : feature/cart-orders
/// Path : lib/screens/orders/order_tracking_screen.dart
class OrderTrackingScreen extends StatelessWidget {
  final String orderId;
  final String vendeurTelephone;

  const OrderTrackingScreen({
    super.key,
    required this.orderId,
    required this.vendeurTelephone,
  });

  static const List<Map<String, String>> _etapes = [
    {'statut': 'nouvelle',    'label': 'En attente du vendeur', 'icon': '🕐'},
    {'statut': 'acceptee',    'label': 'Acceptée',              'icon': '✅'},
    {'statut': 'preparation', 'label': 'En préparation',        'icon': '📦'},
    {'statut': 'livraison',   'label': 'En livraison',          'icon': '🚚'},
    {'statut': 'livree',      'label': 'Livrée',                'icon': '🎉'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B5E),
        foregroundColor: Colors.white,
        title: Text('Commande #${orderId.substring(0, 6).toUpperCase()}'),
      ),
      body: StreamBuilder(
        // Supabase Realtime — statut mis à jour automatiquement
        stream: Supabase.instance.client
            .from('orders')
            .stream(primaryKey: ['id'])
            .eq('id', orderId),
        builder: (context, snapshot) {
          String statutActuel = 'nouvelle';
          bool peutAnnuler = true;

          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            statutActuel = snapshot.data!.first['statut'] ?? 'nouvelle';
            peutAnnuler = statutActuel == 'nouvelle';
          }

          final indexActuel = _etapes
              .indexWhere((e) => e['statut'] == statutActuel);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Statut actuel
                Center(child: OrderStatusBadge(statut: statutActuel)),
                const SizedBox(height: 16),

                // Timeline
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: _etapes.asMap().entries.map((entry) {
                      final i = entry.key;
                      final etape = entry.value;
                      final estPasse = i <= indexActuel;
                      final estActuel = i == indexActuel;

                      return _EtapeItem(
                        label: etape['label']!,
                        icon: etape['icon']!,
                        actif: estPasse,
                        actuel: estActuel,
                        dernier: i == _etapes.length - 1,
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // Bouton WhatsApp vendeur
                if (vendeurTelephone.isNotEmpty)
                  WhatsAppButtonWidget(
                    telephone: vendeurTelephone,
                    label: 'Contacter le vendeur en urgence',
                  ),
                const SizedBox(height: 12),

                // Bouton Annuler
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: peutAnnuler
                      ? OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFE63946)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _confirmerAnnulation(context),
                          child: const Text('Annuler la commande',
                              style: TextStyle(color: Color(0xFFE63946))),
                        )
                      : Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F4F8),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Annulation impossible — commande déjà acceptée',
                            style: TextStyle(color: Color(0xFF999999),
                                fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _confirmerAnnulation(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Annuler la commande ?'),
        content: const Text(
            'Cette action est irréversible. Le vendeur sera informé.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Non, garder'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE63946)),
            onPressed: () async {
              Navigator.pop(context);
              final success = await context
                  .read<OrderProvider>()
                  .cancelOrder(orderId);
              if (success && context.mounted) Navigator.pop(context);
            },
            child: const Text('Oui, annuler',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _EtapeItem extends StatelessWidget {
  final String label;
  final String icon;
  final bool actif;
  final bool actuel;
  final bool dernier;

  const _EtapeItem({
    required this.label,
    required this.icon,
    required this.actif,
    required this.actuel,
    required this.dernier,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: actif
                    ? const Color(0xFF0D2B5E)
                    : const Color(0xFFF2F4F8),
                shape: BoxShape.circle,
                border: Border.all(
                  color: actif
                      ? const Color(0xFF0D2B5E)
                      : const Color(0xFFCCCCCC),
                ),
              ),
              child: Center(child: Text(icon,
                  style: const TextStyle(fontSize: 16))),
            ),
            if (!dernier)
              Container(width: 2, height: 32,
                  color: actif
                      ? const Color(0xFF0D2B5E)
                      : const Color(0xFFCCCCCC)),
          ],
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(label, style: TextStyle(
            fontWeight: actuel ? FontWeight.bold : FontWeight.normal,
            color: actif ? const Color(0xFF0D2B5E) : const Color(0xFF999999),
          )),
        ),
      ],
    );
  }
}
