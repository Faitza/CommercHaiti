/// Modèle boutique — Faitza COLAS
/// Branch : feature/auth-roles
/// Path : lib/models/shop_model.dart
class ShopModel {
  final String id;
  final String proprietaireId;
  final String nom;
  final String description;
  final String? logoURL;
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
    this.logoURL,
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

  factory ShopModel.fromMap(Map<String, dynamic> map, String id) {
    return ShopModel(
      id: id,
      proprietaireId: map['proprietaireId'] ?? '',
      nom: map['nom'] ?? '',
      description: map['description'] ?? '',
      logoURL: map['logoURL'],
      shopCode: map['shopCode'] ?? '',
      zonesLivraison: (map['zonesLivraison'] as List<dynamic>? ?? [])
          .map((z) => ZoneLivraison.fromMap(z as Map<String, dynamic>))
          .toList(),
      rating: (map['rating'] ?? 0.0).toDouble(),
      totalAvis: map['totalAvis'] ?? 0,
      isOpen: map['isOpen'] ?? true,
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'proprietaireId': proprietaireId,
      'nom': nom,
      'description': description,
      'logoURL': logoURL,
      'shopCode': shopCode,
      'zonesLivraison': zonesLivraison.map((z) => z.toMap()).toList(),
      'rating': rating,
      'totalAvis': totalAvis,
      'isOpen': isOpen,
      'createdAt': createdAt,
    };
  }
}

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
      zone: map['zone'] ?? '',
      delaiMin: map['delaiMin'] ?? 30,
      delaiMax: map['delaiMax'] ?? 45,
    );
  }

  Map<String, dynamic> toMap() {
    return {'zone': zone, 'delaiMin': delaiMin, 'delaiMax': delaiMax};
  }
}