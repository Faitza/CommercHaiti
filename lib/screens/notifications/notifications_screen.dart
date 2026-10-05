import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../models/notification_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/notification_navigation.dart';

/// Écran Notifications : liste des notifications de l'utilisateur
/// (commandes, nouveaux produits des boutiques favorites). Toucher une
/// notification la marque comme lue et ouvre l'écran concerné.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) context.read<NotificationProvider>().listen(user.id);
  }

  IconData _icone(String type) {
    switch (type) {
      case 'nouvelle_commande':
        return Icons.receipt_long_outlined;
      case 'statut_commande':
        return Icons.local_shipping_outlined;
      case 'nouveau_produit':
        return Icons.new_releases_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _quand(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return "À l'instant";
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} j';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<void> _ouvrir(NotificationModel n) async {
    final provider = context.read<NotificationProvider>();
    final isSeller = context.read<AuthProvider>().isSeller;
    final router = GoRouter.of(context);
    provider.marquerLue(n.id);
    await ouvrirNotification(router,
        type: n.type, data: n.data, isSeller: isSeller);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final provider = context.watch<NotificationProvider>();
    final items = provider.notifications;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(isDark),
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (provider.nonLues > 0)
            TextButton(
              onPressed: provider.toutMarquerLu,
              child: const Text('Tout marquer lu',
                  style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_none,
                        size: 56, color: AppColors.textSecondaryFor(isDark)),
                    const SizedBox(height: 12),
                    Text('Aucune notification pour le moment',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColors.textSecondaryFor(isDark))),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 2),
              itemBuilder: (_, i) {
                final n = items[i];
                return Material(
                  color: n.lu
                      ? AppColors.surface(isDark)
                      : AppColors.accentFor(isDark).withValues(alpha: 0.08),
                  child: ListTile(
                    onTap: () => _ouvrir(n),
                    leading: CircleAvatar(
                      backgroundColor:
                          AppColors.accentFor(isDark).withValues(alpha: 0.12),
                      child: Icon(_icone(n.type),
                          color: AppColors.accentFor(isDark), size: 20),
                    ),
                    title: Text(n.titre,
                        style: TextStyle(
                            color: AppColors.textPrimaryFor(isDark),
                            fontWeight:
                                n.lu ? FontWeight.w500 : FontWeight.w700)),
                    subtitle: Text('${n.message}\n${_quand(n.createdAt)}',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryFor(isDark))),
                    isThreeLine: true,
                    trailing: n.lu
                        ? null
                        : Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                                color: AppColors.red, shape: BoxShape.circle),
                          ),
                  ),
                );
              },
            ),
    );
  }
}
