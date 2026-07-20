import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

/// Service authentification Supabase — Falexson MERCIVAL
/// Branch : feature/firebase-core
/// Path : lib/services/auth_service.dart
class AuthService {
  final _supabase = Supabase.instance.client;

  // ── Connexion email/mot de passe ──
  Future<UserModel?> signIn(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user == null) return null;
      return await getUserFromDatabase(response.user!.id);
    } on AuthException catch (e) {
      throw Exception(e.message);
    }
  }

  // ── Inscription ──
  Future<UserModel?> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> userData,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );
      if (response.user == null) return null;
      final uid = response.user!.id;

      await _supabase.from('users').insert({
        'id':        uid,
        'nom':       userData['nom'],
        'telephone': userData['telephone'],
        'email':     email,
        'role':      userData['role'] ?? 'customer',
        'adresse':   userData['adresse'],
        'shop_code': userData['shop_code'],
        'created_at': DateTime.now().toIso8601String(),
      });

      return await getUserFromDatabase(uid);
    } on AuthException catch (e) {
      throw Exception(e.message);
    }
  }

  // ── Connexion Google ──
  Future<void> signInWithGoogle() async {
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.commerchaiti://login-callback/',
      );
    } on AuthException catch (e) {
      throw Exception(e.message);
    }
  }

  // ── Déconnexion ──
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // ── Récupérer utilisateur depuis base de données ──
  Future<UserModel?> getUserFromDatabase(String uid) async {
    try {
      final data = await _supabase
          .from('users')
          .select()
          .eq('id', uid)
          .single();
      return UserModel.fromMap(data);
    } catch (e) {
      return null;
    }
  }

  // ── Écouter changements auth ──
  Stream<AuthState> get authStateChanges =>
      _supabase.auth.onAuthStateChange;

  // ── Utilisateur connecté actuellement ──
  User? get currentUser => _supabase.auth.currentUser;
}