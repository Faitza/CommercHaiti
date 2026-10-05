import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';
import '../constants/app_links.dart';
import '../models/product_model.dart';
import '../services/database_service.dart';

/// Bouton "Partager sur WhatsApp" (produit) — Faitza COLAS
/// Branch : feature/whatsapp-share
/// Path : lib/widgets/whatsapp_share_product_widget.dart
///
/// Bouton réutilisable qui ouvre WhatsApp avec un message pré-écrit
/// présentant un produit : nom, prix, nom de la boutique, puis le lien de
/// téléchargement de l'app en bas du message. Le vendeur choisit ensuite
/// lui-même le contact ou le groupe destinataire dans WhatsApp.
///
/// Si le produit a des photos, elles sont téléchargées puis partagées
/// avec le message (feuille de partage du téléphone : le vendeur y choisit
/// WhatsApp). Si aucune photo ne se télécharge, on retombe sur l'ancien
/// partage texte via wa.me.
///
/// Utilisé à deux endroits (même bouton) :
///  - après l'ajout d'un produit (vendor_add_product_screen.dart)
///  - sur chaque carte produit (vendor_products_screen.dart)
class WhatsAppShareProductWidget extends StatefulWidget {
  final ProductModel product;
  // Nom de la boutique si déjà connu ; sinon il est lu dans Supabase
  // (table `shops`) au moment du clic.
  final String? nomBoutique;

  const WhatsAppShareProductWidget({
    super.key,
    required this.product,
    this.nomBoutique,
  });

  /// Construit le texte du message WhatsApp. Si le produit est en promo,
  /// le prix promo est affiché, suivi du prix normal entre parenthèses.
  static String construireMessage(ProductModel product, String nomBoutique) {
    final prix = product.hasPromo
        ? '${product.prixPromo!.toStringAsFixed(0)} HTG '
            '(au lieu de ${product.prix.toStringAsFixed(0)} HTG)'
        : '${product.prix.toStringAsFixed(0)} HTG';
    return '🛍️ *${product.nom}*\n'
        '💰 Prix : $prix\n'
        '🏪 Boutique : $nomBoutique\n'
        '\n'
        '📲 Commandez sur CommercHaiti, téléchargez l\'app :\n'
        '${AppLinks.telechargementApp}';
  }

  @override
  State<WhatsAppShareProductWidget> createState() =>
      _WhatsAppShareProductWidgetState();
}

class _WhatsAppShareProductWidgetState
    extends State<WhatsAppShareProductWidget> {
  bool _isLoading = false;

  /// Récupère le nom de la boutique (si non fourni) et construit le
  /// message, puis partage les photos + le message. Sans photo
  /// téléchargeable (ou sur le web), ouvre `https://wa.me/?text=...` :
  /// sans numéro, WhatsApp propose de choisir le destinataire.
  Future<void> _partager() async {
    setState(() => _isLoading = true);
    try {
      var nomBoutique = widget.nomBoutique;
      if (nomBoutique == null || nomBoutique.isEmpty) {
        final shop = await DatabaseService().getShop(widget.product.shopId);
        nomBoutique = shop?.nom ?? 'CommercHaiti';
      }
      final message = WhatsAppShareProductWidget.construireMessage(
          widget.product, nomBoutique);
      final photos = kIsWeb ? <XFile>[] : await _telechargerPhotos();
      if (photos.isNotEmpty) {
        // WhatsApp garde le texte comme légende de la première photo.
        await Share.shareXFiles(photos, text: message);
      } else {
        await _partagerTexte(message);
      }
    } catch (_) {
      if (mounted) _erreur();
    }
    if (mounted) setState(() => _isLoading = false);
  }

  /// Télécharge toutes les photos du produit (une photo qui échoue est
  /// simplement ignorée). Retourne une liste vide si aucune n'a réussi.
  Future<List<XFile>> _telechargerPhotos() async {
    final fichiers = <XFile>[];
    final urls = widget.product.photos;
    for (var i = 0; i < urls.length; i++) {
      try {
        final rep = await http
            .get(Uri.parse(urls[i]))
            .timeout(const Duration(seconds: 15));
        if (rep.statusCode != 200 || rep.bodyBytes.isEmpty) continue;
        final type = rep.headers['content-type'] ?? 'image/jpeg';
        final ext = type.contains('png')
            ? 'png'
            : type.contains('webp')
                ? 'webp'
                : 'jpg';
        fichiers.add(XFile.fromData(rep.bodyBytes,
            name: 'produit-${i + 1}.$ext', mimeType: type));
      } catch (_) {
        // Photo injoignable : on continue avec les autres.
      }
    }
    return fichiers;
  }

  /// Ancien partage : texte seul via wa.me. Même stratégie que
  /// WhatsAppButtonWidget : `launchUrl` direct dans un try/catch (pas de
  /// `canLaunchUrl`, peu fiable sur Android 11+).
  Future<void> _partagerTexte(String message) async {
    final url = Uri.parse(
        'https://wa.me/?text=${Uri.encodeComponent(message)}');
    final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!ok && mounted) _erreur();
  }

  void _erreur() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Impossible d\'ouvrir WhatsApp — vérifiez qu\'il est installé'),
      backgroundColor: AppColors.red,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.whatsapp,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
        icon: _isLoading
            ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.share, color: Colors.white, size: 18),
        label: const Text(
          'Partager sur WhatsApp',
          style: TextStyle(color: Colors.white, fontSize: 14),
        ),
        onPressed: _isLoading ? null : _partager,
      ),
    );
  }
}
