import 'package:flutter_test/flutter_test.dart';
import 'package:commerchaiti/models/shop_model.dart';

ShopModel _shop({
  String? ouverture = '08:00',
  String? fermeture = '18:00',
  List<String> jours = const ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'],
  bool? manuel,
  bool base = true,
}) =>
    ShopModel(
      id: 's', proprietaireId: 'p', nom: 'Test', description: '',
      shopCode: 'X', zonesLivraison: const [],
      horaireOuverture: ouverture, horaireFermeture: fermeture,
      joursOuverture: jours, isOpenManuel: manuel, isOpenBase: base,
      createdAt: DateTime(2026),
    );

void main() {
  // 2026-10-05 est un lundi, 2026-10-11 un dimanche.
  final lundi10h = DateTime(2026, 10, 5, 10, 0);
  final lundi7h59 = DateTime(2026, 10, 5, 7, 59);
  final lundi18h = DateTime(2026, 10, 5, 18, 0);
  final dimanche10h = DateTime(2026, 10, 11, 10, 0);

  test('ouverte pendant l\'horaire un jour de travail', () {
    expect(_shop().estOuverteA(lundi10h), isTrue);
  });

  test('fermée avant l\'ouverture et à l\'heure de fermeture', () {
    expect(_shop().estOuverteA(lundi7h59), isFalse);
    expect(_shop().estOuverteA(lundi18h), isFalse);
  });

  test('fermée le dimanche (jour non travaillé)', () {
    expect(_shop().estOuverteA(dimanche10h), isFalse);
  });

  test('le forçage manuel l\'emporte sur l\'horaire', () {
    expect(_shop(manuel: false).estOuverteA(lundi10h), isFalse);
    expect(_shop(manuel: true).estOuverteA(dimanche10h), isTrue);
  });

  test('horaire qui passe minuit', () {
    final nuit = _shop(ouverture: '18:00', fermeture: '02:00',
        jours: const ['Samedi']);
    expect(nuit.estOuverteA(DateTime(2026, 10, 10, 23, 0)), isTrue); // samedi
    expect(nuit.estOuverteA(DateTime(2026, 10, 11, 1, 0)), isTrue); // dim. 1h
    expect(nuit.estOuverteA(DateTime(2026, 10, 11, 3, 0)), isFalse);
  });

  test('format TIME Postgres "HH:mm:ss" accepté via fromMap', () {
    final s = ShopModel.fromMap({
      'horaire_ouverture': '08:00:00',
      'horaire_fermeture': '18:00:00',
      'jours_ouverture': ['Lundi'],
    }, 'id');
    expect(s.horaireOuverture, '08:00');
    expect(s.estOuverteA(lundi10h), isTrue);
  });

  test('sans horaire : repli sur la colonne is_open', () {
    expect(_shop(ouverture: null, base: false).estOuverteA(lundi10h), isFalse);
    expect(_shop(ouverture: null, base: true).estOuverteA(lundi10h), isTrue);
  });
}
