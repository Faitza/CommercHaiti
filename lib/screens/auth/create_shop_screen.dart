import 'package:flutter/material.dart';

/// Créer boutique — Faitza COLAS
/// Branch : feature/auth-roles
/// Path : lib/screens/auth/create_shop_screen.dart
/// Premier écran après inscription vendeur
class CreateShopScreen extends StatefulWidget {
  final String shopCode; // généré automatiquement

  const CreateShopScreen({super.key, required this.shopCode});

  @override
  State<CreateShopScreen> createState() => _CreateShopScreenState();
}

class _CreateShopScreenState extends State<CreateShopScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  // Zones livraison disponibles aux Cayes
  final List<String> _zonesDisponibles = [
    'Cayes Centre',
    'Cayes Nord',
    'Cayes Sud',
    'Torbeck',
    'Saint-Jean',
    'Maniche',
    'Camp-Perrin',
  ];
  final List<String> _zonesSelectionnees = [];
  bool _isLoading = false;

  String? _validateNomBoutique(String? v) {
    if (v == null || v.isEmpty) return 'Nom requis';
    if (v.length < 3) return 'Minimum 3 caractères';
    if (v.length > 50) return 'Maximum 50 caractères';
    return null;
  }

  String? _validateDescription(String? v) {
    if (v == null || v.isEmpty) return 'Description requise';
    if (v.length < 10) return 'Minimum 10 caractères';
    if (v.length > 200) return 'Maximum 200 caractères';
    return null;
  }

  Future<void> _creerBoutique() async {
    if (!_formKey.currentState!.validate()) return;
    if (_zonesSelectionnees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sélectionnez au moins une zone de livraison'),
          backgroundColor: Color(0xFFE63946),
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    // TODO : FirestoreService.createShop(...)
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B5E),
        foregroundColor: Colors.white,
        title: const Text('Créer ma boutique'),
        automaticallyImplyLeading: false, // pas de retour en arrière
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Code boutique affiché
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF3FB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text('Votre code boutique',
                        style: TextStyle(color: Color(0xFF666666))),
                    const SizedBox(height: 4),
                    Text(
                      widget.shopCode,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D2B5E),
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Ce code identifie votre boutique sur les reçus',
                      style: TextStyle(
                          fontSize: 11, color: Color(0xFF999999)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Upload logo (placeholder)
              Center(
                child: GestureDetector(
                  onTap: () {
                    // TODO : image_picker → StorageService.uploadLogo()
                  },
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F4F8),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFFCCCCCC), width: 2),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined,
                            color: Color(0xFF0D2B5E), size: 28),
                        SizedBox(height: 4),
                        Text('Logo',
                            style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF666666))),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text('Optionnel — initiales affichées si absent',
                    style: TextStyle(
                        fontSize: 11, color: Color(0xFF999999))),
              ),
              const SizedBox(height: 24),

              // Nom boutique
              _label('Nom de la boutique *'),
              TextFormField(
                controller: _nomCtrl,
                validator: _validateNomBoutique,
                decoration: _inputDeco('Marché Frais Lakay'),
              ),
              const SizedBox(height: 16),

              // Description
              _label('Description *'),
              TextFormField(
                controller: _descriptionCtrl,
                validator: _validateDescription,
                maxLines: 3,
                decoration: _inputDeco(
                    'Décrivez votre boutique en quelques mots...'),
              ),
              const SizedBox(height: 24),

              // Zones livraison
              _label('Zones de livraison *'),
              const Text(
                'Sélectionnez les zones où vous livrez',
                style: TextStyle(fontSize: 12, color: Color(0xFF666666)),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _zonesDisponibles.map((zone) {
                  final selected = _zonesSelectionnees.contains(zone);
                  return FilterChip(
                    label: Text(zone),
                    selected: selected,
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _zonesSelectionnees.add(zone);
                        } else {
                          _zonesSelectionnees.remove(zone);
                        }
                      });
                    },
                    selectedColor: const Color(0xFFEEF3FB),
                    checkmarkColor: const Color(0xFF0D2B5E),
                    labelStyle: TextStyle(
                      color: selected
                          ? const Color(0xFF0D2B5E)
                          : const Color(0xFF666666),
                    ),
                    side: BorderSide(
                      color: selected
                          ? const Color(0xFF0D2B5E)
                          : const Color(0xFFCCCCCC),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),

              // Bouton créer
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D2B5E),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _creerBoutique,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Créer ma boutique',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1F36))),
      );

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFAAAAAA)),
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE63946)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );

  @override
  void dispose() {
    _nomCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }
}