/// Modèle produit — Claudimyr CASSIGNOL
/// Branch : feature/client-home
/// Path : lib/models/product_model.dart
/// Table Supabase : products
/// Colonnes : id, shop_id, nom, prix, prix_promo, photos, stock,
///            categorie, sous_categorie, couleurs, tailles,
///            disponible, total_commandes, created_at
class ProductModel {
  final String id;
  final String shopId;
  final String nom;
  final double prix;
  final double? prixPromo;
  final List<String> photos;
  final int stock;
  final String categorie;
  final String sousCategorie;
  final List<String> couleurs;
  final List<String> tailles;
  final bool disponible;
  final int totalCommandes;
  final DateTime createdAt;

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

  double get prixAffiche => prixPromo ?? prix;
  bool get hasPromo => prixPromo != null && prixPromo! < prix;
  int get pourcentageReduction =>
      hasPromo ? (((prix - prixPromo!) / prix) * 100).round() : 0;
  String? get vignette => photos.isNotEmpty ? photos[0] : null;

  StockStatus get stockStatus {
    if (stock == 0) return StockStatus.epuise;
    if (stock <= 5) return StockStatus.faible;
    return StockStatus.normal;
  }

  /// Supabase → Dart
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
      createdAt:       map['created_at'] != null
                         ? DateTime.parse(map['created_at'])
                         : DateTime.now(),
    );
  }

  /// Dart → Supabase
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

enum StockStatus { normal, faible, epuise }
