import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/zones.dart';

/// Choix des zones de livraison — vendeur
/// Path : lib/widgets/zones_livraison_selecteur.dart
///
/// Menu déroulant des zones de la liste (Zones.toutes) et champ pour
/// écrire une autre zone si elle n'y est pas. Les zones choisies
/// s'affichent en dessous, chacune avec une croix pour la retirer.
/// Utilisé à la création de la boutique (create_shop_screen.dart) et
/// dans sa modification (vendor_edit_shop_screen.dart). La liste `zones`
/// appartient à l'écran parent, prévenu à chaque changement via
/// `onChanged`.
class ZonesLivraisonSelecteur extends StatefulWidget {
  final List<String> zones;
  final ValueChanged<List<String>> onChanged;
  final bool isDark;

  const ZonesLivraisonSelecteur({
    super.key,
    required this.zones,
    required this.onChanged,
    required this.isDark,
  });

  @override
  State<ZonesLivraisonSelecteur> createState() =>
      _ZonesLivraisonSelecteurState();
}

class _ZonesLivraisonSelecteurState extends State<ZonesLivraisonSelecteur> {
  final _autreCtrl = TextEditingController();

  bool _dejaChoisie(String zone) =>
      widget.zones.any((z) => Zones.memeZone(z, zone));

  void _ajouter(String zone) {
    final z = zone.trim();
    if (z.isEmpty) return;
    if (_dejaChoisie(z)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Cette zone est déjà dans la liste'),
        backgroundColor: Color(0xFFE63946),
      ));
      return;
    }
    // Une zone écrite à la main qui existe déjà dans la liste prend
    // l'orthographe de la liste, pour que le client la retrouve.
    final officielle = Zones.toutes
        .firstWhere((t) => Zones.memeZone(t, z), orElse: () => z);
    widget.onChanged([...widget.zones, officielle]);
  }

  @override
  void dispose() {
    _autreCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final restantes = Zones.toutes.where((z) => !_dejaChoisie(z)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Menu déroulant : choisir une zone l'ajoute tout de suite.
        DropdownButtonFormField<String>(
          key: ValueKey(widget.zones.length),
          isExpanded: true,
          decoration: const InputDecoration(
              labelText: 'Choisir une zone', isDense: true),
          items: restantes
              .map((z) => DropdownMenuItem(value: z, child: Text(z)))
              .toList(),
          onChanged: (z) {
            if (z != null) _ajouter(z);
          },
        ),
        const SizedBox(height: 12),
        // Autre zone, écrite par le vendeur.
        Row(children: [
          Expanded(
            child: TextField(
              controller: _autreCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  labelText: 'Autre zone (si elle n\'est pas dans la liste)',
                  isDense: true),
              onSubmitted: (v) {
                _ajouter(v);
                _autreCtrl.clear();
              },
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              _ajouter(_autreCtrl.text);
              _autreCtrl.clear();
            },
            child: const Text('Ajouter'),
          ),
        ]),
        if (widget.zones.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: widget.zones.map((z) => InputChip(
                  label: Text(z),
                  onDeleted: () => widget.onChanged(
                      widget.zones.where((e) => e != z).toList()),
                  backgroundColor: widget.isDark
                      ? AppColors.surface(widget.isDark)
                      : const Color(0xFFEEF3FB),
                )).toList(),
          ),
        ],
      ],
    );
  }
}
