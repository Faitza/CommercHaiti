/// Modèle boutique — Faitza COLAS
/// Branch : feature/auth-roles
/// Path : lib/models/shop_model.dart
/// Table Supabase : shops
/// Colonnes : id, proprietaire_id, nom, description, logo_url,
///            shop_code, zones_livraison, categories, rating, total_avis,
///            is_open, horaire_ouverture, horaire_fermeture,
///            jours_ouverture, is_open_manuel, created_at
///
/// Représente UNE boutique créée par un vendeur. Contient les infos
/// d'identité de la boutique (nom, logo, description), son code unique
/// (utilisé pour que les clients la retrouvent facilement), ses zones de
/// livraison desservies et ses statistiques de réputation (rating, avis).
class ShopModel {
  /// Identifiant unique de la boutique (uuid généré par Supabase).
  final String id;
  /// Identifiant de l'utilisateur vendeur propriétaire (référence users.id).
  final String proprietaireId;
  /// Nom affiché de la boutique.
  final String nom;
  /// Description de la boutique (présentation, type de produits, etc.).
  final String description;
  /// URL du logo de la boutique. Nullable : la boutique peut ne pas
  /// encore avoir uploadé de logo (voir getter `initiales` ci-dessous).
  final String? logoUrl;
  /// Code unique lisible de la boutique (ex : "MFL-2026-4892"), généré
  /// à la création (voir AuthProvider.generateShopCode).
  final String shopCode;
  /// Liste des zones de livraison desservies par la boutique, chacune
  /// avec son délai estimé (voir ZoneLivraison plus bas).
  final List<ZoneLivraison> zonesLivraison;
  /// Catégories vendues par la boutique (ex : ["Alimentation", "Beauté"]),
  /// choisies parmi `Categories.toutes` (voir constants/categories.dart).
  /// Limite les catégories proposées à l'ajout d'un produit.
  final List<String> categories;
  /// Note moyenne de la boutique (calculée à partir des avis clients).
  final double rating;
  /// Nombre total d'avis reçus par la boutique.
  final int totalAvis;
  /// Valeur brute de la colonne `is_open`. Utilisée seulement en repli,
  /// pour une boutique qui n'a pas encore d'horaire (voir `isOpen`).
  final bool isOpenBase;
  /// Heure d'ouverture "HH:mm" (colonne TIME `horaire_ouverture`).
  final String? horaireOuverture;
  /// Heure de fermeture "HH:mm" (colonne TIME `horaire_fermeture`).
  final String? horaireFermeture;
  /// Jours de travail, parmi `ShopModel.joursSemaine` (colonne TEXT[]
  /// `jours_ouverture`).
  final List<String> joursOuverture;
  /// Forçage manuel par le vendeur (colonne `is_open_manuel`) :
  /// true = "Ouvrir maintenant", false = "Fermer maintenant",
  /// null = statut calculé automatiquement selon l'horaire.
  final bool? isOpenManuel;
  /// Date de création de la boutique.
  final DateTime createdAt;

  /// Constructeur constant. rating/totalAvis/isOpenBase ont des valeurs
  /// par défaut car une boutique fraîchement créée n'a encore aucun avis
  /// et est ouverte par défaut.
  const ShopModel({
    required this.id,
    required this.proprietaireId,
    required this.nom,
    required this.description,
    this.logoUrl,
    required this.shopCode,
    required this.zonesLivraison,
    this.categories = const [],
    this.rating = 0.0,
    this.totalAvis = 0,
    this.isOpenBase = true,
    this.horaireOuverture,
    this.horaireFermeture,
    this.joursOuverture = const [],
    this.isOpenManuel,
    required this.createdAt,
  });

  /// Jours proposés au vendeur (Lundi à Samedi), indexés comme
  /// `DateTime.weekday` (1 = lundi).
  static const List<String> joursSemaine = [
    'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi',
  ];

  /// La boutique a-t-elle un horaire complet (heures + au moins un jour) ?
  bool get aUnHoraire =>
      horaireOuverture != null &&
      horaireFermeture != null &&
      joursOuverture.isNotEmpty;

  /// Statut ouvert/fermé affiché partout dans l'app, calculé à l'heure
  /// actuelle de l'appareil (voir `estOuverteA`).
  bool get isOpen => estOuverteA(DateTime.now());

  /// Calcule si la boutique est ouverte à l'instant `t` :
  ///  1. un forçage manuel (`isOpenManuel`) l'emporte toujours ;
  ///  2. sinon, si un horaire existe : ouverte si `t` tombe un jour de
  ///     travail entre l'heure d'ouverture et celle de fermeture. Si la
  ///     fermeture est avant l'ouverture (ex : 18:00 → 02:00), l'horaire
  ///     passe minuit et la fin de nuit compte pour le jour précédent ;
  ///  3. sinon, repli sur la colonne `is_open`.
  bool estOuverteA(DateTime t) {
    if (isOpenManuel != null) return isOpenManuel!;
    if (!aUnHoraire) return isOpenBase;

    final ouverture = _minutes(horaireOuverture!);
    final fermeture = _minutes(horaireFermeture!);
    if (ouverture == null || fermeture == null) return isOpenBase;
    final maintenant = t.hour * 60 + t.minute;
    bool travaille(int weekday) =>
        weekday >= 1 &&
        weekday <= joursSemaine.length &&
        joursOuverture.contains(joursSemaine[weekday - 1]);

    if (ouverture < fermeture) {
      return travaille(t.weekday) &&
          maintenant >= ouverture &&
          maintenant < fermeture;
    }
    // Horaire qui passe minuit.
    final veille = t.weekday == 1 ? 7 : t.weekday - 1;
    return (travaille(t.weekday) && maintenant >= ouverture) ||
        (travaille(veille) && maintenant < fermeture);
  }

  /// "08:00" ou "08:00:00" (format TIME Postgres) → minutes depuis minuit.
  static int? _minutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  /// "08:00:00" → "08:00" (affichage).
  static String? _hhmm(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    return s.length >= 5 ? s.substring(0, 5) : s;
  }

  /// Initiales pour logo par défaut — "Marché Frais" → "MF"
  /// Sert de remplacement visuel (avatar texte) quand logoUrl est null.
  /// Découpe le nom en mots, ignore les espaces multiples, puis prend la
  /// première lettre du premier mot (et du deuxième s'il existe).
  String get initiales {
    final mots = nom.trim().split(' ').where((m) => m.isNotEmpty).toList();
    // Nom vide/uniquement espaces : repli sur un point d'interrogation.
    if (mots.isEmpty) return '?';
    // Un seul mot : on ne peut prendre qu'une seule initiale.
    if (mots.length == 1) return mots[0][0].toUpperCase();
    // Au moins deux mots : initiales des deux premiers, en majuscules.
    return (mots[0][0] + mots[1][0]).toUpperCase();
  }

  /// Supabase → Dart
  /// Convertit une ligne brute Supabase (snake_case) en objet Dart typé.
  factory ShopModel.fromMap(Map<String, dynamic> map, String id) {
    return ShopModel(
      id:             map['id'] ?? id,
      proprietaireId: map['proprietaire_id'] ?? '',
      nom:            map['nom'] ?? '',
      description:    map['description'] ?? '',
      logoUrl:        map['logo_url'],
      shopCode:       map['shop_code'] ?? '',
      // zones_livraison est stocké côté Supabase comme un tableau JSON ;
      // on le caste en List<dynamic> puis on convertit chaque élément
      // (Map) en objet ZoneLivraison via son propre fromMap.
      zonesLivraison: (map['zones_livraison'] as List<dynamic>? ?? [])
                        .map((z) => ZoneLivraison.fromMap(
                              z as Map<String, dynamic>))
                        .toList(),
      categories:     List<String>.from(map['categories'] ?? const []),
      rating:         (map['rating'] ?? 0.0).toDouble(),
      totalAvis:      map['total_avis'] ?? 0,
      isOpenBase:     map['is_open'] ?? true,
      horaireOuverture: _hhmm(map['horaire_ouverture']),
      horaireFermeture: _hhmm(map['horaire_fermeture']),
      joursOuverture: List<String>.from(map['jours_ouverture'] ?? const []),
      isOpenManuel:   map['is_open_manuel'],
      // Repli sur l'heure actuelle si created_at est absent.
      createdAt:      map['created_at'] != null
                        ? DateTime.parse(map['created_at'])
                        : DateTime.now(),
    );
  }

  /// Dart → Supabase
  /// Convertit cet objet en Map (clés snake_case) prête à être envoyée
  /// à Supabase. zonesLivraison est reconverti en liste de Map via le
  /// toMap() de chaque ZoneLivraison (pour être sérialisable en JSON).
  Map<String, dynamic> toMap() {
    return {
      'proprietaire_id':  proprietaireId,
      'nom':              nom,
      'description':      description,
      'logo_url':         logoUrl,
      'shop_code':        shopCode,
      'zones_livraison':  zonesLivraison.map((z) => z.toMap()).toList(),
      'categories':       categories,
      'rating':           rating,
      'total_avis':       totalAvis,
      'is_open':          isOpenBase,
      'horaire_ouverture': horaireOuverture,
      'horaire_fermeture': horaireFermeture,
      'jours_ouverture':  joursOuverture,
      'is_open_manuel':   isOpenManuel,
      'created_at':       createdAt.toIso8601String(),
    };
  }
}

/// Zone de livraison
/// Représente une zone géographique desservie par une boutique, avec
/// un délai de livraison estimé (fourchette min/max en minutes).
class ZoneLivraison {
  /// Nom de la zone (ex : "Pétion-Ville").
  final String zone;
  /// Délai minimum estimé de livraison, en minutes.
  final int delaiMin;
  /// Délai maximum estimé de livraison, en minutes.
  final int delaiMax;

  /// Constructeur constant — tous les champs requis.
  const ZoneLivraison({
    required this.zone,
    required this.delaiMin,
    required this.delaiMax,
  });

  /// Texte formaté pour l'affichage, ex : "30-45 min".
  String get delaiAffiche => '$delaiMin-$delaiMax min';

  /// Supabase → Dart (élément d'un tableau JSON zones_livraison).
  /// delaiMin/delaiMax ont des valeurs par défaut (30/45) au cas où la
  /// donnée serait mal formée ou incomplète.
  factory ZoneLivraison.fromMap(Map<String, dynamic> map) {
    return ZoneLivraison(
      zone:     map['zone'] ?? '',
      delaiMin: map['delai_min'] ?? 30,
      delaiMax: map['delai_max'] ?? 45,
    );
  }

  /// Dart → Supabase (transformé en Map pour être stocké dans le tableau
  /// JSON zones_livraison de la boutique).
  Map<String, dynamic> toMap() {
    return {
      'zone':      zone,
      'delai_min': delaiMin,
      'delai_max': delaiMax,
    };
  }
}
