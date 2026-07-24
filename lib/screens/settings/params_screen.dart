import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';

/// Paramètres Client — Falexson MERCIVAL
/// Branch : feature/ui-settings
/// Path : lib/screens/settings/params_screen.dart
///
/// Écran de paramètres côté CLIENT (pendant du SettingsScreen côté
/// vendeur). Structure et logique très similaires : gestion du profil
/// (nom, adresse, favoris), préférences de notification locales
/// (SharedPreferences), apparence (mode sombre via ThemeProvider),
/// changement de mot de passe (Supabase Auth) et déconnexion. La section
/// "boutique" du SettingsScreen vendeur est ici remplacée par une section
/// "Mon profil" adaptée au client.
class ParamsScreen extends StatefulWidget {
  const ParamsScreen({super.key});

  @override
  State<ParamsScreen> createState() => _ParamsScreenState();
}

class _ParamsScreenState extends State<ParamsScreen> {
  // Préférences de notification locales (persistées sur l'appareil via
  // SharedPreferences, indépendamment du compte/serveur) : être notifié
  // du suivi de ses commandes, et des promotions/offres.
  bool _notifCommande = true;
  bool _notifPromos = true;
  // Indique si le chargement initial des préférences est en cours.
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  // Charge les préférences de notification depuis le stockage local au
  // démarrage de l'écran.
  Future<void> _charger() async {
    final prefs = await SharedPreferences.getInstance();
    // `mounted` vérifié après le `await` : l'écran aurait pu être fermé
    // avant que SharedPreferences ait fini de répondre.
    if (mounted) {
      setState(() {
        _notifCommande = prefs.getBool('notif_suivi_commande') ?? true;
        _notifPromos = prefs.getBool('notif_promos') ?? true;
        _isLoading = false;
      });
    }
  }

  // Enregistre immédiatement une préférence booléenne dans
  // SharedPreferences dès qu'un switch est basculé par l'utilisateur.
  Future<void> _toggleNotifPref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  // Flux de changement de mot de passe : affiche une boîte de dialogue avec
  // un champ masqué, valide la longueur minimale, puis appelle
  // AuthProvider.updatePassword (qui utilise Supabase Auth `updateUser` en
  // interne pour changer le mot de passe du compte connecté).
  //
  // Remarque sur `BuildContext context` en paramètre : cette méthode reçoit
  // le `context` de l'appelant plutôt que d'utiliser le `context` implicite
  // du State, car elle est appelée depuis l'intérieur du `builder` de
  // ListTile dans `build()`. Après chaque `await` (attente de la boîte de
  // dialogue, puis appel réseau `updatePassword`), on revérifie
  // systématiquement `context.mounted` avant de réutiliser ce `context`
  // (pour afficher un SnackBar) : c'est le pattern classique
  // "use_build_context_synchronously" — un `BuildContext` peut devenir
  // invalide pendant une opération asynchrone si l'utilisateur a
  // entre-temps quitté l'écran, et l'utiliser dans ce cas provoquerait une
  // erreur ou un comportement indéfini.
  Future<void> _changerMotDePasse(BuildContext context) async {
    final ctrl = TextEditingController();
    // Affiche la boîte de dialogue et ATTEND que l'utilisateur la ferme.
    // `showDialog<String>` renvoie soit le texte saisi (si "Valider" est
    // pressé, via `Navigator.pop(context, ctrl.text)`), soit `null` (si
    // l'utilisateur annule ou ferme la boîte autrement).
    final nouveau = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Changer le mot de passe'),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          decoration: const InputDecoration(
              hintText: 'Nouveau mot de passe (min. 6 caractères)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D2B5E)),
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text('Valider', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    // Annulation ou champ vide : on ne fait rien de plus.
    if (nouveau == null || nouveau.isEmpty) return;
    // Validation locale simple (côté client) de la longueur minimale, avant
    // même de contacter le serveur — évite un aller-retour réseau inutile
    // pour un mot de passe qui serait de toute façon rejeté.
    if (nouveau.length < 6) {
      // Vérification `context.mounted` après le `await showDialog` :
      // l'écran aurait pu être fermé pendant que la boîte de dialogue était
      // ouverte.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Mot de passe trop court — minimum 6 caractères'),
          backgroundColor: Color(0xFFE63946),
        ));
      }
      return;
    }
    try {
      // Appel réseau vers Supabase Auth pour effectivement changer le mot
      // de passe du compte actuellement connecté.
      await context.read<AuthProvider>().updatePassword(nouveau);
      // Nouvelle vérification `context.mounted` après ce second `await`.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Mot de passe modifié avec succès'),
          backgroundColor: Color(0xFF1D9E75),
        ));
      }
    } catch (e) {
      // En cas d'erreur (ex. session expirée, problème réseau), on informe
      // l'utilisateur avec le message d'erreur brut.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : ${e.toString()}'),
          backgroundColor: const Color(0xFFE63946),
        ));
      }
    }
  }

  // Flux de déconnexion : demande confirmation, puis appelle
  // AuthProvider.signOut() (déconnexion Supabase Auth) et redirige vers
  // l'écran de sélection de rôle.
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
    if (confirm == true) {
      // Attente de la déconnexion effective côté Supabase avant de
      // naviguer, pour être sûr que la session est bien terminée.
      await context.read<AuthProvider>().signOut();
      // `context.mounted` revérifié après ce `await`.
      // `context.go('/role-selection')` REMPLACE toute la pile de
      // navigation (au lieu de push()) : c'est essentiel ici, car on ne
      // veut surtout pas qu'un utilisateur déconnecté puisse appuyer sur
      // "retour" pour se retrouver de nouveau sur un écran protégé de
      // l'application (paramètres, accueil client...).
      if (context.mounted) context.go('/role-selection');
    }
  }

  @override
  Widget build(BuildContext context) {
    // `watch` : on veut que le switch "Mode sombre" et les infos du
    // profil se rafraîchissent automatiquement si le thème ou
    // l'utilisateur connecté changent pendant que cet écran est affiché.
    final theme = context.watch<ThemeProvider>();
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B5E),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          // Navigator.of(context).pop() (et non context.go()) : cet écran
          // est atteint en empilant une route (push depuis l'accueil
          // client), donc un simple retour en arrière classique est
          // adapté et sûr ici.
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Paramètres'),
      ),
      // Spinner tant que le chargement initial (_charger()) n'est pas
      // terminé, sinon la liste complète des réglages.
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _sectionTitle('Mon profil'),
                // Ces items naviguent vers l'écran d'édition de profil ou
                // de favoris ; `push()` (empile la route) car on veut
                // revenir naturellement à cet écran de paramètres après
                // édition.
                _item(Icons.person_outline, 'Informations personnelles',
                    user?.nom, () => context.push('/client/edit-profile')),
                _item(Icons.location_on_outlined, 'Adresse de livraison',
                    user?.adresse, () => context.push('/client/edit-profile')),
                _item(Icons.favorite_border, 'Mes favoris', null,
                    () => context.push('/client/favorites')),
                const Divider(),

                _sectionTitle('Notifications'),
                // Ces switches ne touchent que le stockage local
                // (SharedPreferences), donc mise à jour instantanée, sans
                // requête serveur.
                _switchItem(Icons.local_shipping_outlined,
                    'Suivi de commande', 'Statut, livraison',
                    _notifCommande, (v) {
                  setState(() => _notifCommande = v);
                  _toggleNotifPref('notif_suivi_commande', v);
                }),
                _switchItem(Icons.local_offer_outlined,
                    'Promotions', 'Nouvelles offres et réductions',
                    _notifPromos, (v) {
                  setState(() => _notifPromos = v);
                  _toggleNotifPref('notif_promos', v);
                }),
                const Divider(),

                _sectionTitle('Apparence'),
                // Switch "Mode sombre" : délègue au ThemeProvider, qui
                // applique le changement à toute l'application.
                _switchItem(Icons.dark_mode_outlined, 'Mode sombre', null,
                    theme.isDarkMode,
                    (v) => context.read<ThemeProvider>().toggle(v)),
                const Divider(),

                _sectionTitle('Sécurité'),
                _item(Icons.lock_outline, 'Changer le mot de passe', null,
                    () => _changerMotDePasse(context)),
                const Divider(),

                _sectionTitle('À propos'),
                // Items informatifs : `onTap` à `null` pour les deux,
                // donc pas de flèche ">" ni de réaction au clic (voir
                // `_item` plus bas).
                _item(Icons.info_outline, 'CommercHaiti v1.0',
                    'ITAC · 2025-2026', null),
                _item(Icons.privacy_tip_outlined, 'Confidentialité', null, null),
                const SizedBox(height: 16),

                // Bouton de déconnexion, mis en évidence visuellement
                // (fond rouge clair, texte rouge) pour signaler une action
                // sensible.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Material(
                    color: const Color(0xFFFCE9E9),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _deconnecter(context),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Center(
                          child: Text('Déconnexion',
                              style: TextStyle(
                                  color: Color(0xFFE63946),
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  // Petit helper : titre de section en majuscules (ex. "MON PROFIL"),
  // utilisé pour regrouper visuellement les items ci-dessous en catégories.
  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(t.toUpperCase(),
            style: const TextStyle(fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF999999), letterSpacing: 1)),
      );

  // Petit helper : ligne de paramètre standard (icône + titre + sous-titre
  // optionnel + flèche ">" si cliquable). Si `onTap` est `null`, l'item
  // devient purement informatif (pas de flèche, pas de réaction au clic).
  Widget _item(IconData icon, String label, String? sous, VoidCallback? onTap) =>
      ListTile(
        tileColor: Colors.white,
        leading: Icon(icon, color: const Color(0xFF0D2B5E)),
        title: Text(label,
            style: const TextStyle(
                color: Color(0xFF1A1F36), fontWeight: FontWeight.w600)),
        subtitle: sous != null && sous.isNotEmpty
            ? Text(sous, style: const TextStyle(fontSize: 12))
            : null,
        trailing: onTap != null
            ? const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC))
            : null,
        onTap: onTap,
      );

  // Petit helper : ligne de paramètre avec interrupteur on/off
  // (SwitchListTile), utilisée pour tous les réglages booléens de l'écran
  // (notifications, mode sombre).
  Widget _switchItem(IconData icon, String label, String? sous,
          bool value, ValueChanged<bool> onChanged) =>
      SwitchListTile(
        tileColor: Colors.white,
        secondary: Icon(icon, color: const Color(0xFF0D2B5E)),
        title: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: sous != null ? Text(sous, style: const TextStyle(fontSize: 12)) : null,
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF1D9E75),
      );
}
