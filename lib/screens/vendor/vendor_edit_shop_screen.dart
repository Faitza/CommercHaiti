import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../services/storage_service.dart';
import '../../models/shop_model.dart';

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

  // Modèle de la boutique chargé depuis Supabase, conservé pour connaître
  // son id (`_shop!.id`) et son `proprietaireId` lors des mises à jour.
  ShopModel? _shop;
  // URL du logo actuellement affiché (peut être mise à jour après upload).
  String? _logoUrl;
  // Zones de livraison actuellement cochées par le vendeur.
  final List<String> _zonesSelectionnees = [];
  // Statut "boutique ouverte" (visible/achetable par les clients).
  bool _isOpen = true;
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
        _logoUrl = row.logoUrl;
        _isOpen = row.isOpen;
        // Reconstruit la liste des zones sélectionnées à partir des
        // objets `zonesLivraison` de la boutique (on ne garde que le nom
        // de la zone, pas les délais).
        _zonesSelectionnees
          ..clear()
          ..addAll(row.zonesLivraison.map((z) => z.zone));
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
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
    setState(() => _isSaving = true);
    try {
      // Met à jour la ligne `shops` correspondant à `_shop!.id` avec les
      // nouvelles valeurs saisies. Les zones de livraison sont
      // reconstruites en objets {zone, delai_min, delai_max} — les délais
      // sont ici fixés à des valeurs par défaut (20-45 min) car ce
      // formulaire ne permet pas encore de les personnaliser par zone.
      await _db.updateShop(_shop!.id, {
        'nom': _nomCtrl.text.trim(),
        'description': _descriptionCtrl.text.trim(),
        'logo_url': _logoUrl,
        'is_open': _isOpen,
        'zones_livraison': _zonesSelectionnees
            .map((z) => {'zone': z, 'delai_min': 20, 'delai_max': 45})
            .toList(),
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
    return Scaffold(
      backgroundColor: Colors.white,
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
                            const Text('Code boutique',
                                style: TextStyle(color: Color(0xFF666666))),
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
                                color: const Color(0xFFF2F4F8),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: const Color(0xFFCCCCCC), width: 2),
                                image: _logoUrl != null
                                    ? DecorationImage(
                                        image: NetworkImage(_logoUrl!),
                                        fit: BoxFit.cover)
                                    : null,
                              ),
                              child: _logoUrl == null
                                  ? const Icon(Icons.add_a_photo_outlined,
                                      color: Color(0xFF0D2B5E), size: 28)
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
                        // Interrupteur "Boutique ouverte" : ne modifie que
                        // l'état local `_isOpen` — l'enregistrement réel en
                        // base ne se fait qu'au clic sur "Enregistrer" (via
                        // `_enregistrer`), contrairement au switch de
                        // disponibilité produit qui, lui, écrit
                        // immédiatement.
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Boutique ouverte',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            Switch(
                              value: _isOpen,
                              onChanged: (v) => setState(() => _isOpen = v),
                              activeColor: const Color(0xFF0D2B5E),
                            ),
                          ],
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
    super.dispose();
  }
}
