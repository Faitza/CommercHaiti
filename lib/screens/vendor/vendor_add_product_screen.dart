import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../services/storage_service.dart';
import '../../models/product_model.dart';

/// Ajouter produit — Faitza COLAS
/// Branch : feature/vendor-catalog
/// Path : lib/screens/vendor/vendor_add_product_screen.dart
///
/// Formulaire de création d'un nouveau produit pour la boutique du
/// vendeur connecté : photos (jusqu'à 4), nom, prix (normal + promo
/// optionnel), stock initial, catégorie/sous-catégorie, couleurs et
/// tailles disponibles, et disponibilité à la vente.
class VendorAddProductScreen extends StatefulWidget {
  const VendorAddProductScreen({super.key});

  @override
  State<VendorAddProductScreen> createState() =>
      _VendorAddProductScreenState();
}

class _VendorAddProductScreenState extends State<VendorAddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  // Service Supabase pour créer le produit (`createProduct`).
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

  // URLs des photos déjà téléversées (max 4), tailles et couleurs
  // sélectionnées par le vendeur (listes vides = optionnel).
  List<String> _photoUrls = [];
  List<String> _tailles = [];
  List<String> _couleurs = [];
  bool _disponible = true;
  bool _isLoading = false;

  final List<String> _taillesDisponibles = ['XS','S','M','L','XL','XXL'];
  // Palette de couleurs fixe (codes hexadécimaux) proposée pour marquer
  // les variantes de couleur du produit.
  static const List<String> _paletteCouleurs = [
    '#E63946', '#0D2B5E', '#1D9E75', '#F5A623',
    '#6B21A8', '#0891B2', '#1A1F36', '#FFFFFF',
  ];

  /// Ouvre la galerie, sélectionne une photo (max 4 au total) et
  /// l'envoie à Supabase Storage.
  Future<void> _ajouterPhoto() async {
    if (_photoUrls.length >= 4) return;
    // `pickImage` renvoie un `XFile` (type multiplateforme d'image_picker)
    // plutôt qu'un `dart:io.File`, car cette app doit aussi fonctionner
    // sur Flutter Web, où `dart:io` et `path_provider` ne sont pas
    // disponibles — XFile/Uint8List fonctionnent aussi bien en web qu'en
    // mobile/desktop.
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();
    // IMPORTANT : `auth.shopId` (UUID réel de `shops`, résolu via
    // `shops.proprietaire_id`) est utilisé pour ranger la photo dans le
    // bon dossier du bucket Storage — jamais le `shopCode` d'affichage.
    final shopId = auth.shopId ?? '';
    // Comme le produit n'existe pas encore en base à ce stade (il sera
    // créé seulement lors de `_sauvegarder`), on génère un identifiant
    // temporaire basé sur l'horodatage courant pour nommer le dossier des
    // photos dans le Storage.
    final productId = DateTime.now().millisecondsSinceEpoch.toString();

    // Upload effectif : lit les bytes du XFile (Uint8List, compatible
    // web) et les envoie vers Supabase Storage sous
    // shop_id/product_id/..., puis retourne l'URL publique du fichier.
    final url = await _storage.uploadProductPhoto(
      file: file,
      shopId: shopId,
      productId: productId,
    );

    if (url != null) {
      setState(() => _photoUrls.add(url));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Échec du téléversement de la photo — réessayez'),
        backgroundColor: Color(0xFFE63946),
      ));
    }
    setState(() => _isLoading = false);
  }

  /// Valide le formulaire, construit un ProductModel à partir des champs
  /// saisis, puis l'insère en base via `DatabaseService.createProduct`
  /// (INSERT Supabase dans la table `products`).
  Future<void> _sauvegarder() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final auth = context.read<AuthProvider>();
    // IMPORTANT : le produit est rattaché à la boutique via l'UUID réel
    // `shopId` (et non `shopCode`) — c'est cette valeur qui est écrite
    // dans la colonne `products.shop_id`.
    final shopId = auth.shopId;
    if (shopId == null) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Boutique introuvable — reconnectez-vous'),
          backgroundColor: Color(0xFFE63946),
        ));
      }
      return;
    }

    // `id: ''` car l'id réel sera généré côté base de données (Postgres)
    // lors de l'INSERT — ce n'est qu'un espace réservé côté modèle Dart.
    final product = ProductModel(
      id: '',
      shopId: shopId,
      nom: _nomCtrl.text.trim(),
      prix: double.parse(_prixCtrl.text),
      // Prix promo optionnel : null si le champ est vide.
      prixPromo: _prixPromoCtrl.text.isEmpty
          ? null
          : double.parse(_prixPromoCtrl.text),
      photos: _photoUrls,
      stock: int.parse(_stockCtrl.text),
      categorie: _categorieCtrl.text.trim(),
      sousCategorie: _sousCategorieCtrl.text.trim(),
      couleurs: _couleurs,
      tailles: _tailles,
      disponible: _disponible,
      createdAt: DateTime.now(),
    );

    await _db.createProduct(product);
    setState(() => _isLoading = false);
    if (mounted) Navigator.pop(context);
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
        title: const Text('Ajouter un produit'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photos : galerie horizontale des photos déjà uploadées +
              // une tuile "ajouter" tant qu'on n'a pas atteint 4 photos.
              _label('Photos (max 4)'),
              SizedBox(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ..._photoUrls.map((url) => Container(
                      width: 100, height: 100,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        image: DecorationImage(
                            image: NetworkImage(url), fit: BoxFit.cover),
                      ),
                    )),
                    if (_photoUrls.length < 4)
                      GestureDetector(
                        onTap: _ajouterPhoto,
                        child: Container(
                          width: 100, height: 100,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: const Color(0xFFF2F4F8),
                            border: Border.all(color: const Color(0xFFCCCCCC)),
                          ),
                          child: const Icon(Icons.add_photo_alternate_outlined,
                              color: Color(0xFF0D2B5E), size: 32),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              _label('Nom du produit *'),
              _field(_nomCtrl, 'Ex: Robe fleurie',
                  validator: (v) => v == null || v.isEmpty ? 'Nom requis' : null),
              const SizedBox(height: 16),

              // Prix normal (obligatoire, doit être > 0) et prix promo
              // (optionnel, doit être strictement inférieur au prix
              // normal si renseigné) côte à côte.
              Row(children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Prix normal (HTG) *'),
                    _field(_prixCtrl, '500',
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Prix requis';
                          if (double.tryParse(v) == null || double.parse(v) <= 0)
                            return 'Prix invalide';
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
                          if (normal != null && promo >= normal)
                            return 'Doit être < prix normal';
                          return null;
                        },
                        keyboardType: TextInputType.number),
                  ],
                )),
              ]),
              const SizedBox(height: 16),

              // Stock initial du produit à la création.
              _label('Stock initial *'),
              _field(_stockCtrl, '10',
                  validator: (v) => v == null || v.isEmpty ? 'Stock requis' : null,
                  keyboardType: TextInputType.number),
              const SizedBox(height: 16),

              // Catégorie et sous-catégorie, toutes deux obligatoires,
              // saisies en texte libre côte à côte.
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

              // Sélecteur de couleurs : pastilles rondes de la palette
              // fixe ; un tap ajoute/retire la couleur (code hex) de la
              // liste `_couleurs`. Une coche est affichée sur la pastille
              // sélectionnée, avec une couleur de coche contrastée
              // (noir/blanc) calculée via `computeLuminance()`.
              _label('Couleurs (optionnel)'),
              Wrap(
                spacing: 10,
                children: _paletteCouleurs.map((hex) {
                  final sel = _couleurs.contains(hex);
                  final couleur =
                      Color(int.parse('0xFF${hex.replaceAll('#', '')}'));
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

              // Sélecteur de tailles (chips filtrables), même logique que
              // les couleurs.
              _label('Tailles (optionnel)'),
              Wrap(
                spacing: 8,
                children: _taillesDisponibles.map((t) {
                  final sel = _tailles.contains(t);
                  return FilterChip(
                    label: Text(t),
                    selected: sel,
                    onSelected: (v) => setState(() {
                      if (v) _tailles.add(t);
                      else _tailles.remove(t);
                    }),
                    selectedColor: const Color(0xFFEEF3FB),
                    checkmarkColor: const Color(0xFF0D2B5E),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Interrupteur "Disponible à la vente" — état initial du
              // produit lors de sa création (n'écrit rien en base tant
              // que le formulaire n'est pas soumis, contrairement au
              // switch de la liste produits qui écrit immédiatement).
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
              const SizedBox(height: 32),

              // Bouton final "Publier le produit" — désactivé pendant le
              // chargement (upload photo en cours ou sauvegarde) et
              // remplace son texte par un indicateur de progression.
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D2B5E),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _sauvegarder,
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Publier le produit',
                          style: TextStyle(color: Colors.white,
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Libellé de champ (petit texte gras au-dessus d'un champ de saisie).
  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t, style: const TextStyle(fontSize: 14,
            fontWeight: FontWeight.w600, color: Color(0xFF1A1F36))),
      );

  // Champ de texte réutilisable avec style commun (fond gris clair,
  // coins arrondis) et validateur/clavier optionnels.
  Widget _field(TextEditingController ctrl, String hint,
      {String? Function(String?)? validator,
      TextInputType? keyboardType}) =>
      TextFormField(
        controller: ctrl,
        validator: validator,
        keyboardType: keyboardType,
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
    // Libère tous les controleurs de texte pour éviter les fuites
    // mémoire à la fermeture de l'écran.
    _nomCtrl.dispose();
    _prixCtrl.dispose();
    _prixPromoCtrl.dispose();
    _stockCtrl.dispose();
    _categorieCtrl.dispose();
    _sousCategorieCtrl.dispose();
    super.dispose();
  }
}