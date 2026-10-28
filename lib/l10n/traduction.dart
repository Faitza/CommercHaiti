import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'kreyol.dart';
import 'langue_provider.dart';

/// Traduction des textes de l'app.
/// Path : lib/l10n/traduction.dart
///
/// Le texte français EST la clé : `traduire('Panier')` renvoie « Panye »
/// en Kreyòl et « Panier » en français. Un texte absent du dictionnaire
/// (lib/l10n/kreyol*.dart) reste en français au lieu de casser l'écran.
///
/// Textes avec une valeur : mettre un nom entre accolades dans la clé
/// et passer la valeur dans [params] :
///   traduire('Bonjour {nom}', {'nom': auth.prenom})
///
/// Dans la méthode build d'un widget, utiliser `context.tr(...)` : le
/// widget se redessine tout seul quand la langue change. Partout ailleurs
/// (onPressed, async, services, providers), utiliser `traduire(...)`.
String traduire(String fr, [Map<String, Object?>? params]) {
  var texte =
      LangueProvider.courante == Langue.ht ? (kreyol[fr] ?? fr) : fr;
  if (params != null) {
    params.forEach((cle, valeur) {
      texte = texte.replaceAll('{$cle}', '${valeur ?? ''}');
    });
  }
  return texte;
}

extension TraductionContext on BuildContext {
  /// Comme traduire(), et abonne le widget aux changements de langue.
  /// À appeler seulement pendant build().
  String tr(String fr, [Map<String, Object?>? params]) {
    watch<LangueProvider>();
    return traduire(fr, params);
  }
}
