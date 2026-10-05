import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Image distante mise en cache — checklist production (point 16)
/// Path : lib/widgets/image_reseau_widget.dart
///
/// Remplace `Image.network` : une photo produit ou un logo déjà
/// téléchargé est gardé sur le téléphone et n'est plus re-téléchargé à
/// chaque affichage (économie de données mobiles + affichage immédiat).
/// Pendant le chargement on affiche un fond neutre (point 05) et, si
/// l'image est introuvable, une icône au lieu d'une erreur (point 07).
class ImageReseau extends StatelessWidget {
  final String url;
  final BoxFit? fit;
  final double? width;
  final double? height;
  /// Widget affiché si l'image ne peut pas être chargée.
  final Widget? siErreur;

  const ImageReseau(
    this.url, {
    super.key,
    this.fit,
    this.width,
    this.height,
    this.siErreur,
  });

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      width: width,
      height: height,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (_, __) => Container(color: const Color(0xFFEEF3FB)),
      errorWidget: (_, __, ___) =>
          siErreur ??
          Container(
            color: const Color(0xFFEEF3FB),
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image_outlined,
                color: Color(0xFF0D2B5E)),
          ),
    );
  }
}
