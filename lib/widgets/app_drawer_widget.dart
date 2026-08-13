import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../constants/app_colors.dart';

/// Représente une entrée du menu (icône + libellé + action au clic).
/// `onTap` est optionnel : si non fourni, un comportement par défaut
/// ("Bientôt disponible") est utilisé dans le build ci-dessous — pratique
/// pour lister des fonctionnalités pas encore implémentées sans avoir à
/// écrire un callback pour chacune.
class DrawerMenuItem {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const DrawerMenuItem(this.icon, this.label, {this.onTap});
}

/// Menu hamburger partagé (Client & Vendeur) — section 12.2 du cahier des charges
/// Path : lib/widgets/app_drawer_widget.dart
///
/// Widget de menu latéral (`Drawer`) générique, réutilisé à la fois côté
/// client et côté vendeur : le contenu (titre d'en-tête, sous-titre, liste
/// d'items) est injecté depuis l'écran appelant, ce qui évite de dupliquer
/// deux drawers quasi identiques.
class AppDrawerWidget extends StatelessWidget {
  // Titre affiché dans le bandeau d'en-tête (ex. nom de l'utilisateur ou
  // de la boutique).
  final String headerTitle;
  // Sous-titre sous le titre (ex. email ou rôle).
  final String headerSubtitle;
  // Liste des entrées de menu spécifiques à l'écran appelant (Client ou
  // Vendeur ont des menus différents).
  final List<DrawerMenuItem> items;
  // Route vers laquelle naviguer quand l'utilisateur clique sur
  // "Paramètres" (différente pour client/vendeur).
  final String settingsRoute;

  const AppDrawerWidget({
    super.key,
    required this.headerTitle,
    required this.headerSubtitle,
    required this.items,
    required this.settingsRoute,
  });

  /// Gère la déconnexion : affiche d'abord une boîte de dialogue de
  /// confirmation (pour éviter une déconnexion accidentelle), puis si
  /// l'utilisateur confirme : ferme le drawer, appelle
  /// `AuthProvider.signOut()` (qui déclenche `AuthService.signOut()` côté
  /// Supabase), et redirige vers l'écran de sélection de rôle.
  /// Les vérifications `context.mounted` évitent d'utiliser un
  /// BuildContext après qu'un `await` ait pu démonter le widget
  /// (protection standard Flutter contre les erreurs asynchrones).
  Future<void> _deconnecter(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE63946)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Déconnexion',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      Navigator.pop(context); // ferme le drawer
      await context.read<AuthProvider>().signOut();
      if (context.mounted) context.go('/role-selection');
    }
  }

  @override
  Widget build(BuildContext context) {
    // `context.watch` s'abonne au ThemeProvider : le widget se reconstruit
    // automatiquement si le mode sombre change ailleurs dans l'app,
    // gardant le switch synchronisé avec l'état réel.
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;

    return Drawer(
      backgroundColor: AppColors.surface(isDark),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Bandeau d'en-tête (fond bleu marine, titre + sous-titre) ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: const Color(0xFF0D2B5E),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(headerTitle,
                      style: const TextStyle(color: Colors.white,
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(headerSubtitle,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            // ── Liste des items de menu (scrollable, prend l'espace restant) ──
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Génère une ListTile par item passé en paramètre. Si
                  // l'item n'a pas de callback `onTap` propre, on ferme le
                  // drawer et on affiche un SnackBar "Bientôt disponible"
                  // (comportement par défaut pour les fonctionnalités pas
                  // encore développées).
                  for (final item in items)
                    ListTile(
                      leading: Icon(item.icon, color: AppColors.accentFor(isDark)),
                      title: Text(item.label,
                          style: TextStyle(color: AppColors.textPrimaryFor(isDark))),
                      onTap: item.onTap ??
                          () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Bientôt disponible')),
                            );
                          },
                    ),
                  // Entrée "Paramètres" fixe, commune à tous les écrans qui
                  // utilisent ce drawer — navigue vers `settingsRoute`
                  // (différente selon client/vendeur).
                  ListTile(
                    leading: Icon(Icons.settings_outlined,
                        color: AppColors.accentFor(isDark)),
                    title: Text('Paramètres',
                        style: TextStyle(color: AppColors.textPrimaryFor(isDark))),
                    onTap: () {
                      Navigator.pop(context);
                      context.push(settingsRoute);
                    },
                  ),
                  // Interrupteur "Mode sombre" fixe, relié directement au
                  // ThemeProvider global — change le thème de toute l'app.
                  SwitchListTile(
                    secondary: Icon(Icons.dark_mode_outlined,
                        color: AppColors.accentFor(isDark)),
                    title: Text('Mode sombre',
                        style: TextStyle(color: AppColors.textPrimaryFor(isDark))),
                    value: theme.isDarkMode,
                    activeColor: const Color(0xFF0D2B5E),
                    onChanged: (v) => context.read<ThemeProvider>().toggle(v),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // ── Bouton déconnexion, toujours en bas, en rouge ──
            ListTile(
              leading: const Icon(Icons.logout, color: Color(0xFFE63946)),
              title: const Text('Déconnexion',
                  style: TextStyle(color: Color(0xFFE63946))),
              onTap: () => _deconnecter(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
