/// Modèle commande — Claudimyr CASSIGNOL
/// Branch : feature/cart-orders
/// Path : lib/models/order_model.dart
/// Colonnes Supabase : id, client_id, shop_id, seller_id, total,
///                     statut, adresse_livraison, zone, telephone_client,
///                     note_vendeur, receipt_url, created_at
/// Table liée : order_items (items de la commande)
///
/// Représente UNE commande passée par un client dans une boutique.
/// Une commande contient une liste d'articles (OrderItem, définie plus bas
/// dans ce même fichier) qui viennent d'une table séparée order_items,
/// car une commande peut contenir plusieurs produits différents.
class OrderModel {
  /// Identifiant unique de la commande (uuid généré par Supabase).
  final String id;
  /// Identifiant du client qui a passé la commande (référence users.id).
  final String clientId;
  /// Identifiant de la boutique concernée (référence shops.id).
  final String shopId;
  /// Identifiant du vendeur (propriétaire de la boutique) qui doit traiter
  /// la commande. Dupliqué depuis shops.proprietaire_id pour simplifier
  /// les requêtes côté vendeur (pas besoin de jointure).
  final String sellerId;
  /// Liste des articles commandés (chargée séparément depuis order_items).
  final List<OrderItem> items;
  /// Montant total de la commande (somme des sous-totaux des articles).
  final double total;
  /// Statut courant de la commande : 'nouvelle', 'acceptee', 'preparation',
  /// 'livraison', 'livree' ou 'annulee'. Contrôle le workflow vendeur/client.
  final String statut;
  /// Adresse de livraison saisie par le client au moment de la commande.
  final String adresseLivraison;
  /// Zone de livraison (utilisée pour estimer le délai de livraison).
  final String zone;
  /// Numéro de téléphone du client, pour que le vendeur puisse le contacter.
  final String telephoneClient;
  /// Note laissée par le vendeur (optionnelle) — ex : instructions internes.
  final String? noteVendeur;
  /// URL du reçu/preuve de paiement (optionnel, uploadé sur Supabase Storage).
  final String? receiptUrl;
  /// Date/heure de création de la commande.
  final DateTime createdAt;

  /// Constructeur constant — tous les champs sont requis sauf noteVendeur
  /// et receiptUrl qui ne sont pas toujours renseignés.
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
  /// Une commande ne peut être annulée par le client que tant que le
  /// vendeur ne l'a pas encore acceptée (sinon la préparation a déjà
  /// pu commencer côté boutique).
  bool get peutEtreAnnulee => statut == 'nouvelle';

  /// Label affiché côté client
  /// Traduit le code technique du statut (stocké en base) en un libellé
  /// lisible par l'utilisateur final dans l'interface.
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
  /// Convertit une ligne brute renvoyée par Supabase (Map avec des clés
  /// snake_case) en un objet OrderModel Dart fortement typé. Les valeurs
  /// nulles/absentes sont protégées par des valeurs par défaut (?? ...)
  /// pour éviter les crashs si une colonne manque dans la réponse.
  /// Le paramètre `items` est optionnel car les items sont récupérés par
  /// une requête séparée sur order_items (pas de jointure automatique ici).
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
      // Si created_at est absent (nouvelle commande pas encore relue
      // depuis la base), on utilise l'heure actuelle comme repli.
      createdAt:        map['created_at'] != null
                          ? DateTime.parse(map['created_at'])
                          : DateTime.now(),
    );
  }

  /// Dart → Supabase
  /// Convertit cet objet Dart en Map (clés snake_case) prête à être
  /// insérée/mise à jour dans la table `orders`. Notez que `items` n'est
  /// PAS inclus ici car les articles sont insérés séparément dans la
  /// table order_items (relation one-to-many).
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
/// Représente UNE ligne d'article à l'intérieur d'une commande (produit,
/// quantité, prix au moment de la commande, variante couleur/taille).
/// Le prix et le nom sont dupliqués ici (plutôt que de simplement
/// référencer ProductModel) car le produit peut changer de prix ou être
/// supprimé après coup — la commande doit garder une trace figée de ce
/// qui a été acheté au moment de l'achat.
class OrderItem {
  /// Identifiant de la ligne dans order_items (uuid). Vide par défaut
  /// tant que la ligne n'a pas encore été insérée en base.
  final String id;
  /// Identifiant de la commande parente (référence orders.id). Vide par
  /// défaut car rempli seulement après la création de la commande.
  final String orderId;
  /// Identifiant du produit commandé (référence products.id).
  final String productId;
  /// Nom du produit au moment de la commande (copie figée, indépendante
  /// d'un éventuel renommage futur du produit).
  final String nom;
  /// Prix unitaire au moment de la commande (copie figée du prix affiché).
  final double prix;
  /// Quantité commandée pour ce produit/variante.
  final int quantite;
  /// Couleur choisie, si applicable.
  final String? couleur;
  /// Taille choisie, si applicable.
  final String? taille;

  /// Constructeur constant. id et orderId ont une valeur par défaut vide
  /// car ils ne sont connus qu'après insertion en base (générés côté
  /// serveur/DB), contrairement aux autres champs saisis avant l'envoi.
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

  /// Sous-total de cette ligne = prix unitaire figé × quantité.
  double get sousTotal => prix * quantite;

  /// Supabase → Dart
  /// Convertit une ligne brute de la table order_items en objet Dart.
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
  /// Convertit cet article en Map prête à être insérée dans order_items.
  /// Le champ `id` n'est pas inclus car il est généré automatiquement par
  /// Supabase (clé primaire auto-générée) lors de l'insertion.
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
