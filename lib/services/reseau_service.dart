import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Réseau — checklist production (points 07 et 08)
/// Path : lib/services/reseau_service.dart
///
/// 1. [TimeoutHttpClient] : client HTTP donné à Supabase.initialize()
///    (voir main.dart). Sans lui, une requête vers une API qui ne répond
///    pas peut rester bloquée très longtemps et l'écran tourne sans fin.
///    Ici, toute requête Supabase (base, auth, storage, RPC) est
///    abandonnée après [delai] et lève une TimeoutException, que les
///    écrans transforment en message + bouton « Réessayer ».
/// 2. [messageErreur] : traduit n'importe quelle exception en phrase
///    compréhensible pour l'utilisateur (pas de texte technique).
class TimeoutHttpClient extends http.BaseClient {
  final http.Client _inner;
  final Duration delai;
  // Les envois de fichiers (photos) peuvent être plus longs sur une
  // connexion mobile lente : on leur laisse plus de temps.
  final Duration delaiUpload;

  TimeoutHttpClient({
    http.Client? inner,
    this.delai = const Duration(seconds: 20),
    this.delaiUpload = const Duration(seconds: 90),
  }) : _inner = inner ?? http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final estUpload = request.url.path.contains('/storage/v1/object');
    return _inner.send(request).timeout(estUpload ? delaiUpload : delai);
  }

  @override
  void close() => _inner.close();
}

/// Message d'erreur lisible pour l'utilisateur à partir d'une exception.
/// [parDefaut] est utilisé quand on ne reconnaît pas l'erreur.
String messageErreur(Object erreur,
    {String parDefaut = 'Une erreur est survenue. Réessayez.'}) {
  if (erreur is TimeoutException) {
    return 'Le serveur met trop de temps à répondre. '
        'Vérifiez votre connexion et réessayez.';
  }
  // Pas d'import dart:io (indisponible sur Flutter Web) : on reconnaît
  // l'erreur réseau mobile par son nom.
  if (erreur.runtimeType.toString() == 'SocketException') {
    return 'Pas de connexion Internet. Vérifiez votre réseau et réessayez.';
  }
  if (erreur is http.ClientException) {
    return 'Connexion impossible au serveur. Vérifiez votre réseau.';
  }
  final texte = erreur.toString();
  // Limite de requêtes atteinte (voir supabase/migration_production.sql,
  // fonction verifier_limite()).
  if (texte.contains('trop_de_requetes')) {
    return 'Trop de tentatives en peu de temps. '
        'Patientez une minute puis réessayez.';
  }
  if (erreur is PostgrestException && erreur.code == 'PGRST301') {
    return 'Votre session a expiré. Reconnectez-vous.';
  }
  if (texte.contains('fichier_trop_lourd')) {
    return 'Image trop lourde. Choisissez une photo plus légère.';
  }
  return parDefaut;
}
