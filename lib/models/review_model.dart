/// Modèle avis — Falexson MERCIVAL
/// Branch : feature/firebase-core
/// Path : lib/models/review_model.dart
/// Table Supabase : reviews
/// Colonnes : id, shop_id, client_id, order_id, note, commentaire, created_at
///
/// Représente UN avis laissé par un client sur une boutique, à la suite
/// d'une commande. Chaque avis est lié à la fois à la boutique notée, au
/// client qui a écrit l'avis et à la commande qui justifie cet avis
/// (empêche par exemple un client de noter une boutique sans y avoir
/// jamais commandé).
class ReviewModel {
  /// Identifiant unique de l'avis (uuid généré par Supabase).
  final String id;
  /// Identifiant de la boutique notée (référence shops.id).
  final String shopId;
  /// Identifiant du client auteur de l'avis (référence users.id).
  final String clientId;
  /// Identifiant de la commande associée (référence orders.id) — sert de
  /// preuve que l'avis vient bien d'un achat réel.
  final String orderId;
  /// Note donnée par le client, attendue entre 1 et 5 étoiles.
  final int note;
  /// Commentaire textuel optionnel laissé par le client.
  final String? commentaire;
  /// Date de création de l'avis.
  final DateTime createdAt;

  /// Constructeur constant — tous les champs requis sauf le commentaire
  /// qui est optionnel (un client peut noter sans écrire de texte).
  const ReviewModel({
    required this.id,
    required this.shopId,
    required this.clientId,
    required this.orderId,
    required this.note,
    this.commentaire,
    required this.createdAt,
  });

  /// Vérifie que la note respecte la plage attendue (1 à 5). Utile côté
  /// UI/validation pour détecter une donnée corrompue ou un bug de saisie
  /// avant d'afficher ou d'agréger les notes.
  bool get noteValide => note >= 1 && note <= 5;

  /// Supabase → Dart
  /// Convertit une ligne brute Supabase (snake_case) en objet Dart typé.
  /// Valeurs par défaut sûres si des champs sont absents de la réponse.
  factory ReviewModel.fromMap(Map<String, dynamic> map, String id) {
    return ReviewModel(
      id:          map['id'] ?? id,
      shopId:      map['shop_id'] ?? '',
      clientId:    map['client_id'] ?? '',
      orderId:     map['order_id'] ?? '',
      note:        map['note'] ?? 0,
      commentaire: map['commentaire'],
      // Repli sur l'heure actuelle si created_at est absent.
      createdAt:   map['created_at'] != null
                     ? DateTime.parse(map['created_at'])
                     : DateTime.now(),
    );
  }

  /// Dart → Supabase
  /// Convertit cet avis en Map (clés snake_case) prête à être insérée
  /// dans la table reviews.
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
