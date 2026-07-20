import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

/// Provider authentification — Faitza COLAS
/// Branch : feature/auth-roles
/// Path : lib/providers/auth_provider.dart
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isLoading         => _isLoading;
  String? get errorMessage   => _errorMessage;
  bool get isLoggedIn        => _currentUser != null;
  bool get isSeller          => _currentUser?.role == 'seller';
  bool get isCustomer        => _currentUser?.role == 'customer';
  String get prenom          => _currentUser?.prenom ?? 'Utilisateur';

  AuthProvider() {
    _initAuthListener();
  }

  /// Écoute les changements de connexion Supabase
  void _initAuthListener() {
    _authService.authStateChanges.listen((AuthState state) async {
      if (state.event == AuthChangeEvent.signedIn) {
        final uid = state.session?.user.id;
        if (uid != null) {
          _currentUser = await _authService.getUserFromDatabase(uid);
          notifyListeners();
        }
      } else if (state.event == AuthChangeEvent.signedOut) {
        _currentUser = null;
        notifyListeners();
      }
    });
  }

  // ── Connexion ──
  Future<bool> signIn(String email, String password) async {
    _setLoading(true);
    _clearError();
    try {
      _currentUser = await _authService.signIn(email, password);
      notifyListeners();
      return _currentUser != null;
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Inscription Client ──
  Future<bool> signUpClient({
    required String nom,
    required String telephone,
    required String adresse,
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      _currentUser = await _authService.signUp(
        email: email,
        password: password,
        userData: {
          'nom':       nom,
          'telephone': telephone,
          'adresse':   adresse,
          'role':      'customer',
        },
      );
      notifyListeners();
      return _currentUser != null;
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Inscription Vendeur ──
  Future<bool> signUpVendeur({
    required String nom,
    required String telephone,
    required String email,
    required String password,
    required String nomBoutique,
    required String description,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      final shopCode = generateShopCode(nomBoutique);
      _currentUser = await _authService.signUp(
        email: email,
        password: password,
        userData: {
          'nom':       nom,
          'telephone': telephone,
          'role':      'seller',
          'shop_code': shopCode,
        },
      );
      notifyListeners();
      return _currentUser != null;
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Connexion Google ──
  Future<void> signInWithGoogle() async {
    _setLoading(true);
    _clearError();
    try {
      await _authService.signInWithGoogle();
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  // ── Déconnexion ──
  Future<void> signOut() async {
    await _authService.signOut();
    _currentUser = null;
    notifyListeners();
  }

  /// Génère code boutique — format MFL-2026-4892
  String generateShopCode(String nomBoutique) {
    final mots = nomBoutique.trim().split(' ')
        .where((m) => m.isNotEmpty).toList();
    final initiales = mots.take(3).map((m) => m[0].toUpperCase()).join();
    final annee = DateTime.now().year;
    final random = (DateTime.now().millisecondsSinceEpoch % 9000) + 1000;
    return '$initiales-$annee-$random';
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _clearError() => _errorMessage = null;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  String _parseError(dynamic e) {
    final msg = e.toString();
    if (msg.contains('Invalid login credentials'))
      return 'Email ou mot de passe incorrect';
    if (msg.contains('Email not confirmed'))
      return 'Confirmez votre email avant de vous connecter';
    if (msg.contains('User already registered'))
      return 'Un compte existe déjà avec cet email';
    if (msg.contains('Password should be at least'))
      return 'Mot de passe trop court — minimum 6 caractères';
    return 'Une erreur est survenue. Réessayez.';
  }
}