/// Modèle avis — Falexson MERCIVAL
/// Branch : feature/firebase-core
/// Path : lib/models/review_model.dart
/// Table Supabase : reviews
/// Colonnes : id, shop_id, client_id, order_id, note, commentaire, created_at
class ReviewModel {
  final String id;
  final String shopId;
  final String clientId;
  final String orderId;
  final int note;
  final String? commentaire;
  final DateTime createdAt;

  const ReviewModel({
    required this.id,
    required this.shopId,
    required this.clientId,
    required this.orderId,
    required this.note,
    this.commentaire,
    required this.createdAt,
  });

  bool get noteValide => note >= 1 && note <= 5;

  /// Supabase → Dart
  factory ReviewModel.fromMap(Map<String, dynamic> map, String id) {
    return ReviewModel(
      id:          map['id'] ?? id,
      shopId:      map['shop_id'] ?? '',
      clientId:    map['client_id'] ?? '',
      orderId:     map['order_id'] ?? '',
      note:        map['note'] ?? 0,
      commentaire: map['commentaire'],
      createdAt:   map['created_at'] != null
                     ? DateTime.parse(map['created_at'])
                     : DateTime.now(),
    );
  }

  /// Dart → Supabase
  Map<String, dynamic> toMap() {
    return {
      'shop_id':     shopId,
      'client_id':   clientId,
      'order_id':    orderId,
      'note':        note,
      'commentaire': commentaire,
      'created_at':  createdAt.toIso8601String(),
    };
  }
}