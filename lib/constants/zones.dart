/// Zones de livraison
/// Path : lib/constants/zones.dart
///
/// Liste des zones proposées dans le menu déroulant du vendeur (création
/// et modification de la boutique) et du client (formulaire de commande).
/// Un vendeur peut aussi écrire une autre zone : elle est alors rangée
/// telle quelle dans shops.zones_livraison.
class Zones {
  Zones._();

  static const List<String> toutes = [
    'Cayes Centre', 'Cayes Nord', 'Cayes Sud',
    'Torbeck', 'Saint-Jean', 'Maniche', 'Camp-Perrin',
  ];

  /// Comparaison sans tenir compte des majuscules ni des espaces autour,
  /// pour qu'une zone écrite à la main ("torbeck ") corresponde à la
  /// zone de la liste ("Torbeck").
  static bool memeZone(String a, String b) =>
      a.trim().toLowerCase() == b.trim().toLowerCase();
}
