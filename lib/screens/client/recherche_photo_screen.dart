import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../models/product_model.dart';
import '../../providers/theme_provider.dart';
import '../../services/recherche_photo_service.dart';
import '../../services/reseau_service.dart';
import '../../widgets/etat_widgets.dart';
import '../../widgets/product_card_widget.dart';

/// Recherche par photo — résultats (comme sur Shein)
/// Path : lib/screens/client/recherche_photo_screen.dart
///
/// Ekran sa a montre foto kliyan an pran oswa chwazi a, epi pwodui ki
/// sanble plis ak li, soti nan tout boutik yo.
///
/// Affiche la photo prise ou choisie par le client, puis les produits
/// les plus ressemblants toutes boutiques confondues (du plus proche au
/// moins proche). Accessible sans compte, comme le catalogue (BF-010).
/// Ouvert via [ouvrirRecherchePhoto].
class RecherchePhotoScreen extends StatefulWidget {
  final Uint8List photo;
  const RecherchePhotoScreen({super.key, required this.photo});

  @override
  State<RecherchePhotoScreen> createState() => _RecherchePhotoScreenState();
}

/// Propose « Prendre une photo » ou « Choisir dans la galerie », puis
/// ouvre l'écran de résultats avec la photo obtenue. Ne fait rien si le
/// client annule. [remplacer] : depuis l'écran de résultats, la nouvelle
/// recherche remplace l'ancienne au lieu de s'empiler.
Future<void> ouvrirRecherchePhoto(BuildContext context,
    {bool remplacer = false}) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Rechercher avec une photo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
                'Trouvez des produits qui ressemblent à votre photo.',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Prendre une photo'),
            onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choisir dans la galerie'),
            onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (source == null) return;

  final fichier = await ImagePicker().pickImage(
    source: source,
    // Le modèle travaille en 224×224 : inutile de garder une photo de
    // caméra en pleine résolution (moins de mémoire, calcul plus rapide).
    maxWidth: 800,
    maxHeight: 800,
    imageQuality: 85,
  );
  if (fichier == null) return;
  final octets = await fichier.readAsBytes();
  if (!context.mounted) return;
  if (remplacer) {
    context.pushReplacement('/client/recherche-photo', extra: octets);
  } else {
    context.push('/client/recherche-photo', extra: octets);
  }
}

class _RecherchePhotoScreenState extends State<RecherchePhotoScreen> {
  List<ProductModel> _resultats = [];
  bool _isLoading = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _rechercher();
  }

  Future<void> _rechercher() async {
    setState(() {
      _isLoading = true;
      _erreur = null;
    });
    try {
      final resultats =
          await RecherchePhotoService.instance.rechercher(widget.photo);
      if (!mounted) return;
      setState(() {
        _resultats = resultats;
        _isLoading = false;
      });
    } on FormatException {
      if (!mounted) return;
      setState(() {
        _erreur = 'Impossible de lire cette photo. Essayez-en une autre.';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = messageErreur(e,
            parDefaut: 'La recherche a échoué. Réessayez.');
        _isLoading = false;
      });
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
        title: const Text('Recherche par photo',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        actions: [
          // Nouvelle photo : remplace cet écran par une nouvelle recherche.
          IconButton(
            tooltip: 'Nouvelle photo',
            icon: const Icon(Icons.photo_camera_outlined),
            onPressed: () => ouvrirRecherchePhoto(context, remplacer: true),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rappel de la photo recherchée.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(widget.photo,
                      width: 72, height: 72, fit: BoxFit.cover),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isLoading
                        ? 'Recherche de produits similaires…'
                        : _erreur != null
                            ? ''
                            : '${_resultats.length} produit'
                                '${_resultats.length > 1 ? 's' : ''} '
                                'similaire${_resultats.length > 1 ? 's' : ''}',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondaryFor(isDark)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const ChargementWidget()
                : _erreur != null
                    ? EtatErreurWidget(
                        message: _erreur!, onReessayer: _rechercher)
                    : _resultats.isEmpty
                        ? const EtatVideWidget(
                            icone: Icons.image_search,
                            message: 'Aucun produit similaire trouvé',
                            detail: 'Essayez une photo plus nette, avec le '
                                'produit bien visible au centre.',
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.72,
                            ),
                            itemCount: _resultats.length,
                            itemBuilder: (_, i) => ProductCardWidget(
                              product: _resultats[i],
                              onTap: () => context.push('/client/product',
                                  extra: _resultats[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
