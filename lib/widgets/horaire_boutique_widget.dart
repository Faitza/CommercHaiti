import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/shop_model.dart';
import '../services/database_service.dart';

/// Horaire boutique — Faitza COLAS
/// Branch : feature/shop-hours
/// Path : lib/widgets/horaire_boutique_widget.dart
///
/// Deux widgets liés à l'horaire automatique des boutiques :
///  - HoraireBoutiqueWidget : choix de l'heure d'ouverture / fermeture
///    (TimePicker) et des jours de travail (cases Lundi → Samedi).
///    Utilisé dans create_shop_screen, settings_screen et
///    vendor_edit_shop_screen. L'état appartient à l'écran parent.
///  - ForcerStatutWidget : statut actuel + boutons "Ouvrir maintenant" /
///    "Fermer maintenant" (colonne `is_open_manuel`), et retour à
///    l'horaire automatique.
class HoraireBoutiqueWidget extends StatelessWidget {
  final TimeOfDay? ouverture;
  final TimeOfDay? fermeture;
  final List<String> jours;
  final ValueChanged<TimeOfDay> onOuvertureChanged;
  final ValueChanged<TimeOfDay> onFermetureChanged;
  final ValueChanged<List<String>> onJoursChanged;
  final bool isDark;

  const HoraireBoutiqueWidget({
    super.key,
    required this.ouverture,
    required this.fermeture,
    required this.jours,
    required this.onOuvertureChanged,
    required this.onFermetureChanged,
    required this.onJoursChanged,
    required this.isDark,
  });

  /// TimeOfDay → "HH:mm" (format envoyé aux colonnes TIME Supabase).
  static String? versTexte(TimeOfDay? t) => t == null
      ? null
      : '${t.hour.toString().padLeft(2, '0')}:'
          '${t.minute.toString().padLeft(2, '0')}';

  /// "HH:mm" (ou "HH:mm:ss") → TimeOfDay ; null si absent ou invalide.
  static TimeOfDay? depuisTexte(String? s) {
    if (s == null) return null;
    final p = s.split(':');
    if (p.length < 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  Future<void> _choisir(BuildContext context, TimeOfDay? actuelle,
      TimeOfDay parDefaut, ValueChanged<TimeOfDay> onChoisie) async {
    final t = await showTimePicker(
      context: context,
      initialTime: actuelle ?? parDefaut,
    );
    if (t != null) onChoisie(t);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: _heure(context, 'Ouverture', ouverture,
              const TimeOfDay(hour: 8, minute: 0), onOuvertureChanged)),
          const SizedBox(width: 12),
          Expanded(child: _heure(context, 'Fermeture', fermeture,
              const TimeOfDay(hour: 18, minute: 0), onFermetureChanged)),
        ]),
        const SizedBox(height: 12),
        Text('Jours de travail',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimaryFor(isDark))),
        const SizedBox(height: 4),
        Wrap(
          children: ShopModel.joursSemaine.map((jour) {
            final coche = jours.contains(jour);
            return SizedBox(
              width: 150,
              child: CheckboxListTile(
                value: coche,
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppColors.navy,
                title: Text(jour,
                    style: TextStyle(color: AppColors.textPrimaryFor(isDark))),
                onChanged: (v) => onJoursChanged(ShopModel.joursSemaine
                    .where((j) => j == jour ? v == true : jours.contains(j))
                    .toList()),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _heure(BuildContext context, String libelle, TimeOfDay? valeur,
      TimeOfDay parDefaut, ValueChanged<TimeOfDay> onChoisie) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _choisir(context, valeur, parDefaut, onChoisie),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.inputFill(isDark),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Icon(Icons.access_time, size: 18, color: AppColors.accentFor(isDark)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(libelle,
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondaryFor(isDark))),
                Text(versTexte(valeur) ?? '--:--',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryFor(isDark))),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

/// Statut actuel de la boutique + forçage manuel. Chaque bouton écrit
/// immédiatement `is_open_manuel` en base, puis appelle `onChanged` pour
/// que l'écran parent recharge la boutique.
class ForcerStatutWidget extends StatefulWidget {
  final ShopModel shop;
  final VoidCallback onChanged;
  final bool isDark;

  const ForcerStatutWidget({
    super.key,
    required this.shop,
    required this.onChanged,
    required this.isDark,
  });

  @override
  State<ForcerStatutWidget> createState() => _ForcerStatutWidgetState();
}

class _ForcerStatutWidgetState extends State<ForcerStatutWidget> {
  bool _isSaving = false;

  Future<void> _forcer(bool? valeur) async {
    setState(() => _isSaving = true);
    try {
      await DatabaseService()
          .updateShop(widget.shop.id, {'is_open_manuel': valeur});
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : ${e.toString()}'),
          backgroundColor: AppColors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shop = widget.shop;
    final ouverte = shop.isOpen;
    final String detail;
    if (shop.isOpenManuel != null) {
      detail = 'Forcé manuellement';
    } else if (shop.aUnHoraire) {
      detail = 'Automatique · ${shop.horaireOuverture} – '
          '${shop.horaireFermeture}';
    } else {
      detail = 'Aucun horaire défini';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ouverte ? AppColors.green : AppColors.red,
            ),
          ),
          const SizedBox(width: 8),
          Text(ouverte ? 'Ouverte maintenant' : 'Fermée maintenant',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryFor(widget.isDark))),
          const SizedBox(width: 6),
          Flexible(
            child: Text('· $detail',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryFor(widget.isDark))),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isSaving || shop.isOpenManuel == true
                  ? null
                  : () => _forcer(true),
              child: const Text('Ouvrir maintenant',
                  style: TextStyle(color: Colors.white)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isSaving || shop.isOpenManuel == false
                  ? null
                  : () => _forcer(false),
              child: const Text('Fermer maintenant',
                  style: TextStyle(color: Colors.white)),
            ),
          ),
        ]),
        // Le forçage reste actif jusqu'au retour à l'horaire automatique.
        if (shop.isOpenManuel != null)
          TextButton.icon(
            onPressed: _isSaving ? null : () => _forcer(null),
            icon: const Icon(Icons.schedule, size: 18),
            label: const Text('Revenir à l\'horaire automatique'),
          ),
      ],
    );
  }
}
