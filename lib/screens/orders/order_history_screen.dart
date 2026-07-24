import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../models/order_model.dart';
import '../../widgets/order_status_badge.dart';
import '../../widgets/receipt_buttons_widget.dart';
import '../../widgets/review_dialog_widget.dart';

/// Historique commandes — Claudimyr CASSIGNOL
/// Branch : feature/cart-orders
/// Path : lib/screens/orders/order_history_screen.dart
///
/// Liste toutes les commandes passées par le client connecté (StatefulWidget
/// car on doit démarrer un abonnement Realtime/écoute au chargement de
/// l'écran via `initState`). Chaque commande est affichée sous forme de
/// carte (`_OrderCard`) résumant son statut, son total et sa date.
class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  @override
  void initState() {
    super.initState();
    // On récupère l'utilisateur connecté et, s'il existe, on demande au
    // OrderProvider de commencer à "écouter" (probablement un flux
    // Supabase Realtime) toutes les commandes de ce client. `context.read`
    // (et non `watch`) est utilisé ici car on est dans `initState`, un
    // endroit où on ne veut pas se réabonner aux changements du provider —
    // on veut juste déclencher l'action une seule fois.
    final auth = context.read<AuthProvider>();
    if (auth.currentUser != null) {
      context.read<OrderProvider>().listenClientOrders(auth.currentUser!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    // `watch` ici (contrairement à `read` dans initState) : on veut que ce
    // widget se reconstruise automatiquement à chaque fois que la liste
    // `ordresClient` change (nouvelle commande, changement de statut, etc.)
    final orders = context.watch<OrderProvider>().ordresClient;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B5E),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          // context.go() remplace toute la pile de navigation par la route
          // '/client/home' (au lieu de simplement "dépiler" avec pop()) :
          // ça garantit qu'on ne peut pas revenir en arrière vers un état
          // de navigation incohérent depuis l'accueil.
          onPressed: () => context.go('/client/home'),
        ),
        title: const Text('Mes commandes'),
      ),
      // Affiche un état vide illustré s'il n'y a aucune commande, sinon
      // une liste défilante de cartes.
      body: orders.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 60, color: Color(0xFFCCCCCC)),
                  SizedBox(height: 12),
                  Text('Aucune commande pour l\'instant',
                      style: TextStyle(color: Color(0xFF999999))),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              itemBuilder: (_, i) => _OrderCard(order: orders[i]),
            ),
    );
  }
}

// Carte individuelle représentant une commande dans la liste de
// l'historique. Widget "privé" (préfixe `_`) car utilisé uniquement dans ce
// fichier.
class _OrderCard extends StatelessWidget {
  final OrderModel order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Ici on utilise context.push() (et non go()) : on veut EMPILER
      // l'écran de suivi par-dessus l'historique, afin que le bouton
      // retour de l'écran de suivi ramène naturellement l'utilisateur à
      // cette liste de commandes. Contrairement à order_form_screen.dart
      // (qui fait go() après une nouvelle commande, car on ne veut pas
      // pouvoir revenir en arrière sur le formulaire), ici revenir en
      // arrière vers l'historique est le comportement souhaité.
      // Remarque : `vendeurTelephone` est transmis vide car on ne l'a pas
      // sous la main dans l'historique (contrairement à la création de
      // commande) ; le bouton WhatsApp ne s'affichera donc pas sur cet
      // écran de suivi quand on y accède depuis l'historique.
      onTap: () => context.push('/order-tracking',
          extra: {'orderId': order.id, 'vendeurTelephone': ''}),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Commande #${order.id.substring(0, 6).toUpperCase()}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                OrderStatusBadge(statut: order.statut),
              ],
            ),
            const SizedBox(height: 8),
            Text('${order.total.toStringAsFixed(0)} HTG · ${order.zone}',
                style: const TextStyle(color: Color(0xFF666666))),
            const SizedBox(height: 4),
            Text(order.createdAt.toString().substring(0, 10),
                style: const TextStyle(fontSize: 12,
                    color: Color(0xFF999999))),
            // Une fois la commande livrée, on propose deux actions
            // supplémentaires : laisser un avis sur la boutique et
            // télécharger/partager le reçu PDF.
            if (order.statut == 'livree') ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  final clientId = context.read<AuthProvider>().currentUser?.id;
                  if (clientId == null) return;
                  // Ouvre la boîte de dialogue de notation/avis pour la
                  // boutique concernée par cette commande.
                  ReviewDialogWidget.show(context,
                      shopId: order.shopId,
                      clientId: clientId,
                      orderId: order.id);
                },
                icon: const Icon(Icons.star_outline, size: 16),
                label: const Text('Laisser un avis'),
              ),
              // Boutons pour générer/partager le reçu PDF de la commande.
              ReceiptButtonsWidget(orderId: order.id),
            ],
          ],
        ),
      ),
    );
  }
}
