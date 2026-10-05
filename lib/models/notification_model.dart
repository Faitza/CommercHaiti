/// Notification affichée dans l'app (table `public.notifications`).
///
/// Les lignes sont créées côté serveur par des triggers Postgres (voir
/// supabase/migration_notifications.sql) : nouvelle commande pour le
/// vendeur, changement de statut pour le client, nouveau produit d'une
/// boutique favorite. La même ligne déclenche aussi l'envoi push.
class NotificationModel {
  final String id;
  // 'nouvelle_commande' | 'statut_commande' | 'nouveau_produit'
  final String type;
  final String titre;
  final String message;
  // order_id / product_id / shop_id selon le type, pour ouvrir le bon écran.
  final Map<String, dynamic> data;
  final bool lu;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.type,
    required this.titre,
    required this.message,
    required this.data,
    required this.lu,
    required this.createdAt,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id:        map['id'] as String,
      type:      map['type'] ?? '',
      titre:     map['titre'] ?? '',
      message:   map['message'] ?? '',
      data:      Map<String, dynamic>.from(map['data'] ?? {}),
      lu:        map['lu'] ?? false,
      createdAt: map['created_at'] != null
                   ? DateTime.parse(map['created_at']).toLocal()
                   : DateTime.now(),
    );
  }
}
