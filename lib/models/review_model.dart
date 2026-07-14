/// Modèle avis — Falexson MERCIVAL
/// Branch : feature/firebase-core
/// Path : lib/models/review_model.dart
/// Collection Firestore : reviews/{rid}
/// Règle : 1 avis par commande seulement (orderId unique)
class ReviewModel {
  final String id;
  final String shopId;
  final String clientId;
  final String orderId;  // 1 avis par commande seulement
  final int note;        // 1 à 5 étoiles
  final String? commentaire; // optionnel
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

  /// Vérifie si la note est valide (1 à 5)
  bool get noteValide => note >= 1 && note <= 5;

  /// Firestore → Dart
  factory ReviewModel.fromMap(Map<String, dynamic> map, String id) {
    return ReviewModel(
      id: id,
      shopId: map['shopId'] ?? '',
      clientId: map['clientId'] ?? '',
      orderId: map['orderId'] ?? '',
      note: map['note'] ?? 0,
      commentaire: map['commentaire'],
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
    );
  }

  /// Dart → Firestore
  Map<String, dynamic> toMap() {
    return {
      'shopId': shopId,
      'clientId': clientId,
      'orderId': orderId,
      'note': note,
      'commentaire': commentaire,
      'createdAt': createdAt,
    };
  }

  @override
  String toString() =>
      'ReviewModel(shopId: $shopId, note: $note, orderId: $orderId)';
}