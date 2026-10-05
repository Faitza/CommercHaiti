import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_colors.dart';

/// Gestion globale des erreurs — checklist production (points 04 et 18)
/// Path : lib/services/erreur_service.dart
///
/// - Point 04 « affiche un message quand ça plante » : toute erreur non
///   prévue affiche un message clair (SnackBar via [messengerKey]) au lieu
///   de laisser l'app figée, et un widget qui plante pendant son
///   affichage est remplacé par un encadré lisible au lieu de l'écran
///   rouge/gris de Flutter.
/// - Point 18 « garde une trace de chaque erreur » : chaque erreur est
///   envoyée dans la table Supabase `app_errors` via la fonction
///   `journaliser_erreur` (voir supabase/migration_production.sql). Les
///   admins peuvent la consulter dans le SQL Editor (requêtes prêtes dans
///   docs/PRODUCTION.md).
class ErreurService {
  ErreurService._();

  /// Clé donnée à MaterialApp.router (scaffoldMessengerKey) pour pouvoir
  /// afficher une SnackBar depuis n'importe où, même sans BuildContext.
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();

  // Anti-avalanche : une erreur qui se répète en boucle ne doit pas
  // envoyer des centaines de requêtes (point 02). On garde au plus
  // [_maxParMinute] envois par minute, et on ignore une erreur identique
  // déjà envoyée dans la dernière minute.
  static const _maxParMinute = 10;
  static final List<DateTime> _envoisRecents = [];
  static final Map<String, DateTime> _dejaEnvoyees = {};
  static DateTime? _dernierMessageAffiche;

  /// À appeler une fois dans main(), avant runApp().
  static void installer() {
    // Erreurs levées par le framework Flutter (build, layout, paint...).
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      signaler(details.exception, details.stack,
          contexte: details.context?.toString() ?? 'flutter');
    };

    // Erreurs asynchrones non attrapées (Future sans catch, streams...).
    PlatformDispatcher.instance.onError = (erreur, stack) {
      signaler(erreur, stack, contexte: 'async');
      afficherMessage();
      return true; // erreur gérée : l'app continue de tourner
    };

    // Widget qui plante pendant son build : en production, on affiche un
    // encadré lisible au lieu de l'écran gris de Flutter.
    if (kReleaseMode) {
      ErrorWidget.builder = (details) => const _WidgetEnErreur();
    }
  }

  /// Affiche « Oups... » en bas de l'écran (au plus une fois toutes les
  /// 5 secondes pour ne pas empiler les messages).
  static void afficherMessage(
      [String message = 'Oups, un problème est survenu. Réessayez.']) {
    final maintenant = DateTime.now();
    if (_dernierMessageAffiche != null &&
        maintenant.difference(_dernierMessageAffiche!) <
            const Duration(seconds: 5)) {
      return;
    }
    _dernierMessageAffiche = maintenant;
    messengerKey.currentState?.showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: AppColors.red,
    ));
  }

  /// Enregistre une erreur : console + table `app_errors`. Ne lève
  /// jamais d'exception (un échec d'envoi est simplement ignoré).
  static void signaler(Object erreur, StackTrace? stack,
      {String contexte = ''}) {
    debugPrint('[ErreurService] $contexte : $erreur');

    final message = erreur.toString();
    final maintenant = DateTime.now();
    _envoisRecents.removeWhere(
        (d) => maintenant.difference(d) > const Duration(minutes: 1));
    _dejaEnvoyees.removeWhere(
        (_, d) => maintenant.difference(d) > const Duration(minutes: 1));
    if (_envoisRecents.length >= _maxParMinute) return;
    if (_dejaEnvoyees.containsKey(message)) return;
    _envoisRecents.add(maintenant);
    _dejaEnvoyees[message] = maintenant;

    unawaited(_envoyer(message, stack, contexte));
  }

  static Future<void> _envoyer(
      String message, StackTrace? stack, String contexte) async {
    try {
      await Supabase.instance.client.rpc('journaliser_erreur', params: {
        'p_message': _couper(message, 1000),
        'p_stack': _couper(stack?.toString() ?? '', 4000),
        'p_contexte': _couper(contexte, 200),
        'p_plateforme': kIsWeb ? 'web' : defaultTargetPlatform.name,
      });
    } catch (_) {
      // Pas de réseau, migration pas encore appliquée... : on ignore
      // pour ne pas créer une nouvelle erreur en signalant la première.
    }
  }

  static String _couper(String texte, int max) =>
      texte.length <= max ? texte : texte.substring(0, max);
}

class _WidgetEnErreur extends StatelessWidget {
  const _WidgetEnErreur();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      alignment: Alignment.center,
      child: const Text(
        'Cet élément n\'a pas pu s\'afficher.',
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
    );
  }
}
