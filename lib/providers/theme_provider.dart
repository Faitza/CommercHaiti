import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider mode sombre — persistance SharedPreferences (BNF/section 12.2)
/// Path : lib/providers/theme_provider.dart
///
/// Gère le choix du client entre thème clair et thème sombre pour toute
/// l'application, et mémorise ce choix localement sur l'appareil (via
/// SharedPreferences) pour qu'il soit conservé même après fermeture de
/// l'app.
class ThemeProvider extends ChangeNotifier {
  /// Clé utilisée pour lire/écrire la préférence dans SharedPreferences.
  static const _prefsKey = 'dark_mode';

  /// État courant : vrai si le mode sombre est actif.
  bool _isDarkMode = false;
  /// Expose l'état courant en lecture seule.
  bool get isDarkMode => _isDarkMode;
  /// Traduit le booléen interne en ThemeMode Flutter, directement
  /// utilisable par MaterialApp (theme/darkTheme + themeMode).
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  /// Au moment de la création du provider (donc au démarrage de l'app),
  /// on charge immédiatement la préférence sauvegardée précédemment.
  ThemeProvider() {
    _loadPreference();
  }

  /// Lit la préférence de thème sauvegardée sur l'appareil. Si aucune
  /// valeur n'a encore été enregistrée (première utilisation de l'app),
  /// on utilise `false` (mode clair) par défaut.
  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_prefsKey) ?? false;
    notifyListeners();
  }

  /// Change le mode sombre/clair et sauvegarde immédiatement ce choix
  /// dans SharedPreferences. On notifie les listeners AVANT l'écriture
  /// disque pour que l'UI réagisse instantanément (changement de thème
  /// visible tout de suite), sans attendre la fin de l'opération
  /// asynchrone de sauvegarde.
  Future<void> toggle(bool value) async {
    _isDarkMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
  }
}
