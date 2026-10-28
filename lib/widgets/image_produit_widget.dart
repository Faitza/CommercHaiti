import 'package:flutter/material.dart';

import 'image_reseau_widget.dart';
import '../l10n/traduction.dart';

/// Photo d'un produit, avec une image par défaut propre quand le vendeur
/// n'a pas mis de photo (ou quand la photo ne se charge pas) : fond bleu
/// clair dégradé, sac de courses et, si la place le permet, « Pas de
/// photo ». Remplace les anciennes icônes grises dispersées dans chaque
/// écran, pour que toutes les cartes produit se ressemblent.
class ImageProduit extends StatelessWidget {
  /// URL de la photo ; null ou vide = image par défaut.
  final String? url;
  final BoxFit fit;
  final double? width;
  final double? height;

  const ImageProduit(
    this.url, {
    super.key,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final u = url;
    if (u == null || u.isEmpty) {
      return ImageProduitParDefaut(width: width, height: height);
    }
    return ImageReseau(u,
        fit: fit,
        width: width,
        height: height,
        siErreur: ImageProduitParDefaut(width: width, height: height));
  }
}

/// L'image par défaut seule (voir [ImageProduit]).
class ImageProduitParDefaut extends StatelessWidget {
  final double? width;
  final double? height;
  const ImageProduitParDefaut({super.key, this.width, this.height});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cote = c.biggest.shortestSide.isFinite
          ? c.biggest.shortestSide
          : (height ?? width ?? 100);
      final avecTexte = cote >= 90;
      return Container(
        width: width ?? double.infinity,
        height: height ?? double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEEF3FB), Color(0xFFD9E4F5)],
          ),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_bag_outlined,
                size: (cote * 0.32).clamp(18, 64).toDouble(),
                color: const Color(0xFF7A93BD)),
            if (avecTexte) ...[
              const SizedBox(height: 4),
              Text(context.tr('Pas de photo'),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF5A6F94))),
            ],
          ],
        ),
      );
    });
  }
}
