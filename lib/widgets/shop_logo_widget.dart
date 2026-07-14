import 'package:flutter/material.dart';

/// Logo boutique — Falexson MERCIVAL
/// Branch : feature/ui-settings
/// Path : lib/widgets/shop_logo_widget.dart
/// Affiche photo si logoURL existe, sinon initiales colorées
class ShopLogoWidget extends StatelessWidget {
  final String? logoURL;
  final String initiales;
  final double size;

  const ShopLogoWidget({
    super.key,
    this.logoURL,
    required this.initiales,
    this.size = 50,
  });

  // Couleur de fond selon initiales (déterministe)
  Color _couleurFond() {
    final couleurs = [
      const Color(0xFF0D2B5E),
      const Color(0xFF1D6A3A),
      const Color(0xFF6B21A8),
      const Color(0xFF0891B2),
      const Color(0xFF7A4F00),
      const Color(0xFF8B1A1A),
    ];
    final index = initiales.codeUnitAt(0) % couleurs.length;
    return couleurs[index];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.2),
        color: _couleurFond(),
      ),
      clipBehavior: Clip.antiAlias,
      child: logoURL != null && logoURL!.isNotEmpty
          ? Image.network(
              logoURL!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _initialesWidget(),
            )
          : _initialesWidget(),
    );
  }

  Widget _initialesWidget() => Center(
        child: Text(
          initiales.length > 2 ? initiales.substring(0, 2) : initiales,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.35,
          ),
        ),
      );
}