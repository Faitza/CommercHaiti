import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Langue de l'application : Kreyòl (par défaut) ou Français.
/// Path : lib/l10n/langue_provider.dart
///
/// Le choix est gardé dans SharedPreferences et se change dans
/// Paramètres. Les textes sont traduits par traduire() / context.tr()
/// (voir traduction.dart).
enum Langue { ht, fr }

class LangueProvider extends ChangeNotifier {
  static const _prefsKey = 'langue';

  /// Langue en cours, lisible aussi hors des widgets (services,
  /// messages d'erreur) via traduire().
  static Langue courante = Langue.ht;

  Langue get langue => courante;
  bool get estKreyol => courante == Langue.ht;

  LangueProvider() {
    _charger();
  }

  Future<void> _charger() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefsKey);
      final l = code == 'fr' ? Langue.fr : Langue.ht;
      if (l != courante) {
        courante = l;
        notifyListeners();
      }
    } catch (_) {
      // Préférence illisible : on garde le Kreyòl.
    }
  }

  Future<void> choisir(Langue l) async {
    if (l == courante) return;
    courante = l;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, l.name);
    } catch (_) {}
  }
}
