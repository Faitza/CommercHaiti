import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../models/product_model.dart';
import '../../providers/theme_provider.dart';
import '../../constants/app_colors.dart';

/// Stats Vendeur — Faitza COLAS
/// Branch : feature/vendor-catalog
/// Path : lib/screens/vendor/vendor_stats_screen.dart
///
/// Ecran de statistiques détaillées pour le vendeur : Top 5 des produits
/// les plus commandés, Flop 5 des produits les moins commandés (à
/// promouvoir), et alertes de stock bas (≤ 5 unités). Ces trois sections
/// correspondent aux exigences du cahier des charges BF-031 (indicateurs
/// de vente), BF-032 (produits à promouvoir) et BF-033 (alertes stock).
/// Les calculs eux-mêmes sont effectués côté service (DatabaseService),
/// cet écran ne fait qu'afficher les résultats.
class VendorStatsScreen extends StatefulWidget {
  const VendorStatsScreen({super.key});

  @override
  State<VendorStatsScreen> createState() => _VendorStatsScreenState();
}

// L'état de l'écran est un simple gestionnaire de chargement de données
// (pas de sous-écritures Supabase ici, uniquement de la lecture agrégée).
class _VendorStatsScreenState extends State<VendorStatsScreen> {
  // Service centralisant les requêtes/agrégations Supabase pour les
  // statistiques (voir lib/services/database_service.dart).
  final _db = DatabaseService();
  // Les 5 produits les plus commandés (classés par nombre de commandes).
  List<ProductModel> _top5 = [];
  // Les 5 produits les moins commandés — candidats à une promotion.
  List<ProductModel> _flop5 = [];
  // Les produits dont le stock est descendu à 5 unités ou moins (BF-033).
  List<ProductModel> _stockBas = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Chargement initial de toutes les statistiques dès l'ouverture.
    _loadStats();
  }

  /// Récupère en parallèle (via `await` séquentiels ici, un après l'autre)
  /// les trois listes de statistiques depuis DatabaseService, qui exécute
  /// les agrégations correspondantes côté Supabase/Postgres.
  Future<void> _loadStats() async {
    final auth = context.read<AuthProvider>();
    // IMPORTANT : `auth.shopId` est l'UUID réel de la boutique (résolu via
    // `shops.proprietaire_id`), à utiliser pour toute requête vers les
    // tables Supabase — ne jamais utiliser le `shopCode` (ex.
    // "MFL-2026-4892") qui n'est qu'un code d'affichage.
    final shopId = auth.shopId ?? '';

    // Top 5 : produits avec le plus de commandes, limité à 5 résultats.
    final top5 = await _db.getTopProductsForShop(shopId, limit: 5);
    // Flop 5 : produits avec le moins de commandes (BF-032) — permet au
    // vendeur d'identifier les produits à mettre en avant/promouvoir.
    final flop5 = await _db.getFlop5Products(shopId);
    // Produits en stock bas (seuil ≤ 5, BF-033).
    final stockBas = await _db.getLowStockProducts(shopId);

    setState(() {
      _top5 = top5;
      _flop5 = flop5;
      _stockBas = stockBas;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B5E),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Statistiques'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          // RefreshIndicator permet de tirer vers le bas pour relancer
          // `_loadStats` et recharger des données fraîches manuellement
          // (pas de stream temps réel ici, contrairement à la liste
          // produits).
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section Top 5 : classement 1 à 5 avec le nombre de
                    // commandes de chaque produit affiché en suffixe.
                    _sectionTitle('Top 5 produits les plus demandés', isDark: isDark),
                    _top5.isEmpty
                        ? _emptyState('Pas encore de données', isDark: isDark)
                        : Column(
                            children: _top5.asMap().entries.map((e) =>
                              _produitRow(e.key + 1, e.value,
                                  suffix: '${e.value.totalCommandes} cmd')).toList(),
                          ),
                    const SizedBox(height: 20),

                    // Section Flop 5 : produits peu vendus, avec un
                    // bouton "Promo rapide" menant directement à l'écran
                    // de modification du produit (pour y baisser le prix
                    // par exemple).
                    _sectionTitle('Flop 5 — Produits à promouvoir', isDark: isDark),
                    _flop5.isEmpty
                        ? _emptyState('Pas encore de données', isDark: isDark)
                        : Column(
                            children: _flop5.map((p) => Card(
                              child: ListTile(
                                title: Text(p.nom),
                                subtitle: Text('${p.totalCommandes} commandes'),
                                trailing: TextButton(
                                  onPressed: () => context.push(
                                      '/vendor/edit-product',
                                      extra: p.id),
                                  child: const Text('Promo rapide',
                                      style: TextStyle(
                                          color: Color(0xFFE63946))),
                                ),
                              ),
                            )).toList(),
                          ),
                    const SizedBox(height: 20),

                    // Section Alertes stock bas (BF-033) : produits dont
                    // le stock est ≤ 5, avec bouton direct vers l'écran de
                    // modification du produit pour réapprovisionner.
                    _sectionTitle('Alertes stock bas (≤ 5 unités)', isDark: isDark),
                    _stockBas.isEmpty
                        ? _emptyState('Tous les stocks sont OK', isDark: isDark)
                        : Column(
                            children: _stockBas.map((p) => Card(
                              child: ListTile(
                                title: Text(p.nom),
                                subtitle: Text('Stock : ${p.stock}',
                                    style: const TextStyle(
                                        color: Color(0xFFF5A623))),
                                trailing: TextButton(
                                  onPressed: () => context.push(
                                      '/vendor/edit-product',
                                      extra: p.id),
                                  child: const Text('Modifier'),
                                ),
                              ),
                            )).toList(),
                          ),
                  ],
                ),
              ),
            ),
    );
  }

  // Ligne d'un produit du classement Top 5, avec un badge numéroté (1 à
  // 5) et un texte optionnel en fin de ligne (ex : "12 cmd").
  Widget _produitRow(int rang, ProductModel p, {String? suffix}) => Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF0D2B5E),
            child: Text('$rang',
                style: const TextStyle(color: Colors.white)),
          ),
          title: Text(p.nom),
          trailing: suffix != null
              ? Text(suffix,
                  style: const TextStyle(
                      color: Color(0xFF1D9E75),
                      fontWeight: FontWeight.bold))
              : null,
        ),
      );

  // Titre de section (ex : "Top 5 produits les plus demandés").
  Widget _sectionTitle(String t, {required bool isDark}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: TextStyle(fontSize: 15,
            fontWeight: FontWeight.bold, color: AppColors.accentFor(isDark))),
      );

  // Message affiché quand une section n'a pas encore de données (ex :
  // aucune commande encore passée pour calculer un classement).
  Widget _emptyState(String msg, {required bool isDark}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(color: AppColors.surface(isDark),
            borderRadius: BorderRadius.circular(12)),
        child: Text(msg, textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondaryFor(isDark))),
      );
}