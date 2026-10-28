import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/traduction.dart';
import '../providers/connexion_provider.dart';

/// Bandeau « Pas de connexion Internet » affiché en haut de TOUS les
/// écrans quand le téléphone n'a plus de réseau (voir ConnexionProvider).
/// Branché une seule fois dans MaterialApp.router(builder: ...) ; il
/// disparaît tout seul quand le réseau revient.
class BandeauHorsLigne extends StatelessWidget {
  final Widget child;
  const BandeauHorsLigne({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final enLigne = context.watch<ConnexionProvider>().enLigne;
    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: enLigne
              ? const SizedBox(width: double.infinity)
              : Material(
                  color: const Color(0xFF3A3A3A),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(children: [
                        const Icon(Icons.wifi_off, color: Colors.white, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            context.tr(
                                'Pas de connexion Internet. Les informations '
                                'affichées ne sont peut-être pas à jour.'),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
        ),
        // Sous le bandeau, l'écran ne doit pas réserver une 2e fois la
        // place de la barre d'état (déjà prise par le bandeau).
        Expanded(
          child: enLigne
              ? child
              : MediaQuery.removePadding(
                  context: context, removeTop: true, child: child),
        ),
      ],
    );
  }
}
