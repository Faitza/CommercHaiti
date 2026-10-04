import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Widgets d'état communs — checklist production (points 05, 06, 07)
/// Path : lib/widgets/etat_widgets.dart
///
/// Trois états qu'un écran qui charge des données doit toujours savoir
/// afficher, au lieu d'un écran blanc ou d'une liste vide trompeuse :
/// - ChargementWidget : les données arrivent (point 05)
/// - EtatVideWidget   : la requête a réussi mais il n'y a rien (point 06)
/// - EtatErreurWidget : la requête a échoué, avec un bouton Réessayer
///   (points 07 et 08)

/// Indicateur de chargement centré, avec un texte optionnel.
class ChargementWidget extends StatelessWidget {
  final String? message;
  const ChargementWidget({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (message != null) ...[
              const SizedBox(height: 12),
              Text(message!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Message affiché quand il n'y a rien à montrer (liste vide, recherche
/// sans résultat...).
class EtatVideWidget extends StatelessWidget {
  final IconData icone;
  final String message;
  final String? detail;
  const EtatVideWidget({
    super.key,
    required this.message,
    this.icone = Icons.inbox_outlined,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 56, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            if (detail != null) ...[
              const SizedBox(height: 6),
              Text(detail!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textHint)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Message d'erreur avec bouton « Réessayer ». [message] doit être un
/// texte compréhensible par l'utilisateur (voir messageErreur()).
class EtatErreurWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onReessayer;
  const EtatErreurWidget({
    super.key,
    required this.message,
    this.onReessayer,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined,
                size: 56, color: AppColors.red),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary)),
            if (onReessayer != null) ...[
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: onReessayer,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Réessayer'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bouton « Charger plus » en bas d'une liste paginée (point 13).
class ChargerPlusWidget extends StatelessWidget {
  final bool enCours;
  final VoidCallback onCharger;
  const ChargerPlusWidget({
    super.key,
    required this.enCours,
    required this.onCharger,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: enCours
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5))
            : OutlinedButton(
                onPressed: onCharger,
                child: const Text('Charger plus'),
              ),
      ),
    );
  }
}
