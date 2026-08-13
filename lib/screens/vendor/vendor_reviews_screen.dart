import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../constants/app_colors.dart';

/// Avis clients — vue vendeur (menu hamburger, section 12.2)
/// Path : lib/screens/vendor/vendor_reviews_screen.dart
///
/// Ecran en lecture seule qui liste tous les avis (notes + commentaires)
/// laissés par les clients sur la boutique du vendeur connecté. Accessible
/// depuis le menu hamburger (drawer) du tableau de bord vendeur.
class VendorReviewsScreen extends StatefulWidget {
  const VendorReviewsScreen({super.key});

  @override
  State<VendorReviewsScreen> createState() => _VendorReviewsScreenState();
}

class _VendorReviewsScreenState extends State<VendorReviewsScreen> {
  // Liste brute des avis récupérés depuis Supabase (chaque élément est une
  // ligne de la table `reviews` sous forme de Map). On ne les convertit
  // pas en modèle typé ici, on lit directement les champs `note` et
  // `commentaire` dans le builder de liste plus bas.
  List<Map<String, dynamic>> _avis = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Chargement initial des avis dès l'ouverture de l'écran.
    _charger();
  }

  /// Charge une seule fois (pas de stream temps réel ici, contrairement à
  /// vendor_products_screen) la liste des avis de la boutique du vendeur
  /// connecté.
  Future<void> _charger() async {
    // IMPORTANT : on utilise `AuthProvider.shopId` (UUID réel résolu via
    // `shops.proprietaire_id`), et non le `shopCode` affiché à l'écran —
    // c'est ce shopId qui correspond à la colonne `reviews.shop_id`.
    final shopId = context.read<AuthProvider>().shopId;
    if (shopId == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      // Requête Supabase ponctuelle (pas de `.stream()`) : on lit toutes
      // les lignes de `reviews` où `shop_id` correspond à la boutique,
      // triées par date de création décroissante (les plus récents avis
      // en premier) via `.order('created_at', ascending: false)`.
      final rows = await Supabase.instance.client
          .from('reviews')
          .select()
          .eq('shop_id', shopId)
          .order('created_at', ascending: false);
      setState(() {
        _avis = List<Map<String, dynamic>>.from(rows);
        _isLoading = false;
      });
    } catch (e) {
      // En cas d'erreur réseau/Supabase, on arrête simplement le
      // chargement — la liste reste vide et l'écran affichera l'état
      // "Aucun avis pour l'instant".
      setState(() => _isLoading = false);
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
        title: const Text('Avis clients'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _avis.isEmpty
              ? Center(
                  child: Text('Aucun avis pour l\'instant',
                      style: TextStyle(color: AppColors.textSecondaryFor(isDark))),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _avis.length,
                  itemBuilder: (_, i) {
                    final r = _avis[i];
                    // Note sur 5 (entier), 0 par défaut si absente.
                    final note = (r['note'] ?? 0) as int;
                    // Commentaire texte optionnel laissé par le client.
                    final commentaire = r['commentaire'] as String?;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: AppColors.surface(isDark),
                          borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Affiche 5 étoiles : pleines pour les positions
                          // < note (donc `note` étoiles pleines), vides
                          // ensuite. Ex : note=3 -> ★★★☆☆.
                          Row(
                            children: List.generate(5, (j) => Icon(
                                j < note
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                size: 16, color: const Color(0xFFF5A623))),
                          ),
                          if (commentaire != null && commentaire.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(commentaire,
                                style: TextStyle(color: AppColors.textSecondaryFor(isDark))),
                          ],
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
