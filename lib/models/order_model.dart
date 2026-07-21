/// Modèle commande — Claudimyr CASSIGNOL
/// Branch : feature/cart-orders
/// Path : lib/models/order_model.dart
/// Colonnes Supabase : id, client_id, shop_id, seller_id, total,
///                     statut, adresse_livraison, zone, telephone_client,
///                     note_vendeur, receipt_url, created_at
/// Table liée : order_items (items de la commande)
class OrderModel {
  final String id;
  final String clientId;
  final String shopId;
  final String sellerId;
  final List<OrderItem> items;
  final double total;
  final String statut;
  final String adresseLivraison;
  final String zone;
  final String telephoneClient;
  final String? noteVendeur;
  final String? receiptUrl;
  final DateTime createdAt;

  const OrderModel({
    required this.id,
    required this.clientId,
    required this.shopId,
    required this.sellerId,
    required this.items,
    required this.total,
    required this.statut,
    required this.adresseLivraison,
    required this.zone,
    required this.telephoneClient,
    this.noteVendeur,
    this.receiptUrl,
    required this.createdAt,
  });

  /// Annulation seulement si statut = nouvelle
  bool get peutEtreAnnulee => statut == 'nouvelle';

  /// Label affiché côté client
  String get statutLabel {
    switch (statut) {
      case 'nouvelle':    return 'En attente du vendeur';
      case 'acceptee':    return 'Acceptée';
      case 'preparation': return 'En préparation';
      case 'livraison':   return 'En livraison';
      case 'livree':      return 'Livrée';
      case 'annulee':     return 'Annulée';
      default:            return statut;
    }
  }

  /// Supabase → Dart
  /// Les items viennent de la table order_items (jointure ou séparé)
  factory OrderModel.fromMap(Map<String, dynamic> map, String id,
      {List<OrderItem> items = const []}) {
    return OrderModel(
      id:               map['id'] ?? id,
      clientId:         map['client_id'] ?? '',
      shopId:           map['shop_id'] ?? '',
      sellerId:         map['seller_id'] ?? '',
      items:            items,
      total:            (map['total'] ?? 0.0).toDouble(),
      statut:           map['statut'] ?? 'nouvelle',
      adresseLivraison: map['adresse_livraison'] ?? '',
      zone:             map['zone'] ?? '',
      telephoneClient:  map['telephone_client'] ?? '',
      noteVendeur:      map['note_vendeur'],
      receiptUrl:       map['receipt_url'],
      createdAt:        map['created_at'] != null
                          ? DateTime.parse(map['created_at'])
                          : DateTime.now(),
    );
  }

  /// Dart → Supabase
  Map<String, dynamic> toMap() {
    return {
      'client_id':          clientId,
      'shop_id':            shopId,
      'seller_id':          sellerId,
      'total':              total,
      'statut':             statut,
      'adresse_livraison':  adresseLivraison,
      'zone':               zone,
      'telephone_client':   telephoneClient,
      'note_vendeur':       noteVendeur,
      'receipt_url':        receiptUrl,
      'created_at':         createdAt.toIso8601String(),
    };
  }
}

/// Article d'une commande — table order_items
class OrderItem {
  final String id;
  final String orderId;
  final String productId;
  final String nom;
  final double prix;
  final int quantite;
  final String? couleur;
  final String? taille;

  const OrderItem({
    this.id = '',
    this.orderId = '',
    required this.productId,
    required this.nom,
    required this.prix,
    required this.quantite,
    this.couleur,
    this.taille,
  });

  double get sousTotal => prix * quantite;

  /// Supabase → Dart
  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id:        map['id'] ?? '',
      orderId:   map['order_id'] ?? '',
      productId: map['product_id'] ?? '',
      nom:       map['nom'] ?? '',
      prix:      (map['prix'] ?? 0.0).toDouble(),
      quantite:  map['quantite'] ?? 1,
      couleur:   map['couleur'],
      taille:    map['taille'],
    );
  }

  /// Dart → Supabase
  Map<String, dynamic> toMap() {
    return {
      'order_id':   orderId,
      'product_id': productId,
      'nom':        nom,
      'prix':       prix,
      'quantite':   quantite,
      'couleur':    couleur,
      'taille':     taille,
    };
  }
}
