import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/database_service.dart';
import '../../services/storage_service.dart';
import '../../models/product_model.dart';

/// Modifier produit — Faitza COLAS
/// Branch : feature/vendor-catalog
/// Path : lib/screens/vendor/vendor_edit_product_screen.dart
///
/// Formulaire d'édition d'un produit existant (récupéré via son
/// `productId`) : mêmes champs que l'écran d'ajout (photos, nom, prix,
/// stock, catégorie, couleurs, tailles, disponibilité), avec en plus la
/// possibilité de retirer des photos et de supprimer le produit.
class VendorEditProductScreen extends StatefulWidget {
  // Id (uuid) du produit à modifier, transmis par l'écran appelant
  // (ex : liste des produits, via `extra: product.id`).
  final String productId;

  const VendorEditProductScreen({super.key, required this.productId});

  @override
  State<VendorEditProductScreen> createState() =>
      _VendorEditProductScreenState();
}

class _VendorEditProductScreenState extends State<VendorEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  // Service Supabase pour mettre à jour/supprimer le produit.
  final _db = DatabaseService();
  // Service d'upload de fichiers vers Supabase Storage (photos produit).
  final _storage = StorageService();
  // Sélecteur d'image multiplateforme (galerie).
  final _picker = ImagePicker();

  final _nomCtrl = TextEditingController();
  final _prixCtrl = TextEditingController();
  final _prixPromoCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _categorieCtrl = TextEditingController();
  final _sousCategorieCtrl = TextEditingController();

  // Produit chargé depuis Supabase — utilisé notamment pour connaître son
  // `shopId` lors des uploads de nouvelles photos.
  ProductModel? _product;
  List<String> _photoUrls = [];
  List<String> _tailles = [];
  List<String> _couleurs = [];
  bool _disponible = true;
  bool _isLoading = true;
  bool _isSaving = false;

  final List<String> _taillesDisponibles = ['XS', 'S', 'M', 'L', 'XL', 'XXL'];
  static const List<String> _paletteCouleurs = [
    '#E63946', '#0D2B5E', '#1D9E75', '#F5A623',
    '#6B21A8', '#0891B2', '#1A1F36', '#FFFFFF',
  ];

  @override
  void initState() {
    super.initState();
    // Charge le produit à modifier dès l'ouverture de l'écran, pour
    // pré-remplir tous les champs du formulaire.
    _chargerProduit();
  }

  /// Récupère le produit par son id (requête Supabase ponctuelle, pas de
  /// stream ici puisqu'on veut juste l'état au moment de l'ouverture de
  /// l'écran) et pré-remplit tous les contrôleurs de texte et listes avec
  /// ses valeurs actuelles.
  Future<void> _chargerProduit() async {
    try {
      // `.eq('id', widget.productId).single()` : on lit exactement une
      // ligne de `products` correspondant à l'id du produit (erreur levée
      // si 0 ou plusieurs lignes trouvées).
      final row = await Supabase.instance.client
          .from('products')
          .select()
          .eq('id', widget.productId)
          .single();
      final p = ProductModel.fromMap(row, row['id']);
      setState(() {
        _product = p;
        _nomCtrl.text = p.nom;
        _prixCtrl.text = p.prix.toStringAsFixed(0);
        _prixPromoCtrl.text = p.prixPromo?.toStringAsFixed(0) ?? '';
        _stockCtrl.text = p.stock.toString();
        _categorieCtrl.text = p.categorie;
        _sousCategorieCtrl.text = p.sousCategorie;
        // On copie les listes (List<String>.from) plutôt que de
        // référencer directement celles du modèle, pour pouvoir les
        // modifier librement dans cet écran sans altérer `_product`.
        _photoUrls = List<String>.from(p.photos);
        _tailles = List<String>.from(p.tailles);
        _couleurs = List<String>.from(p.couleurs);
        _disponible = p.disponible;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Ajoute une nouvelle photo au produit : sélection depuis la galerie
  /// puis upload vers Supabase Storage.
  Future<void> _ajouterPhoto() async {
    if (_photoUrls.length >= 4 || _product == null) return;
    // `XFile` (pas `dart:io.File`) car cette app tourne aussi sur Flutter
    // Web, où dart:io/path_provider ne sont pas disponibles.
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    setState(() => _isSaving = true);
    // Upload des bytes de la photo (Uint8List en interne, compatible
    // web) dans le bucket Storage, sous le dossier du shop/produit
    // concerné ; retourne l'URL publique du fichier.
    final url = await _storage.uploadProductPhoto(
      file: file,
      shopId: _product!.shopId,
      productId: widget.productId,
    );
    if (url != null) {
      setState(() => _photoUrls.add(url));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Échec du téléversement de la photo — réessayez'),
        backgroundColor: Color(0xFFE63946),
      ));
    }
    if (mounted) setState(() => _isSaving = false);
  }

  /// Valide le formulaire puis met à jour le produit en base via un
  /// UPDATE Supabase (`DatabaseService.updateProduct`) ciblé sur
  /// `widget.productId`, avec toutes les valeurs actuelles des champs.
  Future<void> _sauvegarder() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      await _db.updateProduct(widget.productId, {
        'nom': _nomCtrl.text.trim(),
        'prix': double.parse(_prixCtrl.text),
        'prix_promo': _prixPromoCtrl.text.isEmpty
            ? null
            : double.parse(_prixPromoCtrl.text),
        'stock': int.parse(_stockCtrl.text),
        'categorie': _categorieCtrl.text.trim(),
        'sous_categorie': _sousCategorieCtrl.text.trim(),
        'photos': _photoUrls,
        'tailles': _tailles,
        'couleurs': _couleurs,
        'disponible': _disponible,
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

  /// Affiche une confirmation avant de supprimer définitivement le
  /// produit (DELETE Supabase via `DatabaseService.deleteProduct`), puis
  /// ferme cet écran d'édition.
  Future<void> _supprimer(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ce produit ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE63946)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _db.deleteProduct(widget.productId);
      if (context.mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B5E),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Modifier · ${_product?.nom ?? ""}',
            overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Color(0xFFE63946)),
            onPressed: () => _supprimer(context),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF2F4F8),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _product == null
              ? const Center(child: Text('Produit introuvable'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _card(children: [
                          _label('Photos (max 4)', icon: Icons.camera_alt_outlined),
                          SizedBox(
                            height: 100,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                ..._photoUrls.map((url) => Stack(children: [
                                      Container(
                                        width: 100, height: 100,
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(10),
                                          image: DecorationImage(
                                              image: NetworkImage(url),
                                              fit: BoxFit.cover),
                                        ),
                                      ),
                                      Positioned(
                                        top: 2, right: 10,
                                        child: GestureDetector(
                                          onTap: () => setState(
                                              () => _photoUrls.remove(url)),
                                          child: const CircleAvatar(
                                            radius: 10,
                                            backgroundColor: Color(0xFFE63946),
                                            child: Icon(Icons.close,
                                                size: 12, color: Colors.white),
                                          ),
                                        ),
                                      ),
                                    ])),
                                if (_photoUrls.length < 4)
                                  GestureDetector(
                                    onTap: _ajouterPhoto,
                                    child: Container(
                                      width: 100, height: 100,
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        color: const Color(0xFFF2F4F8),
                                        border: Border.all(
                                            color: const Color(0xFFCCCCCC)),
                                      ),
                                      child: const Icon(
                                          Icons.add_photo_alternate_outlined,
                                          color: Color(0xFF0D2B5E), size: 32),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ]),
                        const SizedBox(height: 16),

                        _card(children: [
                          _label('Informations', icon: Icons.info_outline),
                          _field(_nomCtrl, 'Ex: Robe fleurie',
                              validator: (v) =>
                                  v == null || v.isEmpty ? 'Nom requis' : null),
                          const SizedBox(height: 16),

                          Row(children: [
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('Prix normal (HTG) *'),
                                _field(_prixCtrl, '500',
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return 'Prix requis';
                                      if (double.tryParse(v) == null ||
                                          double.parse(v) <= 0) {
                                        return 'Prix invalide';
                                      }
                                      return null;
                                    },
                                    keyboardType: TextInputType.number),
                              ],
                            )),
                            const SizedBox(width: 12),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('Prix promo (optionnel)'),
                                _field(_prixPromoCtrl, '350',
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return null;
                                      final promo = double.tryParse(v);
                                      final normal = double.tryParse(_prixCtrl.text);
                                      if (promo == null || promo <= 0) return 'Invalide';
                                      if (normal != null && promo >= normal) {
                                        return 'Doit être < prix normal';
                                      }
                                      return null;
                                    },
                                    keyboardType: TextInputType.number),
                              ],
                            )),
                          ]),
                          const SizedBox(height: 16),

                          _label('Stock actuel *'),
                          _field(_stockCtrl, '10',
                              validator: (v) =>
                                  v == null || v.isEmpty ? 'Stock requis' : null,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setState(() {})),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: ((int.tryParse(_stockCtrl.text) ?? 0) / 20)
                                  .clamp(0.0, 1.0),
                              minHeight: 5,
                              backgroundColor: const Color(0xFFEEEEEE),
                              color: (int.tryParse(_stockCtrl.text) ?? 0) == 0
                                  ? const Color(0xFFE63946)
                                  : (int.tryParse(_stockCtrl.text) ?? 0) <= 5
                                      ? const Color(0xFFF5A623)
                                      : const Color(0xFF1D9E75),
                            ),
                          ),
                          if ((int.tryParse(_stockCtrl.text) ?? 0) <= 5)
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Text('⚠ Stock bas',
                                  style: TextStyle(
                                      color: Color(0xFFF5A623),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                            ),
                        ]),
                        const SizedBox(height: 16),

                        Row(children: [
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('Catégorie *'),
                              _field(_categorieCtrl, 'Alimentation',
                                  validator: (v) =>
                                      v == null || v.isEmpty ? 'Requis' : null),
                            ],
                          )),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('Sous-catégorie *'),
                              _field(_sousCategorieCtrl, 'Fruits',
                                  validator: (v) =>
                                      v == null || v.isEmpty ? 'Requis' : null),
                            ],
                          )),
                        ]),
                        const SizedBox(height: 16),

                        _label('Couleurs (optionnel)'),
                        Wrap(
                          spacing: 10,
                          children: _paletteCouleurs.map((hex) {
                            final sel = _couleurs.contains(hex);
                            final couleur = Color(
                                int.parse('0xFF${hex.replaceAll('#', '')}'));
                            return GestureDetector(
                              onTap: () => setState(() {
                                if (sel) {
                                  _couleurs.remove(hex);
                                } else {
                                  _couleurs.add(hex);
                                }
                              }),
                              child: Container(
                                width: 34, height: 34,
                                decoration: BoxDecoration(
                                  color: couleur,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: sel
                                        ? const Color(0xFF0D2B5E)
                                        : const Color(0xFFDDDDDD),
                                    width: sel ? 3 : 1,
                                  ),
                                ),
                                child: sel
                                    ? Icon(Icons.check,
                                        size: 16,
                                        color: couleur.computeLuminance() > 0.5
                                            ? Colors.black
                                            : Colors.white)
                                    : null,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        _label('Tailles (optionnel)'),
                        Wrap(
                          spacing: 8,
                          children: _taillesDisponibles.map((t) {
                            final sel = _tailles.contains(t);
                            return FilterChip(
                              label: Text(t),
                              selected: sel,
                              onSelected: (v) => setState(() {
                                if (v) {
                                  _tailles.add(t);
                                } else {
                                  _tailles.remove(t);
                                }
                              }),
                              selectedColor: const Color(0xFFEEF3FB),
                              checkmarkColor: const Color(0xFF0D2B5E),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Disponible à la vente',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            Switch(
                              value: _disponible,
                              onChanged: (v) => setState(() => _disponible = v),
                              activeColor: const Color(0xFF0D2B5E),
                            ),
                          ],
                        ),
                        if (!_disponible)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text(
                                'Non disponible pour l\'acheteur — masqué avec overlay dans le catalogue.',
                                style: TextStyle(
                                    fontSize: 12, color: Color(0xFF999999))),
                          ),
                        const SizedBox(height: 24),

                        Row(children: [
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 52,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE63946),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: _isSaving ? null : _sauvegarder,
                                icon: _isSaving
                                    ? const SizedBox(width: 16, height: 16,
                                        child: CircularProgressIndicator(
                                            color: Colors.white, strokeWidth: 2))
                                    : const Icon(Icons.check, color: Colors.white),
                                label: const Text('Sauvegarder',
                                    style: TextStyle(color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SizedBox(
                              height: 52,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFDEAEA),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                onPressed: () => _supprimer(context),
                                icon: const Icon(Icons.delete_outline,
                                    color: Color(0xFFE63946), size: 18),
                                label: const Text('Supprimer',
                                    style: TextStyle(color: Color(0xFFE63946),
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _card({required List<Widget> children}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _label(String t, {IconData? icon}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: const Color(0xFF0D2B5E)),
            const SizedBox(width: 6),
          ],
          Text(t, style: const TextStyle(fontSize: 14,
              fontWeight: FontWeight.w600, color: Color(0xFF1A1F36))),
        ]),
      );

  Widget _field(TextEditingController ctrl, String hint,
          {String? Function(String?)? validator,
          TextInputType? keyboardType,
          ValueChanged<String>? onChanged}) =>
      TextFormField(
        controller: ctrl,
        validator: validator,
        keyboardType: keyboardType,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFFAAAAAA)),
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
        ),
      );

  @override
  void dispose() {
    _nomCtrl.dispose();
    _prixCtrl.dispose();
    _prixPromoCtrl.dispose();
    _stockCtrl.dispose();
    _categorieCtrl.dispose();
    _sousCategorieCtrl.dispose();
    super.dispose();
  }
}
