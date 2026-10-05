import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/auth_provider.dart';
import 'notification_navigation.dart';

/// Notifications push (Firebase Cloud Messaging).
///
/// Rôle de ce service :
///  1. Initialiser Firebase. Si android/app/google-services.json n'a pas
///     encore été ajouté, l'initialisation échoue proprement : l'app
///     fonctionne normalement, sans push (les notifications restent
///     visibles dans l'écran Notifications).
///  2. Demander la permission (Android 13+ / iOS).
///  3. Enregistrer le jeton du téléphone dans `device_tokens` à chaque
///     connexion, et le retirer à la déconnexion.
///  4. Ouvrir le bon écran quand l'utilisateur touche une notification,
///     et afficher un bandeau quand une notification arrive alors que
///     l'app est ouverte.
///
/// L'envoi lui-même est fait côté serveur (Edge Function send-push).
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  /// Clé du ScaffoldMessenger global (branchée sur MaterialApp.router),
  /// pour afficher un SnackBar quand un push arrive app ouverte.
  final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  bool _disponible = false;
  GoRouter? _router;
  AuthProvider? _auth;
  RemoteMessage? _enAttente;

  bool get disponible => _disponible;

  /// À appeler dans main(), après Supabase.initialize().
  Future<void> init() async {
    try {
      await Firebase.initializeApp();
      _disponible = true;
    } catch (e) {
      debugPrint('PushService: Firebase non configuré, push désactivé ($e)');
      return;
    }

    final messaging = FirebaseMessaging.instance;

    // Enregistre le jeton dès qu'une session existe (démarrage avec une
    // session déjà ouverte, ou nouvelle connexion).
    Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      if (state.session != null &&
          (state.event == AuthChangeEvent.initialSession ||
           state.event == AuthChangeEvent.signedIn)) {
        _enregistrerJeton();
      }
    });
    messaging.onTokenRefresh.listen((_) => _enregistrerJeton());

    FirebaseMessaging.onMessage.listen(_afficherBandeau);
    FirebaseMessaging.onMessageOpenedApp.listen(_ouvrir);
    // App lancée en touchant une notification (app fermée).
    final initial = await messaging.getInitialMessage();
    if (initial != null) _enAttente = initial;
  }

  /// Branche le router et l'auth, une fois créés (voir main.dart).
  void attach(GoRouter router, AuthProvider auth) {
    _router = router;
    _auth = auth;
    router.routerDelegate.addListener(_traiterEnAttente);
    auth.addListener(_traiterEnAttente);
    _traiterEnAttente();
  }

  Future<void> _enregistrerJeton() async {
    if (!_disponible) return;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await Supabase.instance.client.rpc('register_device_token', params: {
        'p_token': token,
        'p_platform': defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android',
      });
    } catch (e) {
      debugPrint('PushService: enregistrement du jeton impossible ($e)');
    }
  }

  /// À appeler AVANT la déconnexion (il faut encore la session pour
  /// supprimer la ligne, à cause de RLS) : ce téléphone ne recevra plus
  /// les notifications de ce compte.
  Future<void> retirerJeton() async {
    if (!_disponible) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await Supabase.instance.client
          .from('device_tokens')
          .delete()
          .eq('token', token);
    } catch (e) {
      debugPrint('PushService: suppression du jeton impossible ($e)');
    }
  }

  void _afficherBandeau(RemoteMessage message) {
    final notif = message.notification;
    if (notif == null) return;
    scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
      content: Text([notif.title, notif.body]
          .whereType<String>()
          .join('\n')),
      duration: const Duration(seconds: 5),
      action: SnackBarAction(label: 'Voir', onPressed: () => _ouvrir(message)),
    ));
  }

  void _ouvrir(RemoteMessage message) {
    _enAttente = message;
    _traiterEnAttente();
  }

  // Ouvre l'écran de la notification en attente dès que c'est possible :
  // utilisateur connecté et écran de démarrage (splash) terminé — sinon
  // la redirection du splash écraserait notre navigation.
  void _traiterEnAttente() {
    final message = _enAttente;
    final router = _router;
    final auth = _auth;
    if (message == null || router == null || auth == null) return;
    if (!auth.isLoggedIn) return;
    final path = router.routerDelegate.currentConfiguration.uri.path;
    if (path.isEmpty || path == '/splash') return;

    _enAttente = null;
    final notificationId = message.data['notification_id']?.toString();
    if (notificationId != null) {
      Supabase.instance.client
          .from('notifications')
          .update({'lu': true})
          .eq('id', notificationId)
          .then((_) {}, onError: (_) {});
    }
    ouvrirNotification(
      router,
      type: message.data['type']?.toString() ?? '',
      data: message.data,
      isSeller: auth.isSeller,
    );
  }
}
