/// Modèle produit — Claudimyr CASSIGNOL
/// Branch : feature/client-home
/// Path : lib/models/product_model.dart
/// Table Supabase : products
/// Colonnes : id, shop_id, nom, prix, prix_promo, photos, stock,
///            categorie, sous_categorie, couleurs, tailles,
///            disponible, total_commandes, created_at
///
/// Représente UN produit vendu par une boutique (shop). Contient à la
/// fois les informations d'affichage (nom, prix, photos) et les
/// informations de gestion vendeur (stock, disponibilité, statistiques
/// de commandes).
class ProductModel {
  /// Identifiant unique du produit (uuid généré par Supabase).
  final String id;
  /// Identifiant de la boutique propriétaire (référence shops.id).
  final String shopId;
  /// Nom affiché du produit.
  final String nom;
  /// Prix normal (avant promotion).
  final double prix;
  /// Prix promotionnel, s'il y en a un. Nullable : absence de promo.
  final double? prixPromo;
  /// Liste des URLs des photos du produit (galerie).
  final List<String> photos;
  /// Quantité disponible en stock.
  final int stock;
  /// Catégorie principale du produit (ex : "Vêtements").
  final String categorie;
  /// Sous-catégorie du produit (ex : "T-shirts").
  final String sousCategorie;
  /// Couleurs disponibles pour ce produit (liste vide si non applicable).
  final List<String> couleurs;
  /// Tailles disponibles pour ce produit (liste vide si non applicable).
  final List<String> tailles;
  /// Indique si le vendeur a rendu le produit disponible à la vente
  /// (différent du stock : un produit peut avoir du stock mais être
  /// désactivé volontairement par le vendeur).
  final bool disponible;
  /// Compteur de commandes total pour ce produit (utile pour trier les
  /// produits populaires).
  final int totalCommandes;
  /// Date de création du produit.
  final DateTime createdAt;

  /// Constructeur constant. couleurs/tailles/disponible/totalCommandes
  /// ont des valeurs par défaut car tous les produits n'ont pas de
  /// variantes et sont disponibles/à zéro commande par défaut à la création.
  const ProductModel({
    required this.id,
    required this.shopId,
    required this.nom,
    required this.prix,
    this.prixPromo,
    required this.photos,
    required this.stock,
    required this.categorie,
    required this.sousCategorie,
    this.couleurs = const [],
    this.tailles = const [],
    this.disponible = true,
    this.totalCommandes = 0,
    required this.createdAt,
  });

  /// Prix à afficher au client : le prix promo s'il existe, sinon le
  /// prix normal. Évite de dupliquer cette logique dans chaque écran.
  double get prixAffiche => prixPromo ?? prix;

  /// Vrai si le produit est réellement en promotion (un prix promo existe
  /// ET il est strictement inférieur au prix normal — évite d'afficher
  /// un badge promo si prixPromo a été mal saisi égal ou supérieur au prix).
  bool get hasPromo => prixPromo != null && prixPromo! < prix;

  /// Pourcentage de réduction arrondi, calculé seulement si hasPromo est
  /// vrai (sinon 0). Utilisé pour afficher un badge du type "-20%".
  int get pourcentageReduction =>
      hasPromo ? (((prix - prixPromo!) / prix) * 100).round() : 0;

  /// Première photo de la liste, utilisée comme vignette/miniature dans
  /// les listes de produits. Retourne null si aucune photo n'a été
  /// uploadée, pour permettre l'affichage d'un placeholder côté UI.
  String? get vignette => photos.isNotEmpty ? photos[0] : null;

  /// Dérive un statut de stock lisible (épuisé / faible / normal) à
  /// partir du nombre brut en stock. Seuil de "faible" fixé à 5 unités
  /// pour alerter le vendeur avant la rupture totale.
  StockStatus get stockStatus {
    if (stock == 0) return StockStatus.epuise;
    if (stock <= 5) return StockStatus.faible;
    return StockStatus.normal;
  }

  /// Supabase → Dart
  /// Convertit une ligne brute Supabase (snake_case) en objet Dart
  /// typé. Les listes (photos, couleurs, tailles) sont reconstruites
  /// avec List<String>.from(...) car Supabase les renvoie comme
  /// List<dynamic> ; les valeurs manquantes tombent sur des valeurs
  /// par défaut sûres (?? ...) pour éviter les erreurs de type null.
  factory ProductModel.fromMap(Map<String, dynamic> map, String id) {
    return ProductModel(
      id:              map['id'] ?? id,
      shopId:          map['shop_id'] ?? '',
      nom:             map['nom'] ?? '',
      prix:            (map['prix'] ?? 0.0).toDouble(),
      prixPromo:       map['prix_promo']?.toDouble(),
      photos:          List<String>.from(map['photos'] ?? []),
      stock:           map['stock'] ?? 0,
      categorie:       map['categorie'] ?? '',
      sousCategorie:   map['sous_categorie'] ?? '',
      couleurs:        List<String>.from(map['couleurs'] ?? []),
      tailles:         List<String>.from(map['tailles'] ?? []),
      disponible:      map['disponible'] ?? true,
      totalCommandes:  map['total_commandes'] ?? 0,
      // Repli sur l'heure actuelle si created_at est absent de la réponse.
      createdAt:       map['created_at'] != null
                         ? DateTime.parse(map['created_at'])
                         : DateTime.now(),
    );
  }

  /// Dart → Supabase
  /// Convertit cet objet en Map (clés snake_case) prête à être envoyée
  /// à Supabase pour un insert/update de la table products.
  Map<String, dynamic> toMap() {
    return {
      'shop_id':         shopId,
      'nom':             nom,
      'prix':            prix,
      'prix_promo':      prixPromo,
      'photos':          photos,
      'stock':           stock,
      'categorie':       categorie,
      'sous_categorie':  sousCategorie,
      'couleurs':        couleurs,
      'tailles':         tailles,
      'disponible':      disponible,
      'total_commandes': totalCommandes,
      'created_at':      createdAt.toIso8601String(),
    };
  }
}

/// Statuts possibles du stock d'un produit, dérivés du champ `stock` :
/// - normal : plus de 5 unités disponibles
/// - faible : entre 1 et 5 unités (alerte vendeur)
/// - epuise : 0 unité (produit non commandable)
enum StockStatus { normal, faible, epuise }
