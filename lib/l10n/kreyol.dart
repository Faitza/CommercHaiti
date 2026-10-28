import 'kreyol_auth.dart';
import 'kreyol_client.dart';
import 'kreyol_commandes.dart';
import 'kreyol_vendeur.dart';
import 'kreyol_commun.dart';

/// Dictionnaire français -> Kreyòl de toute l'app, assemblé à partir
/// d'un fichier par partie de l'app (auth, client, commandes, vendeur,
/// commun). Clé = texte français exact utilisé dans le code.
final Map<String, String> kreyol = {
  ...kreyolCommun,
  ...kreyolAuth,
  ...kreyolClient,
  ...kreyolCommandes,
  ...kreyolVendeur,
};
