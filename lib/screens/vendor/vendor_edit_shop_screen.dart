import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../services/storage_service.dart';
import '../../models/shop_model.dart';
import '../../providers/theme_provider.dart';
import '../../constants/app_colors.dart';
import '../../widgets/categories_boutique_widget.dart';
import '../../widgets/horaire_boutique_widget.dart';

/// Modifier infos boutique — vendeur (menu Paramètres)
/// Path : lib/screens/vendor/vendor_edit_shop_screen.dart
///
/// Formulaire permettant au vendeur de modifier les informations de sa
/// boutique : nom, description, logo, statut ouvert/fermé et zones de
/// livraison desservies. Accessible depuis le menu Paramètres.
class VendorEditShopScreen extends StatefulWidget {
  const VendorEditShopScreen({super.key});

  @override
  State<VendorEditShopScreen> createState() => _VendorEditShopScreenState();
}

class _VendorEditShopScreenState extends State<VendorEditShopScreen> {
  // Clé du formulaire, utilisée pour déclencher la validation de tous les
  // champs (`_formKey.currentState!.validate()`).
  final _formKey = GlobalKey<FormState>();
  // Service d'accès aux données Supabase pour la boutique (getShop,
  // updateShop).
  final _db = DatabaseService();
  // Service d'upload de fichiers vers Supabase Storage (logo).
  final _storage = StorageService();
  // Sélecteur d'image de la galerie du téléphone/ordinateur.
  final _picker = ImagePicker();

  final _nomCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  // Numéro MonCash où les clients envoient leur paiement (optionnel).
  final _moncashCtrl = TextEditingController();

  // Modèle de la boutique chargé depuis Supabase, conservé pour connaître
  // son id (`_shop!.id`) et son `proprietaireId` lors des mises à jour.
  ShopModel? _shop;
  // URL du logo actuellement affiché (peut être mise à jour après upload).
  String? _logoUrl;
  // Zones de livraison actuellement cochées par le vendeur.
  final List<String> _zonesSelectionnees = [];
  // Prix de livraison saisi pour chaque zone sélectionnée (en HTG).
  final Map<String, TextEditingController> _fraisCtrls = {};

  TextEditingController _fraisCtrl(String zone) =>
      _fraisCtrls.putIfAbsent(zone, () => TextEditingController());
  // Catégories vendues cochées par le vendeur.
  List<String> _categoriesSelectionnees = [];
  // Horaire (heures + jours de travail), enregistré avec le formulaire.
  TimeOfDay? _ouverture;
  TimeOfDay? _fermeture;
  List<String> _jours = [];
  bool _isLoading = true;
  bool _isSaving = false;

  // Liste fixe des zones de livraison proposées (zone géographique
  // desservie par les livreurs de la plateforme).
  final List<String> _zonesDisponibles = [
    'Cayes Centre', 'Cayes Nord', 'Cayes Sud',
    'Torbeck', 'Saint-Jean', 'Maniche', 'Camp-Perrin',
  ];

  @override
  void initState() {
    super.initState();
    // Chargement des données actuelles de la boutique dès l'ouverture,
    // pour pré-remplir le formulaire.
    _charger();
  }

  /// Charge la boutique du vendeur connecté et pré-remplit tous les
  /// champs du formulaire avec ses valeurs actuelles.
  Future<void> _charger() async {
    // IMPORTANT : `AuthProvider.shopId` est l'UUID réel (table `shops`,
    // résolu via `shops.proprietaire_id`) — c'est cet id qui identifie la
    // boutique en base, contrairement au `shopCode` qui n'est qu'un code
    // d'affichage lisible par l'utilisateur.
    final shopId = context.read<AuthProvider>().shopId;
    if (shopId == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      // Récupère la ligne `shops` correspondante et la convertit en
      // ShopModel.
      final row = await _db.getShop(shopId);
      if (row == null) {
        setState(() => _isLoading = false);
        return;
      }
      setState(() {
        _shop = row;
        _nomCtrl.text = row.nom;
        _descriptionCtrl.text = row.description;
        _moncashCtrl.text = row.moncashNumero ?? '';
        _logoUrl = row.logoUrl;
        _ouverture = HoraireBoutiqueWidget.depuisTexte(row.horaireOuverture);
        _fermeture = HoraireBoutiqueWidget.depuisTexte(row.horaireFermeture);
        _jours = List<String>.from(row.joursOuverture);
        // Reconstruit la liste des zones sélectionnées à partir des
        // objets `zonesLivraison` de la boutique (on ne garde que le nom
        // de la zone, pas les délais).
        _zonesSelectionnees
          ..clear()
          ..addAll(row.zonesLivraison.map((z) => z.zone));
        for (final z in row.zonesLivraison) {
          _fraisCtrl(z.zone).text =
              z.frais > 0 ? z.frais.toStringAsFixed(0) : '';
        }
        _categoriesSelectionnees = List<String>.from(row.categories);
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  /// Recharge uniquement la boutique après un forçage ouvert/fermé, sans
  /// toucher aux champs du formulaire en cours de modification.
  Future<void> _rechargerStatut() async {
    if (_shop == null) return;
    final shop = await _db.getShop(_shop!.id);
    if (mounted && shop != null) setState(() => _shop = shop);
  }

  /// Ouvre la galerie pour choisir une nouvelle photo de logo, l'envoie
  /// vers Supabase Storage via StorageService, puis met à jour l'aperçu
  /// local avec l'URL retournée. Noter que l'upload en base de données
  /// (colonne `logo_url`) ne se fait qu'au moment d'"Enregistrer" — cette
  /// méthode ne fait qu'uploader le fichier et mémoriser son URL.
  Future<void> _uploadLogo() async {
    if (_shop == null) return;
    // `pickImage` retourne un `XFile` (type multiplateforme de
    // image_picker) et non un `dart:io.File`, car dart:io n'existe pas
    // sur Flutter Web — cette app doit fonctionner en web comme en mobile.
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    setState(() => _isSaving = true);
    // `StorageService.uploadShopLogo` lit le fichier en `Uint8List`
    // (bytes bruts, compatibles web et mobile) plutôt que de le manipuler
    // via `dart:io.File`, puis l'envoie dans le bucket Supabase Storage
    // dédié aux logos de boutique, et retourne l'URL publique du fichier
    // uploadé.
    final url = await _storage.uploadShopLogo(
      file: file,
      shopId: _shop!.proprietaireId,
    );
    setState(() {
      _logoUrl = url;
      _isSaving = false;
    });
  }

  /// Valide le formulaire puis enregistre les modifications de la
  /// boutique en base via un UPDATE Supabase sur la table `shops`.
  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate() || _shop == null) return;
    // Règle métier : au moins une zone de livraison doit être
    // sélectionnée, sinon la boutique ne pourrait livrer nulle part.
    if (_zonesSelectionnees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Sélectionnez au moins une zone de livraison'),
        backgroundColor: Color(0xFFE63946),
      ));
      return;
    }
    if (_categoriesSelectionnees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Sélectionnez au moins une catégorie vendue'),
        backgroundColor: Color(0xFFE63946),
      ));
      return;
    }
    if (_ouverture == null || _fermeture == null ||
        _ouverture == _fermeture || _jours.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Horaire incomplet : heures d\'ouverture et de '
            'fermeture différentes, et au moins un jour de travail'),
        backgroundColor: Color(0xFFE63946),
      ));
      return;
    }
    setState(() => _isSaving = true);
    try {
      // Met à jour la ligne `shops` correspondant à `_shop!.id` avec les
      // nouvelles valeurs saisies. Les zones de livraison sont
      // reconstruites en objets {zone, delai_min, delai_max} — les délais
      // sont ici fixés à des valeurs par défaut (20-45 min) car ce
      // formulaire ne permet pas encore de les personnaliser par zone.
      final moncash = _moncashCtrl.text.trim();
      await _db.updateShop(_shop!.id, {
        // Envoyé seulement s'il a changé : ce formulaire continue de
        // marcher tant que migration_moncash.sql n'a pas été exécutée.
        if (moncash != (_shop!.moncashNumero ?? ''))
          'moncash_numero': moncash.isEmpty ? null : moncash,
        'nom': _nomCtrl.text.trim(),
        'description': _descriptionCtrl.text.trim(),
        'logo_url': _logoUrl,
        'horaire_ouverture': HoraireBoutiqueWidget.versTexte(_ouverture),
        'horaire_fermeture': HoraireBoutiqueWidget.versTexte(_fermeture),
        'jours_ouverture': _jours,
        // Chaque zone garde ses délais existants (20-45 min par défaut)
        // et reçoit le prix de livraison saisi (vide = gratuit).
        'zones_livraison': _zonesSelectionnees.map((z) {
          ZoneLivraison? existante;
          for (final e in _shop!.zonesLivraison) {
            if (e.zone == z) existante = e;
          }
          final frais = double.tryParse(
                  _fraisCtrl(z).text.trim().replaceAll(',', '.')) ??
              0;
          return {
            'zone': z,
            'delai_min': existante?.delaiMin ?? 20,
            'delai_max': existante?.delaiMax ?? 45,
            'frais': frais < 0 ? 0 : frais,
          };
        }).toList(),
        'categories': _categoriesSelectionnees,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : ${e.toString()}'),
          backgroundColor: const Color(0xFFE63946),
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(isDark),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B5E),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Infos boutique'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _shop == null
              ? const Center(child: Text('Boutique introuvable'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Bandeau d'info affichant le code boutique
                        // (`shopCode`, ex : "MFL-2026-4892") — c'est un
                        // identifiant purement lisible/affiché à
                        // l'utilisateur, en lecture seule ici. Il ne sert
                        // jamais de clé pour les requêtes Supabase (voir
                        // note plus haut sur `AuthProvider.shopId`).
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF3FB),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(children: [
                            Text('Code boutique',
                                style: TextStyle(color: AppColors.textSecondaryFor(isDark))),
                            const SizedBox(height: 4),
                            Text(_shop!.shopCode,
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0D2B5E),
                                    letterSpacing: 2)),
                          ]),
                        ),
                        const SizedBox(height: 24),
                        // Avatar circulaire du logo — tap pour ouvrir la
                        // galerie et changer le logo via `_uploadLogo`.
                        // Affiche l'image réseau si un logo existe déjà,
                        // sinon une icône "ajouter une photo".
                        Center(
                          child: GestureDetector(
                            onTap: _uploadLogo,
                            child: Container(
                              width: 100, height: 100,
                              decoration: BoxDecoration(
                                color: AppColors.inputFill(isDark),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppColors.borderColor(isDark), width: 2),
                                image: _logoUrl != null
                                    ? DecorationImage(
                                        image: NetworkImage(_logoUrl!),
                                        fit: BoxFit.cover)
                                    : null,
                              ),
                              child: _logoUrl == null
                                  ? Icon(Icons.add_a_photo_outlined,
                                      color: AppColors.accentFor(isDark), size: 28)
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Champ nom de la boutique — obligatoire.
                        const Text('Nom de la boutique *',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _nomCtrl,
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Nom requis' : null,
                        ),
                        const SizedBox(height: 16),
                        // Champ description de la boutique — obligatoire,
                        // multi-lignes (3 lignes visibles).
                        const Text('Description *',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _descriptionCtrl,
                          maxLines: 3,
                          validator: (v) => v == null || v.isEmpty
                              ? 'Description requise'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        // Numéro MonCash (optionnel) : s'il est rempli, les
                        // clients peuvent choisir de payer par MonCash.
                        const Text('Numéro MonCash (optionnel)',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _moncashCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            hintText: 'Ex : 3712 3456',
                            helperText:
                                'Les clients pourront payer par MonCash à ce numéro',
                          ),
                          validator: (v) {
                            final chiffres =
                                (v ?? '').replaceAll(RegExp(r'[^\d]'), '');
                            if (chiffres.isEmpty) return null;
                            if (chiffres.length == 8 ||
                                (chiffres.length == 11 &&
                                    chiffres.startsWith('509'))) {
                              return null;
                            }
                            return 'Numéro invalide (8 chiffres)';
                          },
                        ),
                        const SizedBox(height: 16),
                        // Statut actuel + "Ouvrir maintenant" / "Fermer
                        // maintenant" (écrit immédiatement en base).
                        const Text('Statut',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        ForcerStatutWidget(
                          shop: _shop!,
                          isDark: isDark,
                          onChanged: _rechargerStatut,
                        ),
                        const SizedBox(height: 16),
                        // Horaire automatique (enregistré avec le bouton
                        // "Enregistrer").
                        const Text('Horaire d\'ouverture *',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        HoraireBoutiqueWidget(
                          ouverture: _ouverture,
                          fermeture: _fermeture,
                          jours: _jours,
                          isDark: isDark,
                          onOuvertureChanged: (t) =>
                              setState(() => _ouverture = t),
                          onFermetureChanged: (t) =>
                              setState(() => _fermeture = t),
                          onJoursChanged: (l) => setState(() => _jours = l),
                        ),
                        const SizedBox(height: 16),
                        // Sélection des zones de livraison via des
                        // "chips" filtrables (FilterChip) : chaque tap
                        // ajoute/retire la zone de `_zonesSelectionnees`.
                        const Text('Zones de livraison *',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: _zonesDisponibles.map((zone) {
                            final sel = _zonesSelectionnees.contains(zone);
                            return FilterChip(
                              label: Text(zone),
                              selected: sel,
                              onSelected: (v) => setState(() {
                                if (v) {
                                  _zonesSelectionnees.add(zone);
                                } else {
                                  _zonesSelectionnees.remove(zone);
                                }
                              }),
                              selectedColor: const Color(0xFFEEF3FB),
                              checkmarkColor: const Color(0xFF0D2B5E),
                            );
                          }).toList(),
                        ),
                        // Prix de livraison de chaque zone choisie : il
                        // s'ajoute au total de la commande du client.
                        if (_zonesSelectionnees.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text('Prix de livraison par zone (HTG)',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          const Text('Laissez vide si la livraison est gratuite.',
                              style: TextStyle(fontSize: 12, color: Colors.grey)),
                          for (final zone in _zonesDisponibles
                              .where(_zonesSelectionnees.contains))
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(children: [
                                Expanded(child: Text(zone)),
                                SizedBox(
                                  width: 110,
                                  child: TextFormField(
                                    controller: _fraisCtrl(zone),
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.right,
                                    decoration: const InputDecoration(
                                        hintText: '0', suffixText: 'HTG',
                                        isDense: true),
                                    validator: (v) {
                                      final t = (v ?? '').trim();
                                      if (t.isEmpty) return null;
                                      final n = double.tryParse(
                                          t.replaceAll(',', '.'));
                                      return n == null || n < 0
                                          ? 'Invalide'
                                          : null;
                                    },
                                  ),
                                ),
                              ]),
                            ),
                        ],
                        const SizedBox(height: 16),
                        // Catégories vendues (cases à cocher) : limitent
                        // les catégories proposées à l'ajout d'un produit.
                        const Text('Catégories vendues *',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        CategoriesBoutiqueWidget(
                          selection: _categoriesSelectionnees,
                          isDark: isDark,
                          onChanged: (l) =>
                              setState(() => _categoriesSelectionnees = l),
                        ),
                        const SizedBox(height: 32),
                        // Bouton "Enregistrer" — désactivé pendant la
                        // sauvegarde (`_isSaving`) et remplacé par un
                        // indicateur de chargement.
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D2B5E),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _isSaving ? null : _enregistrer,
                            child: _isSaving
                                ? const SizedBox(width: 20, height: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : const Text('Enregistrer',
                                    style: TextStyle(color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _descriptionCtrl.dispose();
    _moncashCtrl.dispose();
    for (final c in _fraisCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }
}
