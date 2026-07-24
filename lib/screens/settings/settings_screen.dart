import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/database_service.dart';
import '../../models/shop_model.dart';

/// Paramètres Vendeur — Falexson MERCIVAL
/// Branch : feature/ui-settings
/// Path : lib/screens/settings/settings_screen.dart
///
/// Écran de paramètres côté VENDEUR (pendant du ParamsScreen côté client).
/// Regroupe : gestion basique de la boutique (logo, infos, zones, ouverture/
/// suspension), préférences de notifications (stockées localement via
/// SharedPreferences), apparence (mode sombre via ThemeProvider),
/// changement de mot de passe (Supabase Auth) et déconnexion.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Service d'accès à la base de données (lecture/écriture de la boutique).
  final _db = DatabaseService();
  // Boutique du vendeur connecté, chargée de façon asynchrone dans
  // `_charger()`. Reste `null` tant que le chargement n'est pas terminé.
  ShopModel? _shop;
  // Préférences de notification locales (stockées sur l'appareil via
  // SharedPreferences, pas en base de données) : activer le son à chaque
  // nouvelle commande, et être alerté quand le stock d'un produit est bas.
  bool _sonNouvelleCommande = true;
  bool _alerteStockBas = true;
  // Indique si le chargement initial (boutique + préférences) est en
  // cours ; affiche un spinner tant que c'est `true`.
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  // Charge en une fois toutes les données nécessaires à l'affichage de
  // l'écran : la boutique du vendeur (depuis Supabase via DatabaseService)
  // et les préférences de notification (depuis le stockage local
  // SharedPreferences, qui persiste sur l'appareil entre les sessions).
  Future<void> _charger() async {
    final shopId = context.read<AuthProvider>().shopId;
    final prefs = await SharedPreferences.getInstance();
    ShopModel? shop;
    if (shopId != null) shop = await _db.getShop(shopId);
    // `mounted` est vérifié ici car on est après plusieurs `await` : le
    // widget aurait pu être démonté entre-temps (utilisateur ayant quitté
    // l'écran avant la fin du chargement). Appeler `setState` sur un widget
    // démonté provoquerait une exception.
    if (mounted) {
      setState(() {
        _shop = shop;
        _sonNouvelleCommande = prefs.getBool('notif_nouvelle_commande') ?? true;
        _alerteStockBas = prefs.getBool('notif_stock_bas') ?? true;
        _isLoading = false;
      });
    }
  }

  // Ouvre ou suspend la boutique (champ `is_open`) : quand la boutique est
  // suspendue, elle n'est probablement plus visible/achetable côté client
  // (logique gérée ailleurs, ce switch se contente de changer le champ).
  Future<void> _toggleSuspendre(bool ouvert) async {
    if (_shop == null) return;
    await _db.updateShop(_shop!.id, {'is_open': ouvert});
    // ShopModel est une classe immuable (pas de setter sur `isOpen`) : pour
    // refléter le changement localement sans re-télécharger toute la
    // boutique depuis le serveur, on reconstruit un nouvel objet ShopModel
    // identique en tout point sauf `isOpen`, qui prend la nouvelle valeur.
    setState(() => _shop = ShopModel(
          id: _shop!.id, proprietaireId: _shop!.proprietaireId,
          nom: _shop!.nom, description: _shop!.description,
          logoUrl: _shop!.logoUrl, shopCode: _shop!.shopCode,
          zonesLivraison: _shop!.zonesLivraison, rating: _shop!.rating,
          totalAvis: _shop!.totalAvis, isOpen: ouvert,
          createdAt: _shop!.createdAt,
        ));
  }

  // Enregistre une préférence booléenne (clé/valeur) dans le stockage
  // local SharedPreferences. Utilisé pour les deux switches de
  // notification ci-dessus : contrairement aux réglages de la boutique
  // (stockés en base via Supabase), ces préférences sont propres à
  // l'appareil et ne sont pas synchronisées entre plusieurs appareils.
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
  // le `context` de l'appelant (plutôt que d'utiliser directement le
  // `context` implicite du State) car elle est aussi appelée depuis
  // l'intérieur d'un `builder` de ListTile dans `build()`. Après chaque
  // `await` (attente de la boîte de dialogue, puis appel réseau
  // `updatePassword`), on revérifie systématiquement `context.mounted`
  // avant de réutiliser ce `context` (pour afficher un SnackBar) : c'est le
  // pattern classique "use_build_context_synchronously" — un `BuildContext`
  // peut devenir invalide pendant une opération asynchrone si l'utilisateur
  // a entre-temps quitté l'écran, et l'utiliser dans ce cas provoquerait
  // une erreur ou un comportement indéfini.
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
      // `context.mounted` revérifié après ce `await` : même logique que
      // plus haut, l'écran pourrait avoir été démonté entre-temps.
      // `context.go('/role-selection')` REMPLACE toute la pile de
      // navigation (au lieu de push()) : c'est essentiel ici, car on ne
      // veut surtout pas qu'un utilisateur déconnecté puisse appuyer sur
      // "retour" pour se retrouver de nouveau sur un écran protégé de
      // l'application (paramètres, tableau de bord...).
      if (context.mounted) context.go('/role-selection');
    }
  }

  @override
  Widget build(BuildContext context) {
    // `watch` : on veut que le switch "Mode sombre" reflète en temps réel
    // l'état courant du thème (utile si le thème est aussi modifié
    // ailleurs dans l'app).
    final theme = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B5E),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          // Ici on utilise Navigator.of(context).pop() (et non
          // context.go()) : contrairement aux écrans de commande, cet
          // écran de paramètres est accédé en "empilant" une route
          // (push depuis le tableau de bord vendeur), donc un simple
          // retour en arrière classique est le comportement attendu et
          // sûr (il n'y a pas de risque de revenir sur un état incohérent
          // comme un formulaire déjà soumis).
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Paramètres'),
      ),
      // Affiche un spinner tant que le chargement initial (_charger())
      // n'est pas terminé, sinon la liste complète des réglages.
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _sectionTitle('Ma boutique'),
                // Ces trois items naviguent tous vers le même écran
                // d'édition de boutique ('/vendor/edit-shop') ; seul le
                // sous-titre affiché diffère selon l'aspect mis en avant
                // (logo, infos générales, zones de livraison). `push()`
                // est utilisé ici (empile la route) car on veut pouvoir
                // revenir naturellement aux paramètres après édition.
                _item(Icons.image_outlined, 'Logo de la boutique',
                    'Modifier ou remplacer',
                    () => context.push('/vendor/edit-shop')),
                _item(Icons.edit_outlined, 'Informations boutique',
                    'Nom, description, horaires',
                    () => context.push('/vendor/edit-shop')),
                _item(Icons.location_on_outlined, 'Zones de livraison',
                    _shop?.zonesLivraison.map((z) => z.zone).join(', ') ?? '',
                    () => context.push('/vendor/edit-shop')),
                // Switch "Suspendre la boutique" : bascule `is_open` en
                // base immédiatement au changement (voir _toggleSuspendre).
                _switchItem(Icons.storefront_outlined, 'Suspendre la boutique',
                    'Masquer temporairement',
                    _shop?.isOpen ?? true,
                    (v) => _toggleSuspendre(v)),
                const Divider(),

                _sectionTitle('Notifications'),
                // Ces deux switches ne touchent QUE le stockage local
                // (SharedPreferences) — pas de requête serveur — donc la
                // mise à jour est instantanée et fonctionne même hors
                // ligne.
                _switchItem(Icons.notifications_active_outlined,
                    'Son nouvelle commande', null,
                    _sonNouvelleCommande,
                    (v) {
                  setState(() => _sonNouvelleCommande = v);
                  _toggleNotifPref('notif_nouvelle_commande', v);
                }),
                _switchItem(Icons.warning_amber_rounded,
                    'Alerte stock bas', 'Quand stock ≤ 5',
                    _alerteStockBas,
                    (v) {
                  setState(() => _alerteStockBas = v);
                  _toggleNotifPref('notif_stock_bas', v);
                }),
                const Divider(),

                _sectionTitle('Apparence'),
                // Switch "Mode sombre" : délègue directement au
                // ThemeProvider (qui applique le changement de thème à
                // toute l'application et le persiste, probablement lui
                // aussi via SharedPreferences, pour que le choix soit
                // conservé au prochain lancement de l'app).
                _switchItem(Icons.dark_mode_outlined, 'Mode sombre', null,
                    theme.isDarkMode,
                    (v) => context.read<ThemeProvider>().toggle(v)),
                const Divider(),

                _sectionTitle('Sécurité'),
                _item(Icons.lock_outline, 'Changer le mot de passe', null,
                    () => _changerMotDePasse(context)),
                const Divider(),

                _sectionTitle('À propos'),
                // Item purement informatif : `onTap` est `null`, donc pas
                // de flèche ">" affichée (voir `_item` plus bas) et aucune
                // action au clic.
                _item(Icons.info_outline, 'CommercHaiti v1.0',
                    'ITAC · 2025-2026', null),
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

  // Petit helper : titre de section en majuscules (ex. "MA BOUTIQUE"),
  // utilisé pour regrouper visuellement les items ci-dessous en catégories.
  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(t.toUpperCase(),
            style: const TextStyle(fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF999999), letterSpacing: 1)),
      );

  // Petit helper : ligne de paramètre standard (icône + titre + sous-titre
  // optionnel + flèche ">" si cliquable). Utilisé pour toutes les entrées
  // qui déclenchent une navigation ou une action ponctuelle (pas un
  // interrupteur on/off, voir `_switchItem` pour ça). Si `onTap` est
  // `null`, l'item devient purement informatif (pas de flèche, pas de
  // réaction au clic) — voir l'item "CommercHaiti v1.0" plus haut.
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
  // (suspension boutique, notifications, mode sombre).
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
