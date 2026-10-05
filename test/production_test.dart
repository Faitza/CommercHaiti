import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:commerchaiti/services/database_service.dart';
import 'package:commerchaiti/services/reseau_service.dart';
import 'package:commerchaiti/widgets/etat_widgets.dart';

/// Tests de la checklist production (points 05 à 10).
void main() {
  group('TimeoutHttpClient (point 08)', () {
    test('abandonne une requête qui ne répond pas', () async {
      final lent = MockClient((_) async {
        await Future.delayed(const Duration(milliseconds: 300));
        return http.Response('ok', 200);
      });
      final client = TimeoutHttpClient(
          inner: lent, delai: const Duration(milliseconds: 50));
      expect(client.get(Uri.parse('https://x.supabase.co/rest/v1/shops')),
          throwsA(isA<TimeoutException>()));
    });

    test('laisse plus de temps aux envois de photos', () async {
      final lent = MockClient((_) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return http.Response('ok', 200);
      });
      final client = TimeoutHttpClient(
        inner: lent,
        delai: const Duration(milliseconds: 50),
        delaiUpload: const Duration(seconds: 2),
      );
      final r = await client.post(
          Uri.parse('https://x.supabase.co/storage/v1/object/products/a.jpg'));
      expect(r.statusCode, 200);
    });
  });

  group('messageErreur (point 07)', () {
    test('délai dépassé', () {
      expect(messageErreur(TimeoutException('x')), contains('trop de temps'));
    });
    test('limite de requêtes', () {
      expect(messageErreur(Exception('trop_de_requetes')),
          contains('Trop de tentatives'));
    });
    test('erreur inconnue → message par défaut', () {
      expect(messageErreur(Exception('???'), parDefaut: 'Défaut'), 'Défaut');
    });
  });

  test('clé de commande unique au format UUID v4 (point 10)', () {
    final uuid = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
    final cles = List.generate(200, (_) => DatabaseService.nouvelleCleIdempotence());
    for (final c in cles) {
      expect(uuid.hasMatch(c), isTrue, reason: c);
    }
    expect(cles.toSet().length, cles.length);
  });

  testWidgets('EtatErreurWidget affiche Réessayer (points 05-07)',
      (tester) async {
    var appels = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EtatErreurWidget(message: 'Hors ligne', onReessayer: () => appels++),
      ),
    ));
    expect(find.text('Hors ligne'), findsOneWidget);
    await tester.tap(find.text('Réessayer'));
    expect(appels, 1);
  });
}
