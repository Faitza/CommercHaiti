/// Modèle utilisateur — Faitza COLAS
/// Branch : feature/auth-roles
/// Path : lib/models/user_model.dart
class UserModel {
  final String uid;
  final String nom;
  final String telephone;
  final String email;
  final String role; // 'seller' ou 'customer'
  final String? adresse;
  final String? shopCode;
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.nom,
    required this.telephone,
    required this.email,
    required this.role,
    this.adresse,
    this.shopCode,
    required this.createdAt,
  });

  bool get isSeller => role == 'seller';
  bool get isCustomer => role == 'customer';
  String get prenom => nom.split(' ').first;

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      nom: map['nom'] ?? '',
      telephone: map['telephone'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'customer',
      adresse: map['adresse'],
      shopCode: map['shopCode'],
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'nom': nom,
      'telephone': telephone,
      'email': email,
      'role': role,
      'adresse': adresse,
      'shopCode': shopCode,
      'createdAt': createdAt,
    };
  }
}