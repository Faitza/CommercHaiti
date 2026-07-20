/// Modèle utilisateur — Faitza COLAS
/// Branch : feature/auth-roles
/// Path : lib/models/user_model.dart
/// Table Supabase : users
/// Colonnes : id, nom, telephone, email, role, adresse, shop_code, created_at
class UserModel {
  final String id;
  final String nom;
  final String telephone;
  final String email;
  final String role; // 'seller' ou 'customer'
  final String? adresse;
  final String? shopCode;
  final DateTime createdAt;

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

  bool get isSeller   => role == 'seller';
  bool get isCustomer => role == 'customer';
  String get prenom   => nom.split(' ').first;

  /// Supabase → Dart (snake_case → camelCase)
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id:        map['id'] ?? '',
      nom:       map['nom'] ?? '',
      telephone: map['telephone'] ?? '',
      email:     map['email'] ?? '',
      role:      map['role'] ?? 'customer',
      adresse:   map['adresse'],
      shopCode:  map['shop_code'],
      createdAt: map['created_at'] != null
                   ? DateTime.parse(map['created_at'])
                   : DateTime.now(),
    );
  }

  /// Dart → Supabase (camelCase → snake_case)
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