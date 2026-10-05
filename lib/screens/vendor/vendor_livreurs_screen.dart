import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';

/// Mes livreurs (vendeur) : la liste des personnes qui livrent pour la
/// boutique. Le vendeur en choisit une dans le détail d'une commande ;
/// le client voit alors son nom et son téléphone sur l'écran de suivi.
/// Table `livreurs`, voir supabase/migration_livreurs.sql.
class VendorLivreursScreen extends StatefulWidget {
  const VendorLivreursScreen({super.key});

  @override
  State<VendorLivreursScreen> createState() => _VendorLivreursScreenState();
}

class _VendorLivreursScreenState extends State<VendorLivreursScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _livreurs = [];
  bool _isLoading = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final shopId = context.read<AuthProvider>().shopId;
    if (shopId == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final rows = await _supabase
          .from('livreurs')
          .select()
          .eq('shop_id', shopId)
          .order('actif', ascending: false)
          .order('nom');
      if (mounted) {
        setState(() {
          _livreurs = List<Map<String, dynamic>>.from(rows);
          _isLoading = false;
          _erreur = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _erreur = 'Chargement impossible. Réessayez.';
        });
      }
    }
  }

  Future<void> _editer([Map<String, dynamic>? livreur]) async {
    final nomCtrl = TextEditingController(text: livreur?['nom'] ?? '');
    final telCtrl = TextEditingController(text: livreur?['telephone'] ?? '');
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(livreur == null ? 'Ajouter un livreur' : 'Modifier le livreur'),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: nomCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nom'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Nom requis' : null,
            ),
            TextFormField(
              controller: telCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Téléphone'),
              validator: (v) {
                var chiffres = (v ?? '').replaceAll(RegExp(r'[^\d]'), '');
                if (chiffres.length == 11 && chiffres.startsWith('509')) {
                  chiffres = chiffres.substring(3);
                }
                return chiffres.length == 8 ? null : 'Numéro invalide (8 chiffres)';
              },
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    final nom = nomCtrl.text.trim();
    final telephone = telCtrl.text.trim();
    nomCtrl.dispose();
    telCtrl.dispose();
    if (ok != true || !mounted) return;

    try {
      if (livreur == null) {
        await _supabase.from('livreurs').insert({
          'shop_id': context.read<AuthProvider>().shopId,
          'nom': nom,
          'telephone': telephone,
        });
      } else {
        await _supabase
            .from('livreurs')
            .update({'nom': nom, 'telephone': telephone})
            .eq('id', livreur['id']);
      }
      await _charger();
    } catch (e) {
      _snack('Enregistrement impossible. Réessayez.');
    }
  }

  // Un livreur déjà assigné à des commandes n'est pas supprimé mais mis
  // en pause (il n'est plus proposé), pour garder l'historique.
  Future<void> _basculerActif(Map<String, dynamic> livreur, bool actif) async {
    try {
      await _supabase
          .from('livreurs')
          .update({'actif': actif})
          .eq('id', livreur['id']);
      await _charger();
    } catch (e) {
      _snack('Modification impossible. Réessayez.');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: AppColors.red,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(isDark),
      appBar: AppBar(title: const Text('Mes livreurs')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        onPressed: () => _editer(),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Ajouter'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _erreur != null
              ? Center(child: Text(_erreur!))
              : _livreurs.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'Ajoutez les personnes qui livrent vos commandes. '
                          'Vous pourrez choisir un livreur pour chaque commande.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppColors.textSecondaryFor(isDark)),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(0, 8, 0, 96),
                      itemCount: _livreurs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 2),
                      itemBuilder: (_, i) {
                        final l = _livreurs[i];
                        final actif = l['actif'] == true;
                        return Material(
                          color: AppColors.surface(isDark),
                          child: ListTile(
                            onTap: () => _editer(l),
                            leading: CircleAvatar(
                              backgroundColor: actif
                                  ? AppColors.lightBlue
                                  : AppColors.textHint.withValues(alpha: 0.2),
                              child: Icon(Icons.delivery_dining,
                                  color: actif ? AppColors.navy : AppColors.textHint),
                            ),
                            title: Text(l['nom'] ?? '',
                                style: TextStyle(
                                    color: AppColors.textPrimaryFor(isDark),
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(
                                actif ? l['telephone'] ?? '' : '${l['telephone']} · en pause',
                                style: TextStyle(
                                    color: AppColors.textSecondaryFor(isDark))),
                            trailing: Switch(
                              value: actif,
                              onChanged: (v) => _basculerActif(l, v),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
