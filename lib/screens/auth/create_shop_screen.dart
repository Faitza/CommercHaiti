import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../services/storage_service.dart';
import '../../models/shop_model.dart';

/// Créer boutique — Faitza COLAS
/// Branch : feature/auth-roles
/// Path : lib/screens/auth/create_shop_screen.dart
/// Premier écran après inscription vendeur
// Formulaire de finalisation de la boutique : le vendeur vient de créer
// son compte (voir auth_screen.dart) et doit maintenant renseigner les
// informations de sa boutique (nom, description, logo, zones de
// livraison) avant d'accéder à son tableau de bord.
class CreateShopScreen extends StatefulWidget {
  // Code boutique généré côté inscription (ex: "MFL-2026-0000"), affiché
  // en lecture seule ici et enregistré tel quel avec la boutique.
  final String shopCode;
  const CreateShopScreen({super.key, required this.shopCode});

  @override
  State<CreateShopScreen> createState() => _CreateShopScreenState();
}

class _CreateShopScreenState extends State<CreateShopScreen> {
  // Clé du formulaire, utilisée pour déclencher la validation de tous les
  // champs d'un coup (_formKey.currentState!.validate()).
  final _formKey = GlobalKey<FormState>();
  // Services d'accès aux données (Supabase) et au stockage (upload logo).
  final _db = DatabaseService();
  final _storage = StorageService();
  // Sélecteur d'image natif (galerie photo du téléphone).
  final _picker = ImagePicker();

  final _nomCtrl         = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  // URL du logo une fois uploadé (null tant qu'aucun logo n'a été choisi).
  String? _logoUrl;
  // Zones de livraison sélectionnées par le vendeur (au moins une requise).
  final List<String> _zonesSelectionnees = [];
  // Indique un chargement en cours (upload logo ou création boutique) —
  // désactive le bouton de soumission et affiche un spinner.
  bool _isLoading = false;

  // Liste fixe des zones de livraison proposées (spécifiques à la région
  // des Cayes, contexte local de l'application).
  final List<String> _zonesDisponibles = [
    'Cayes Centre', 'Cayes Nord', 'Cayes Sud',
    'Torbeck', 'Saint-Jean', 'Maniche', 'Camp-Perrin',
  ];

  // Ouvre la galerie photo, puis envoie l'image choisie vers le service
  // de stockage (Supabase Storage) associée à l'ID de l'utilisateur
  // courant. Met à jour `_logoUrl` avec l'URL retournée.
  Future<void> _uploadLogo() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    // Si l'utilisateur annule la sélection, `file` est null : on arrête là.
    if (file == null) return;

    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();
    final url = await _storage.uploadShopLogo(
      file: file,
      shopId: auth.currentUser!.id,
    );
    setState(() {
      _logoUrl = url;
      _isLoading = false;
    });
  }

  // Valide le formulaire, s'assure qu'au moins une zone de livraison est
  // sélectionnée, puis construit un ShopModel et l'enregistre en base via
  // DatabaseService.createShop. Une fois la boutique créée, rafraîchit
  // l'ID de boutique stocké dans AuthProvider (nécessaire pour que le
  // reste de l'app — dashboard, produits, etc. — sache à quelle boutique
  // le vendeur est rattaché) puis navigue vers le tableau de bord vendeur.
  Future<void> _creerBoutique() async {
    if (!_formKey.currentState!.validate()) return;
    if (_zonesSelectionnees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Sélectionnez au moins une zone de livraison'),
        backgroundColor: Color(0xFFE63946),
      ));
      return;
    }

    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();

    // Construction du modèle boutique. `id` est laissé vide car il sera
    // généré côté base de données (ex: uuid) lors de l'insertion.
    final shop = ShopModel(
      id: '',
      proprietaireId: auth.currentUser!.id,
      nom: _nomCtrl.text.trim(),
      description: _descriptionCtrl.text.trim(),
      logoUrl: _logoUrl,
      shopCode: widget.shopCode,
      // Convertit chaque zone sélectionnée en objet ZoneLivraison avec
      // des délais de livraison par défaut (20 à 45 minutes).
      zonesLivraison: _zonesSelectionnees.map((z) =>
          ZoneLivraison(zone: z, delaiMin: 20, delaiMax: 45)).toList(),
      createdAt: DateTime.now(),
    );

    try {
      await _db.createShop(shop);
      // Recharge l'ID de boutique dans AuthProvider maintenant qu'une
      // boutique existe pour ce vendeur.
      await auth.refreshShopId();
      if (mounted) context.go('/vendor/dashboard');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : ${e.toString()}'),
          backgroundColor: const Color(0xFFE63946),
        ));
      }
    } finally {
      // Toujours exécuté (succès ou erreur) : on désactive le spinner.
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B5E),
        foregroundColor: Colors.white,
        title: const Text('Créer ma boutique'),
        // Pas de bouton retour automatique : cet écran est une étape
        // obligatoire après inscription vendeur, l'utilisateur ne doit
        // pas pouvoir revenir en arrière avant de l'avoir complétée.
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Code boutique
              // Encadré affichant le code boutique généré automatiquement
              // (en lecture seule) — sert à identifier la boutique sur les
              // reçus/commandes.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF3FB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(children: [
                  const Text('Votre code boutique',
                      style: TextStyle(color: Color(0xFF666666))),
                  const SizedBox(height: 4),
                  Text(widget.shopCode, style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold,
                      color: Color(0xFF0D2B5E), letterSpacing: 2)),
                  const SizedBox(height: 4),
                  const Text('Ce code identifie votre boutique sur les reçus',
                      style: TextStyle(fontSize: 11, color: Color(0xFF999999)),
                      textAlign: TextAlign.center),
                ]),
              ),
              const SizedBox(height: 24),

              // Logo
              // Zone circulaire cliquable pour choisir/afficher le logo de
              // la boutique. Affiche une icône "ajouter photo" tant
              // qu'aucun logo n'est choisi, sinon l'image elle-même en
              // fond (DecorationImage).
              Center(
                child: GestureDetector(
                  onTap: _uploadLogo,
                  child: Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F4F8),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFCCCCCC), width: 2),
                      image: _logoUrl != null
                          ? DecorationImage(
                              image: NetworkImage(_logoUrl!),
                              fit: BoxFit.cover)
                          : null,
                    ),
                    child: _logoUrl == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo_outlined,
                                  color: Color(0xFF0D2B5E), size: 28),
                              SizedBox(height: 4),
                              Text('Logo', style: TextStyle(
                                  fontSize: 12, color: Color(0xFF666666))),
                            ])
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Précise que le logo est facultatif (des initiales seront
              // affichées par défaut ailleurs dans l'app si absent).
              const Center(
                child: Text('Optionnel — initiales affichées si absent',
                    style: TextStyle(fontSize: 11, color: Color(0xFF999999))),
              ),
              const SizedBox(height: 24),

              // Nom
              // Champ obligatoire : nom de la boutique (3 à 50 caractères).
              _label('Nom de la boutique *'),
              TextFormField(
                controller: _nomCtrl,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Nom requis';
                  final t = v.trim();
                  if (t.length < 3) return 'Minimum 3 caractères';
                  if (t.length > 50) return 'Maximum 50 caractères';
                  if (!RegExp(r"^[A-Za-zÀ-ÿ' \-0-9&]+$").hasMatch(t)) {
                    return 'Caractères non autorisés';
                  }
                  if (!RegExp(r'[A-Za-zÀ-ÿ]').hasMatch(t)) {
                    return 'Le nom ne peut pas être uniquement des chiffres';
                  }
                  if (t.replaceAll(RegExp(r'[^0-9]'), '').length > 4) {
                    return 'Maximum 4 chiffres dans le nom';
                  }
                  return null;
                },
                decoration: _deco('Marché Frais Lakay'),
              ),
              const SizedBox(height: 16),

              // Description
              // Champ obligatoire : description de la boutique (10 à 200
              // caractères), affiché sur plusieurs lignes.
              _label('Description *'),
              TextFormField(
                controller: _descriptionCtrl,
                maxLines: 3,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Description requise';
                  final t = v.trim();
                  if (t.length < 10) return 'Minimum 10 caractères';
                  if (t.length > 200) return 'Maximum 200 caractères';
                  if (RegExp(r'\d').hasMatch(t)) {
                    return 'La description ne doit contenir aucun chiffre';
                  }
                  return null;
                },
                decoration: _deco('Décrivez votre boutique...'),
              ),
              const SizedBox(height: 24),

              // Zones livraison
              // Sélection multiple des zones de livraison via des
              // FilterChip. Au clic, on ajoute ou on retire la zone de la
              // liste `_zonesSelectionnees` (voir onSelected).
              _label('Zones de livraison *'),
              const Text('Sélectionnez les zones où vous livrez',
                  style: TextStyle(fontSize: 12, color: Color(0xFF666666))),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _zonesDisponibles.map((zone) {
                  final sel = _zonesSelectionnees.contains(zone);
                  return FilterChip(
                    label: Text(zone),
                    selected: sel,
                    onSelected: (v) => setState(() {
                      if (v) _zonesSelectionnees.add(zone);
                      else _zonesSelectionnees.remove(zone);
                    }),
                    selectedColor: const Color(0xFFEEF3FB),
                    checkmarkColor: const Color(0xFF0D2B5E),
                    labelStyle: TextStyle(
                      color: sel ? const Color(0xFF0D2B5E) : const Color(0xFF666666),
                    ),
                    side: BorderSide(
                      color: sel ? const Color(0xFF0D2B5E) : const Color(0xFFCCCCCC),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),

              // Bouton
              // Bouton de soumission final : désactivé et affichant un
              // spinner pendant `_isLoading` (upload logo ou création en
              // cours), sinon déclenche `_creerBoutique`.
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
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Créer ma boutique',
                          style: TextStyle(color: Colors.white,
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // Libellé au-dessus d'un champ de formulaire (même style que les autres
  // écrans d'authentification, pour cohérence visuelle).
  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t, style: const TextStyle(fontSize: 14,
            fontWeight: FontWeight.w600, color: Color(0xFF1A1F36))),
      );

  // Décoration commune des champs de texte de cet écran (fond gris clair,
  // pas de bordure visible sauf en cas d'erreur).
  InputDecoration _deco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFAAAAAA)),
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE63946))),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
      );

  @override
  void dispose() {
    // Libère les contrôleurs de texte pour éviter les fuites mémoire.
    _nomCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }
}
