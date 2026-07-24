/// Modèle utilisateur
/// Branch : feature/auth-roles
/// Path : lib/models/user_model.dart
/// Table Supabase : users
/// Colonnes : id, nom, telephone, email, role, adresse, shop_code, created_at
///
/// Représente UN utilisateur de l'application, qu'il soit client
/// ("customer") ou vendeur ("seller"). Un seul modèle sert pour les deux
/// rôles ; les champs spécifiques à un rôle (comme shopCode pour les
/// vendeurs) sont simplement nullables pour les utilisateurs concernés.
class UserModel {
  /// Identifiant unique de l'utilisateur (uuid, correspond à l'id
  /// Supabase Auth).
  final String id;
  /// Nom complet de l'utilisateur.
  final String nom;
  /// Numéro de téléphone de l'utilisateur.
  final String telephone;
  /// Adresse email de l'utilisateur (utilisée pour la connexion).
  final String email;
  /// Rôle de l'utilisateur : 'seller' (vendeur) ou 'customer' (client).
  final String role; // 'seller' ou 'customer'
  /// Adresse du client, utilisée notamment pour la livraison.
  /// Nullable car un vendeur n'a pas forcément besoin de ce champ.
  final String? adresse;
  /// Code de la boutique du vendeur, s'il en a créé une.
  /// Nullable car les clients n'ont pas de boutique.
  final String? shopCode;
  /// Date de création du compte.
  final DateTime createdAt;

  /// Constructeur constant — champs communs requis, champs spécifiques
  /// au rôle (adresse, shopCode) optionnels.
  const UserModel({
    required this.id,
    required this.nom,
    required this.telephone,
    required this.email,
    required this.role,
    this.adresse,
    this.shopCode,
    required this.createdAt,
  });

  /// Vrai si l'utilisateur a le rôle vendeur.
  bool get isSeller   => role == 'seller';
  /// Vrai si l'utilisateur a le rôle client.
  bool get isCustomer => role == 'customer';
  /// Premier mot du nom complet — utilisé pour un affichage plus
  /// personnalisé et court (ex : messages de bienvenue "Bonjour, Jean").
  String get prenom   => nom.split(' ').first;

  /// Supabase → Dart (snake_case → camelCase)
  /// Convertit une ligne brute renvoyée par Supabase en objet Dart
  /// typé. Valeurs par défaut sûres si des champs sont absents (ex :
  /// role par défaut 'customer' si jamais la colonne était vide).
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id:        map['id'] ?? '',
      nom:       map['nom'] ?? '',
      telephone: map['telephone'] ?? '',
      email:     map['email'] ?? '',
      role:      map['role'] ?? 'customer',
      adresse:   map['adresse'],
      shopCode:  map['shop_code'],
      // Repli sur l'heure actuelle si created_at est absent.
      createdAt: map['created_at'] != null
                   ? DateTime.parse(map['created_at'])
                   : DateTime.now(),
    );
  }

  /// Dart → Supabase (camelCase → snake_case)
  /// Convertit cet objet en Map prête à être insérée/mise à jour dans
  /// la table users.
  Map<String, dynamic> toMap() {
    return {
      'id':         id,
      'nom':        nom,
      'telephone':  telephone,
      'email':      email,
      'role':       role,
      'adresse':    adresse,
      'shop_code':  shopCode,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
