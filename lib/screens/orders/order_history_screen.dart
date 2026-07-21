import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../models/order_model.dart';
import '../../widgets/order_status_badge.dart';

/// Historique commandes — Claudimyr CASSIGNOL
/// Branch : feature/cart-orders
/// Path : lib/screens/orders/order_history_screen.dart
class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    if (auth.currentUser != null) {
      context.read<OrderProvider>().listenClientOrders(auth.currentUser!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrderProvider>().ordresClient;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B5E),
        foregroundColor: Colors.white,
        title: const Text('Mes commandes'),
      ),
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

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context, '/order-tracking',
        arguments: {'orderId': order.id, 'vendeurTelephone': ''},
      ),
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
            if (order.statut == 'livree') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(
                    onPressed: () {},
                    child: const Text('Laisser un avis'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {},
                    child: const Text('Télécharger reçu PDF'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
