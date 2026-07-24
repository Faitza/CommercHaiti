import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

/// Provider authentification — Faitza COLAS
/// Branch : feature/auth-roles
/// Path : lib/providers/auth_provider.dart
///
/// Centralise tout l'état lié à l'authentification : utilisateur
/// connecté, chargement, erreurs, et — pour les vendeurs — l'identifiant
/// de leur boutique. Écoute aussi en continu les changements de session
/// Supabase (connexion/déconnexion déclenchées ailleurs, ex : lien
/// magique par email) pour garder l'état de l'app synchronisé.
class AuthProvider extends ChangeNotifier {
  /// Service dédié qui encapsule les appels bruts à Supabase Auth
  /// (signIn, signUp, signOut, etc.).
  final AuthService _authService = AuthService();
  /// Client Supabase global, utilisé ici pour des requêtes directes
  /// (ex : résoudre l'id de la boutique du vendeur).
  final _supabase = Supabase.instance.client;

  /// Utilisateur actuellement connecté, ou null si personne n'est connecté.
  UserModel? _currentUser;
  /// Indique si une opération d'authentification est en cours.
  bool _isLoading = false;
  /// Dernier message d'erreur (déjà traduit en français lisible) à
  /// afficher à l'utilisateur.
  String? _errorMessage;

  /// id réel de la boutique (shops.id — uuid), distinct de shopCode qui
  /// n'est qu'un identifiant lisible. Résolu via shops.proprietaire_id.
  String? _shopId;

  /// Expose l'utilisateur connecté.
  UserModel? get currentUser => _currentUser;
  /// Indique si une opération est en cours.
  bool get isLoading         => _isLoading;
  /// Message d'erreur courant.
  String? get errorMessage   => _errorMessage;
  /// Vrai si un utilisateur est actuellement connecté.
  bool get isLoggedIn        => _currentUser != null;
  /// Vrai si l'utilisateur connecté est un vendeur.
  bool get isSeller          => _currentUser?.role == 'seller';
  /// Vrai si l'utilisateur connecté est un client.
  bool get isCustomer        => _currentUser?.role == 'customer';
  /// Prénom de l'utilisateur connecté, ou une valeur de repli générique
  /// si personne n'est connecté (évite un null lors de l'affichage).
  String get prenom          => _currentUser?.prenom ?? 'Utilisateur';
  /// Identifiant réel (uuid) de la boutique du vendeur connecté, ou
  /// null si le vendeur n'a pas encore créé de boutique / n'est pas vendeur.
  String? get shopId         => _shopId;

  /// À la création du provider, on démarre immédiatement l'écoute des
  /// changements de session Supabase.
  AuthProvider() {
    _initAuthListener();
  }

  /// Écoute les changements de connexion Supabase
  /// S'abonne au flux d'événements d'authentification de Supabase :
  /// à chaque connexion ou déconnexion (même déclenchée par un autre
  /// mécanisme, comme un lien de confirmation email), ce callback est
  /// invoqué pour garder _currentUser synchronisé avec la vraie session.
  void _initAuthListener() {
    _authService.authStateChanges.listen((AuthState state) async {
      if (state.event == AuthChangeEvent.signedIn) {
        final uid = state.session?.user.id;
        if (uid != null) {
          // On va chercher le profil complet (nom, rôle, etc.) dans la
          // table users, car la session Supabase Auth ne contient que
          // les infos d'authentification (email, uid), pas le profil
          // métier de l'application.
          _currentUser = await _authService.getUserFromDatabase(uid);
          // Si c'est un vendeur, on résout aussi l'id de sa boutique
          // (nécessaire pour toutes les requêtes liées à sa boutique).
          if (_currentUser?.isSeller == true) {
            await _loadShopId(uid);
          }
          notifyListeners();
        }
      } else if (state.event == AuthChangeEvent.signedOut) {
        // Déconnexion : on réinitialise tout l'état utilisateur.
        _currentUser = null;
        _shopId = null;
        notifyListeners();
      }
    });
  }

  /// Résout shops.id du vendeur connecté depuis shops.proprietaire_id.
  /// null tant que le vendeur n'a pas encore créé sa boutique.
  /// maybeSingle() est utilisé plutôt que single() car il est normal
  /// qu'aucune ligne n'existe encore (vendeur fraîchement inscrit sans
  /// boutique) — single() lèverait une exception dans ce cas, alors que
  /// maybeSingle() retourne simplement null.
  Future<void> _loadShopId(String ownerId) async {
    try {
      final row = await _supabase
          .from('shops')
          .select('id')
          .eq('proprietaire_id', ownerId)
          .maybeSingle();
      _shopId = row?['id'] as String?;
    } catch (_) {
      // En cas d'erreur réseau/DB, on considère simplement qu'on ne
      // connaît pas encore l'id de la boutique plutôt que de planter.
      _shopId = null;
    }
  }

  /// À appeler après CreateShopScreen — la boutique vient d'être créée.
  /// Permet de rafraîchir _shopId sans devoir se déconnecter/reconnecter,
  /// juste après que le vendeur a terminé la création de sa boutique.
  Future<void> refreshShopId() async {
    if (_currentUser == null) return;
    await _loadShopId(_currentUser!.id);
    notifyListeners();
  }

  /// À appeler après modification du profil (nom, téléphone, adresse).
  /// Recharge le profil utilisateur complet depuis la base pour que
  /// l'UI reflète immédiatement les changements effectués par
  /// l'utilisateur sur son propre profil.
  Future<void> refreshCurrentUser() async {
    if (_currentUser == null) return;
    _currentUser = await _authService.getUserFromDatabase(_currentUser!.id);
    notifyListeners();
  }

  // ── Connexion ──
  /// Connecte un utilisateur avec email/mot de passe. Met à jour
  /// _currentUser et, si c'est un vendeur, résout aussi son shopId.
  /// Retourne true en cas de succès, false sinon (avec _errorMessage
  /// rempli pour expliquer l'échec à l'utilisateur).
  Future<bool> signIn(String email, String password) async {
    _setLoading(true);
    _clearError();
    try {
      _currentUser = await _authService.signIn(email, password);
      if (_currentUser?.isSeller == true) {
        await _loadShopId(_currentUser!.id);
      }
      notifyListeners();
      return _currentUser != null;
    } catch (e) {
      // On journalise l'erreur brute en debug pour faciliter le
      // diagnostic, mais on affiche à l'utilisateur un message traduit
      // et compréhensible via _parseError.
      debugPrint('AuthProvider error: $e');
      _errorMessage = _parseError(e);
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Inscription Client ──
  /// Crée un nouveau compte client (role = 'customer') avec les
  /// informations fournies. Ne gère pas de boutique (uniquement pour
  /// les vendeurs, voir signUpVendeur).
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
      debugPrint('AuthProvider error: $e');
      _errorMessage = _parseError(e);
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Inscription Vendeur ──
  /// Crée un nouveau compte vendeur (role = 'seller'). Génère aussi un
  /// code boutique unique à partir du nom de boutique fourni, stocké
  /// dans le profil utilisateur (shop_code) — la boutique elle-même
  /// (table shops) est créée séparément dans un écran ultérieur
  /// (CreateShopScreen), d'où l'appel à refreshShopId() plus tard.
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
      debugPrint('AuthProvider error: $e');
      _errorMessage = _parseError(e);
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Connexion Google ──
  /// Lance le flux de connexion via Google (OAuth). Ne renvoie rien
  /// directement : la mise à jour de _currentUser se fait via
  /// _initAuthListener() qui réagira à l'événement signedIn une fois le
  /// flux OAuth terminé côté Supabase.
  Future<void> signInWithGoogle() async {
    _setLoading(true);
    _clearError();
    try {
      await _authService.signInWithGoogle();
    } catch (e) {
      debugPrint('AuthProvider error: $e');
      _errorMessage = _parseError(e);
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  // ── Changer mot de passe ──
  /// Met à jour le mot de passe de l'utilisateur actuellement connecté
  /// via l'API Supabase Auth (nécessite une session active valide).
  Future<void> updatePassword(String nouveauMotDePasse) async {
    await _supabase.auth.updateUser(
      UserAttributes(password: nouveauMotDePasse),
    );
  }

  // ── Déconnexion ──
  /// Déconnecte l'utilisateur courant et réinitialise l'état local.
  Future<void> signOut() async {
    await _authService.signOut();
    _currentUser = null;
    notifyListeners();
  }

  /// Génère code boutique — format MFL-2026-4892
  /// Construit un identifiant lisible et unique pour une boutique à
  /// partir de son nom : initiales des 3 premiers mots (majuscules) +
  /// année courante + un nombre "aléatoire" à 4 chiffres dérivé de
  /// l'horodatage courant (millisecondesDepuisEpoch modulo 9000, +1000
  /// pour garantir 4 chiffres entre 1000 et 9999). Ce n'est pas un vrai
  /// générateur cryptographique, mais suffisant pour un code lisible et
  /// très peu susceptible de collision dans ce contexte.
  String generateShopCode(String nomBoutique) {
    final mots = nomBoutique.trim().split(' ')
        .where((m) => m.isNotEmpty).toList();
    final initiales = mots.take(3).map((m) => m[0].toUpperCase()).join();
    final annee = DateTime.now().year;
    final random = (DateTime.now().millisecondsSinceEpoch % 9000) + 1000;
    return '$initiales-$annee-$random';
  }

  /// Met à jour l'état de chargement et notifie les listeners.
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// Efface l'erreur courante sans notifier (utilisé en interne juste
  /// avant de lancer une nouvelle opération, pour repartir propre sans
  /// provoquer un rebuild inutile supplémentaire — le notifyListeners()
  /// de _setLoading juste après suffit à rafraîchir l'UI).
  void _clearError() => _errorMessage = null;

  /// Efface l'erreur courante ET notifie les listeners — version
  /// publique utilisable depuis l'UI (ex : après avoir affiché l'erreur
  /// dans une SnackBar, pour ne pas la réafficher au prochain rebuild).
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Traduit une exception technique (souvent en anglais, venant de
  /// Supabase Auth) en message d'erreur clair et en français pour
  /// l'utilisateur final. Si aucun cas connu ne correspond, retourne un
  /// message générique plutôt que d'exposer le détail technique brut.
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
