import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'langue_provider.dart';
import 'traduction.dart';

/// Choix de la langue : Kreyòl / Français. Utilisé dans les Paramètres
/// (client et vendeur) et sur l'écran de choix du rôle (visiteur).
/// Les deux libellés restent chacun dans sa propre langue, pour que
/// tout le monde retrouve la sienne.
class LangueSelecteur extends StatelessWidget {
  const LangueSelecteur({super.key});

  @override
  Widget build(BuildContext context) {
    final langue = context.watch<LangueProvider>().langue;
    return SegmentedButton<Langue>(
      segments: const [
        ButtonSegment(value: Langue.ht, label: Text('Kreyòl')),
        ButtonSegment(value: Langue.fr, label: Text('Français')),
      ],
      selected: {langue},
      showSelectedIcon: false,
      onSelectionChanged: (s) =>
          context.read<LangueProvider>().choisir(s.first),
    );
  }
}

/// Ligne « Langue » pour les écrans Paramètres.
class LangueParametreTile extends StatelessWidget {
  final bool isDark;
  const LangueParametreTile({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        const Icon(Icons.language, size: 22),
        const SizedBox(width: 14),
        Expanded(child: Text(context.tr('Langue'))),
        const LangueSelecteur(),
      ]),
    );
  }
}
