import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

/// Service authentification Supabase — Falexson MERCIVAL
/// Branch : feature/firebase-core
/// Path : lib/services/auth_service.dart
///
/// Encapsule toutes les opérations Supabase Auth (connexion, inscription,
/// OAuth Google, déconnexion) et fait le lien avec la table `users` : dans
/// Supabase, `auth.users` (géré par le système d'authentification, contient
/// email/mot de passe hashé) est SÉPARÉ de notre table applicative
/// `public.users` (contient nom, téléphone, rôle, etc.) — les deux
/// partagent le même id (uid), ce qui permet de les relier.
class AuthService {
  final _supabase = Supabase.instance.client;

  /// Connecte un utilisateur avec email + mot de passe via
  /// `signInWithPassword`. En cas de succès, va chercher le profil complet
  /// dans la table `users` (nom, rôle, etc.) car `response.user` ne
  /// contient que les infos d'authentification (email, id...), pas les
  /// données métier. Retourne `null` si Supabase n'a pas renvoyé
  /// d'utilisateur ; lève une Exception avec un message lisible si
  /// Supabase Auth rejette la tentative (ex. mauvais mot de passe).
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

  /// Crée un nouveau compte : d'abord dans Supabase Auth (`signUp` crée
  /// l'entrée dans `auth.users` avec email/mot de passe), puis insère le
  /// profil applicatif correspondant dans `public.users` avec le MÊME id
  /// (`uid`) que l'utilisateur Auth généré — c'est ce qui relie les deux
  /// tables. `userData` contient les champs saisis dans le formulaire
  /// d'inscription (nom, téléphone, adresse, rôle, code boutique
  /// éventuel) ; `role` a une valeur par défaut 'customer' si absente.
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
  // Sur le web, Supabase redirige automatiquement vers l'URL courante —
  // le schéma personnalisé io.supabase.commerchaiti:// n'existe que sur
  // mobile (Android/iOS) et casse l'authentification si utilisé sur web.
  /// Lance le flux OAuth Google (`signInWithOAuth`) : Supabase ouvre une
  /// page Google de connexion puis redirige l'utilisateur vers
  /// `redirectTo` une fois authentifié. Sur mobile, ce paramètre est un
  /// "deep link" custom (schéma d'URL propre à l'app) qui permet à
  /// l'application de reprendre la main après la redirection ; sur le web
  /// on laisse `redirectTo` à `null` pour que Supabase utilise l'URL
  /// courante du navigateur automatiquement (le deep link mobile n'a pas
  /// de sens dans un navigateur).
  Future<void> signInWithGoogle() async {
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'io.supabase.commerchaiti://login-callback/',
      );
    } on AuthException catch (e) {
      throw Exception(e.message);
    }
  }

  /// Déconnecte l'utilisateur courant (invalide sa session Supabase Auth).
  // ── Déconnexion ──
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  /// Récupère le profil applicatif (table `users`) correspondant à un uid
  /// Supabase Auth. Retourne `null` si aucune ligne ne correspond (ex.
  /// profil pas encore créé) plutôt que de laisser l'exception remonter.
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

  /// Flux (Stream) réactif qui émet un événement à chaque changement d'état
  /// d'authentification (connexion, déconnexion, rafraîchissement de
  /// token...). Permet à l'UI (ex. AuthProvider) de réagir automatiquement
  /// sans avoir à vérifier manuellement l'état de connexion en boucle.
  // ── Écouter changements auth ──
  Stream<AuthState> get authStateChanges =>
      _supabase.auth.onAuthStateChange;

  /// Raccourci vers l'utilisateur Supabase Auth actuellement connecté
  /// (ou `null` si personne n'est connecté) — lecture synchrone de l'état
  /// courant, sans requête réseau.
  // ── Utilisateur connecté actuellement ──
  User? get currentUser => _supabase.auth.currentUser;
}