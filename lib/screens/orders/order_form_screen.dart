import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/order_provider.dart';
import '../../models/order_model.dart';

/// Formulaire commande — Claudimyr CASSIGNOL
/// Branch : feature/cart-orders
/// Path : lib/screens/orders/order_form_screen.dart
class OrderFormScreen extends StatefulWidget {
  const OrderFormScreen({super.key});

  @override
  State<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends State<OrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _adresseCtrl = TextEditingController();
  final _telephoneCtrl = TextEditingController();
  final _confirmTelCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  String _zoneSelectionnee = '';
  bool _isLoading = false;

  final List<String> _zones = [
    'Cayes Centre', 'Cayes Nord', 'Cayes Sud',
    'Torbeck', 'Saint-Jean', 'Camp-Perrin',
  ];

  @override
  void initState() {
    super.initState();
    // Pré-remplir téléphone depuis profil
    final auth = context.read<AuthProvider>();
    _telephoneCtrl.text = auth.currentUser?.telephone ?? '';
  }

  String? _validateTelephone(String? v) {
    if (v == null || v.isEmpty) return 'Téléphone requis';
    if (!RegExp(r'^[\+0-9\s]+$').hasMatch(v)) return 'Chiffres uniquement';
    if (v.replaceAll(RegExp(r'[^\d]'), '').length < 8) return 'Numéro trop court';
    return null;
  }

  String? _validateConfirmTelephone(String? v) {
    if (v == null || v.isEmpty) return 'Confirmation requise';
    final t1 = _telephoneCtrl.text.replaceAll(RegExp(r'[^\d]'), '');
    final t2 = v.replaceAll(RegExp(r'[^\d]'), '');
    if (t1 != t2) return 'Les numéros ne correspondent pas';
    return null;
  }

  Future<void> _validerCommande() async {
    if (!_formKey.currentState!.validate()) return;
    if (_zoneSelectionnee.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Sélectionnez une zone de livraison'),
        backgroundColor: Color(0xFFE63946),
      ));
      return;
    }

    setState(() => _isLoading = true);

    final auth = context.read<AuthProvider>();
    final cart = context.read<CartProvider>();
    final orderProvider = context.read<OrderProvider>();

    if (cart.items.isEmpty) return;
    final item = cart.items.first;

    final order = OrderModel(
      id: '',
      clientId: auth.currentUser!.id,
      shopId: item.product.shopId,
      sellerId: '',
      items: [],
      total: cart.totalAvecPromo,
      statut: 'nouvelle',
      adresseLivraison: _adresseCtrl.text.trim(),
      zone: _zoneSelectionnee,
      telephoneClient: _telephoneCtrl.text.trim(),
      noteVendeur: _noteCtrl.text.isEmpty ? null : _noteCtrl.text.trim(),
      createdAt: DateTime.now(),
    );

    final orderId = await orderProvider.createOrder(
      order: order,
      productId: item.product.id,
      quantite: item.quantite,
      nomProduit: item.product.nom,
      prixProduit: item.product.prixAffiche,
      couleur: item.couleur,
      taille: item.taille,
    );

    setState(() => _isLoading = false);

    if (orderId != null) {
      cart.clear();
      if (mounted) {
        Navigator.pushReplacementNamed(
          context, '/order-tracking',
          arguments: {'orderId': orderId, 'vendeurTelephone': ''},
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(orderProvider.errorMessage ?? 'Erreur commande'),
          backgroundColor: const Color(0xFFE63946),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B5E),
        foregroundColor: Colors.white,
        title: const Text('Passer commande'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('Adresse de livraison *'),
              _field(_adresseCtrl, 'Cayes, Rue...',
                  validator: (v) => v == null || v.length < 5
                      ? 'Adresse trop courte' : null),
              const SizedBox(height: 16),

              _label('Zone de livraison *'),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _zones.map((z) {
                  final sel = _zoneSelectionnee == z;
                  return ChoiceChip(
                    label: Text(z),
                    selected: sel,
                    onSelected: (_) => setState(() => _zoneSelectionnee = z),
                    selectedColor: const Color(0xFFEEF3FB),
                    labelStyle: TextStyle(
                      color: sel ? const Color(0xFF0D2B5E) : const Color(0xFF666666),
                      fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                    ),
                    side: BorderSide(color: sel
                        ? const Color(0xFF0D2B5E) : const Color(0xFFCCCCCC)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              _label('Numéro de téléphone *'),
              _field(_telephoneCtrl, '+509 XXXX XXXX',
                  validator: _validateTelephone,
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 8),
              const Text('Pré-rempli depuis votre profil. Modifiable pour cette commande uniquement.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF999999))),
              const SizedBox(height: 16),

              _label('Confirmer le numéro *'),
              _field(_confirmTelCtrl, 'Ressaisir le numéro',
                  validator: _validateConfirmTelephone,
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 16),

              _label('Note pour le vendeur (optionnel)'),
              _field(_noteCtrl, 'Ex: Livrer après 17h...',
                  maxLines: 2, maxLength: 200),
              const SizedBox(height: 16),

              // Récapitulatif
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white,
                    borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Récapitulatif',
                        style: TextStyle(fontWeight: FontWeight.bold,
                            color: Color(0xFF0D2B5E))),
                    const Divider(),
                    ...cart.items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(item.product.nom,
                              overflow: TextOverflow.ellipsis)),
                          Text('x${item.quantite}'),
                          const SizedBox(width: 8),
                          Text('${item.sousTotal.toStringAsFixed(0)} HTG',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('${cart.totalAvecPromo.toStringAsFixed(0)} HTG',
                            style: const TextStyle(fontWeight: FontWeight.bold,
                                color: Color(0xFF0D2B5E))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text('Paiement à la livraison',
                        style: TextStyle(fontSize: 12, color: Color(0xFF666666))),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D2B5E),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _validerCommande,
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Confirmer la commande',
                          style: TextStyle(color: Colors.white,
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 32),
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
      TextInputType? keyboardType,
      int maxLines = 1,
      int? maxLength}) =>
      TextFormField(
        controller: ctrl,
        validator: validator,
        keyboardType: keyboardType,
        maxLines: maxLines,
        maxLength: maxLength,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFFAAAAAA)),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE63946))),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
        ),
      );

  @override
  void dispose() {
    _adresseCtrl.dispose();
    _telephoneCtrl.dispose();
    _confirmTelCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }
}
