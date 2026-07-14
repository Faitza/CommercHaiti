import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Bouton WhatsApp — Falexson MERCIVAL
/// Branch : feature/ui-settings
/// Path : lib/widgets/whatsapp_button_widget.dart
class WhatsAppButtonWidget extends StatelessWidget {
  final String telephone;
  final String? label;
  final bool compact; // true = icône seulement

  const WhatsAppButtonWidget({
    super.key,
    required this.telephone,
    this.label,
    this.compact = false,
  });

  Future<void> _ouvrir() async {
    final numero = telephone.replaceAll(RegExp(r'[^\d+]'), '');
    final url = Uri.parse('https://wa.me/$numero');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return IconButton(
        onPressed: _ouvrir,
        icon: const Icon(Icons.chat, color: Color(0xFF25D366)),
        tooltip: 'Contacter via WhatsApp',
      );
    }

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
        onPressed: _ouvrir,
      ),
    );
  }
}