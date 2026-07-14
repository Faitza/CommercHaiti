import 'package:flutter/material.dart';
import '../models/user_model.dart';
// TODO Falexson : décommenter quand auth_service.dart sera prêt
// import '../services/auth_service.dart';

/// Provider authentification — Faitza COLAS
/// Branch : feature/auth-roles
/// Path : lib/providers/auth_provider.dart
class AuthProvider extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _currentUser != null;
  bool get isSeller => _currentUser?.role == 'seller';
  bool get isCustomer => _currentUser?.role == 'customer';
  String get prenom => _currentUser?.prenom ?? 'Utilisateur';

  Future<bool> signIn(String email, String password) async {
    _setLoading(true);
    try {
      // TODO : await _authService.signIn(email, password)
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signUpClient({
    required String nom,
    required String telephone,
    required String adresse,
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    try {
      // TODO : créer users/{uid} dans Firestore avec role = 'customer'
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signUpVendeur({
    required String nom,
    required String telephone,
    required String email,
    required String password,
    required String nomBoutique,
    required String description,
  }) async {
    _setLoading(true);
    try {
      final code = generateShopCode(nomBoutique);
      // TODO : créer users/{uid} et shops/{sid} dans Firestore
      print('Code boutique généré : $code');
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    try {
      // TODO : await _authService.signInWithGoogle()
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    // TODO : await _authService.signOut()
    _currentUser = null;
    notifyListeners();
  }

  /// Génère le code boutique — format MFL-2026-4892
  String generateShopCode(String nomBoutique) {
    final mots = nomBoutique.trim().split(' ').where((m) => m.isNotEmpty).toList();
    final initiales = mots.take(3).map((m) => m[0].toUpperCase()).join();
    final annee = DateTime.now().year;
    final random = (DateTime.now().millisecondsSinceEpoch % 9000) + 1000;
    return '$initiales-$annee-$random';
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}