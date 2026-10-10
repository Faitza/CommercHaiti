/// Liens externes de l'application — Faitza COLAS
/// Branch : feature/whatsapp-share
/// Path : lib/constants/app_links.dart
///
/// Centralise les URLs partagées hors de l'app (messages WhatsApp, etc.)
/// pour qu'un changement de lien se fasse à un seul endroit.
class AppLinks {
  /// Lien de téléchargement de l'app ajouté en bas des messages de
  /// partage WhatsApp.
  /// TODO : lien PROVISOIRE (dépôt GitHub) — à remplacer par le lien
  /// Play Store / APK définitif dès qu'il existe.
  static const String telechargementApp =
      'https://github.com/Faitza/CommercHaiti';

  /// Site web qui sert les liens produit partagés sur WhatsApp
  /// (hébergé sur Vercel avec l'admin web, voir dépôt CommercHaiti-admin,
  /// fichier api/produit.js). À changer ici ET dans
  /// android/app/src/main/AndroidManifest.xml si un vrai nom de domaine
  /// est acheté plus tard.
  static const String siteWeb = 'https://commerc-haiti-admin.vercel.app';

  /// Lien d'un produit : `https://…/p/<id>`. Clic sur le téléphone :
  ///  - app installée → l'app s'ouvre directement sur le produit
  ///    (route `/p/:id`, voir app_router.dart) ;
  ///  - app pas installée → page web du produit avec le bouton de
  ///    téléchargement de l'app.
  static String lienProduit(String productId) => '$siteWeb/p/$productId';
}
