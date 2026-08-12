import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Bouton WhatsApp — Falexson MERCIVAL
/// Branch : feature/ui-settings
/// Path : lib/widgets/whatsapp_button_widget.dart
///
/// Bouton réutilisable qui ouvre une conversation WhatsApp avec un numéro
/// de téléphone donné (client -> vendeur ou l'inverse), via le lien
/// universel `https://wa.me/<numero>` supporté par WhatsApp sur toutes les
/// plateformes (ouvre l'app si installée, sinon WhatsApp Web).
class WhatsAppButtonWidget extends StatelessWidget {
  // Numéro de téléphone brut (peut contenir espaces, tirets, etc. — sera
  // nettoyé avant utilisation).
  final String telephone;
  // Texte du bouton ; si null, un libellé par défaut est utilisé.
  final String? label;
  final bool compact; // true = icône seulement

  const WhatsAppButtonWidget({
    super.key,
    required this.telephone,
    this.label,
    this.compact = false,
  });

  /// Nettoie le numéro de téléphone (garde uniquement les chiffres et le
  /// signe '+', supprime espaces/tirets/parenthèses via une regex), puis
  /// construit l'URL `wa.me` et l'ouvre dans une application externe
  /// (WhatsApp). On tente directement `launchUrl` (avec try/catch) plutôt
  /// que de se fier uniquement à `canLaunchUrl` : sur Android 11+, sans la
  /// déclaration `<queries>` correspondante dans AndroidManifest.xml,
  /// `canLaunchUrl` peut renvoyer `false` même quand WhatsApp est bel et
  /// bien installé (restriction de "package visibility"), ce qui bloquait
  /// silencieusement le bouton — désormais on affiche un message d'erreur
  /// explicite si l'ouverture échoue vraiment, au lieu de ne rien faire.
  Future<void> _ouvrir(BuildContext context) async {
    final numero = telephone.replaceAll(RegExp(r'[^\d+]'), '');
    final url = Uri.parse('https://wa.me/$numero');
    try {
      final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) _erreur(context);
    } catch (_) {
      if (context.mounted) _erreur(context);
    }
  }

  void _erreur(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Impossible d\'ouvrir WhatsApp — vérifiez qu\'il est installé'),
      backgroundColor: Color(0xFFE63946),
    ));
  }

  @override
  Widget build(BuildContext context) {
    // Mode compact : juste une icône (utile dans un espace réduit, ex.
    // ligne de liste), sans texte.
    if (compact) {
      return IconButton(
        onPressed: () => _ouvrir(context),
        icon: const Icon(Icons.chat, color: Color(0xFF25D366)), // vert WhatsApp officiel
        tooltip: 'Contacter via WhatsApp',
      );
    }

    // Mode normal : bouton pleine largeur avec icône + texte, couleur
    // verte de la marque WhatsApp, coins arrondis.
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF25D366),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
        icon: const Icon(Icons.chat, color: Colors.white, size: 18),
        label: Text(
          label ?? 'Contacter via WhatsApp',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        onPressed: () => _ouvrir(context),
      ),
    );
  }
}