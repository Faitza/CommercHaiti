/// Modèle boutique — Faitza COLAS
/// Branch : feature/auth-roles
/// Path : lib/models/shop_model.dart
/// Table Supabase : shops
/// Colonnes : id, proprietaire_id, nom, description, logo_url,
///            shop_code, zones_livraison, rating, total_avis, is_open, created_at
class ShopModel {
  final String id;
  final String proprietaireId;
  final String nom;
  final String description;
  final String? logoUrl;
  final String shopCode;
  final List<ZoneLivraison> zonesLivraison;
  final double rating;
  final int totalAvis;
  final bool isOpen;
  final DateTime createdAt;

  const ShopModel({
    required this.id,
    required this.proprietaireId,
    required this.nom,
    required this.description,
    this.logoUrl,
    required this.shopCode,
    required this.zonesLivraison,
    this.rating = 0.0,
    this.totalAvis = 0,
    this.isOpen = true,
    required this.createdAt,
  });

  /// Initiales pour logo par défaut — "Marché Frais" → "MF"
  String get initiales {
    final mots = nom.trim().split(' ').where((m) => m.isNotEmpty).toList();
    if (mots.isEmpty) return '?';
    if (mots.length == 1) return mots[0][0].toUpperCase();
    return (mots[0][0] + mots[1][0]).toUpperCase();
  }

  /// Supabase → Dart
  factory ShopModel.fromMap(Map<String, dynamic> map, String id) {
    return ShopModel(
      id:             map['id'] ?? id,
      proprietaireId: map['proprietaire_id'] ?? '',
      nom:            map['nom'] ?? '',
      description:    map['description'] ?? '',
      logoUrl:        map['logo_url'],
      shopCode:       map['shop_code'] ?? '',
      zonesLivraison: (map['zones_livraison'] as List<dynamic>? ?? [])
                        .map((z) => ZoneLivraison.fromMap(
                              z as Map<String, dynamic>))
                        .toList(),
      rating:         (map['rating'] ?? 0.0).toDouble(),
      totalAvis:      map['total_avis'] ?? 0,
      isOpen:         map['is_open'] ?? true,
      createdAt:      map['created_at'] != null
                        ? DateTime.parse(map['created_at'])
                        : DateTime.now(),
    );
  }

  /// Dart → Supabase
  Map<String, dynamic> toMap() {
    return {
      'proprietaire_id':  proprietaireId,
      'nom':              nom,
      'description':      description,
      'logo_url':         logoUrl,
      'shop_code':        shopCode,
      'zones_livraison':  zonesLivraison.map((z) => z.toMap()).toList(),
      'rating':           rating,
      'total_avis':       totalAvis,
      'is_open':          isOpen,
      'created_at':       createdAt.toIso8601String(),
    };
  }
}

/// Zone de livraison
class ZoneLivraison {
  final String zone;
  final int delaiMin;
  final int delaiMax;

  const ZoneLivraison({
    required this.zone,
    required this.delaiMin,
    required this.delaiMax,
  });

  String get delaiAffiche => '$delaiMin-$delaiMax min';

  factory ZoneLivraison.fromMap(Map<String, dynamic> map) {
    return ZoneLivraison(
      zone:     map['zone'] ?? '',
      delaiMin: map['delai_min'] ?? 30,
      delaiMax: map['delai_max'] ?? 45,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'zone':      zone,
      'delai_min': delaiMin,
      'delai_max': delaiMax,
    };
  }
}