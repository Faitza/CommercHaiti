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
class VendorAddProductScreen extends StatefulWidget {
  const VendorAddProductScreen({super.key});

  @override
  State<VendorAddProductScreen> createState() =>
      _VendorAddProductScreenState();
}

class _VendorAddProductScreenState extends State<VendorAddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseService();
  final _storage = StorageService();
  final _picker = ImagePicker();

  final _nomCtrl = TextEditingController();
  final _prixCtrl = TextEditingController();
  final _prixPromoCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();

  List<String> _photoUrls = [];
  List<String> _tailles = [];
  bool _disponible = true;
  bool _isLoading = false;

  final List<String> _taillesDisponibles = ['XS','S','M','L','XL','XXL'];

  Future<void> _ajouterPhoto() async {
    if (_photoUrls.length >= 4) return;
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();
    final shopId = auth.currentUser?.shopCode ?? '';
    final productId = DateTime.now().millisecondsSinceEpoch.toString();

    final url = await _storage.uploadProductPhoto(
      filePath: file.path,
      shopId: shopId,
      productId: productId,
    );

    if (url != null) setState(() => _photoUrls.add(url));
    setState(() => _isLoading = false);
  }

  Future<void> _sauvegarder() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final auth = context.read<AuthProvider>();
    final shopId = auth.currentUser?.shopCode ?? '';

    final product = ProductModel(
      id: '',
      shopId: shopId,
      nom: _nomCtrl.text.trim(),
      prix: double.parse(_prixCtrl.text),
      prixPromo: _prixPromoCtrl.text.isEmpty
          ? null
          : double.parse(_prixPromoCtrl.text),
      photos: _photoUrls,
      stock: int.parse(_stockCtrl.text),
      categorie: '',
      sousCategorie: '',
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
        title: const Text('Ajouter un produit'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photos
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

              _label('Stock initial *'),
              _field(_stockCtrl, '10',
                  validator: (v) => v == null || v.isEmpty ? 'Stock requis' : null,
                  keyboardType: TextInputType.number),
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
                      if (v) _tailles.add(t);
                      else _tailles.remove(t);
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
              const SizedBox(height: 32),

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

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t, style: const TextStyle(fontSize: 14,
            fontWeight: FontWeight.w600, color: Color(0xFF1A1F36))),
      );

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
    _nomCtrl.dispose();
    _prixCtrl.dispose();
    _prixPromoCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }
}