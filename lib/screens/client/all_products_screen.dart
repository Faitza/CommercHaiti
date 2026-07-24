import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/product_model.dart';
import '../../widgets/product_card_widget.dart';

/// Tous les produits — catalogue complet, toutes boutiques confondues.
/// Accessible sans compte (BF-010 — navigation libre).
/// Path : lib/screens/client/all_products_screen.dart
///
/// Ekran sa a montre yon katalòg konplè tout pwodwi ki disponib, san
/// gade nan ki boutik yo soti — kontrèman ak subcategory_screen.dart
/// ki limite a yon sèl boutik. Li aksesib menm pou moun ki poko gen
/// kont (invite), dapre règ BF-010. Li gen yon rechèch tèks lokal
/// (sou done deja chaje) ansanm ak yon filtè kategori ki, li menm,
/// deklanche yon nouvo rekèt Supabase.
///
/// Cet écran affiche un catalogue complet de tous les produits
/// disponibles, toutes boutiques confondues — contrairement à
/// subcategory_screen.dart qui se limite à une seule boutique. Il est
/// accessible même aux utilisateurs non connectés (invités), selon la
/// règle BF-010. Il combine une recherche texte locale (sur les
/// données déjà chargées en mémoire) avec un filtre de catégorie qui,
/// lui, déclenche une nouvelle requête Supabase.
class AllProductsScreen extends StatefulWidget {
  const AllProductsScreen({super.key});

  @override
  State<AllProductsScreen> createState() => _AllProductsScreenState();
}

class _AllProductsScreenState extends State<AllProductsScreen> {
  // Contrôleur du champ de recherche texte (filtrage local, pas de
  // requête réseau à chaque frappe).
  final _searchCtrl = TextEditingController();
  // Produits actuellement chargés depuis Supabase (avant filtrage
  // texte local).
  List<ProductModel> _produits = [];
  // Liste des catégories disponibles, calculée à partir des produits
  // chargés lorsqu'aucun filtre de catégorie n'est actif (voir
  // _charger()).
  List<String> _categories = [];
  // Catégorie actuellement sélectionnée ; chaîne vide = "Toutes" (pas
  // de filtre catégorie).
  String _categorieSelectionnee = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _charger();
    // Le listener force un rebuild (setState vide) à chaque frappe
    // dans le champ de recherche, ce qui recalcule automatiquement le
    // getter _produitsAffiches ci-dessous et met à jour la grille
    // affichée en temps réel, sans nouvel appel réseau.
    _searchCtrl.addListener(() => setState(() {}));
  }

  /// Charge (ou recharge) jusqu'à 100 produits disponibles depuis
  /// Supabase, triés par popularité (nombre total de commandes),
  /// filtrés par catégorie si une est sélectionnée.
  Future<void> _charger() async {
    setState(() => _isLoading = true);
    try {
      // Requête Supabase (Postgres) sur la table "products" :
      // - .eq('disponible', true) : uniquement les produits en vente.
      var query = Supabase.instance.client
          .from('products')
          .select()
          .eq('disponible', true);

      // Filtre optionnel supplémentaire par catégorie exacte (texte
      // libre défini par les vendeurs).
      if (_categorieSelectionnee.isNotEmpty) {
        query = query.eq('categorie', _categorieSelectionnee);
      }

      // .order('total_commandes', ascending: false) : trie les
      // produits du plus commandé au moins commandé, pour mettre en
      // avant les produits populaires en premier dans le catalogue.
      // .limit(100) : plafond de sécurité pour éviter de charger un
      // catalogue potentiellement énorme d'un coup.
      // Appel one-shot (pas de .stream()) : la liste ne se rafraîchit
      // pas toute seule ; RefreshIndicator plus bas permet à
      // l'utilisateur de relancer _charger() manuellement (tirer pour
      // rafraîchir).
      final rows = await query
          .order('total_commandes', ascending: false)
          .limit(100);

      final produits =
          rows.map((r) => ProductModel.fromMap(r, r['id'])).toList();

      if (mounted) {
        setState(() {
          _produits = produits;
          // On ne recalcule la liste des catégories (pour les chips
          // de filtre) QUE lorsque aucun filtre n'est actif :
          // sinon, si un filtre de catégorie est déjà sélectionné, la
          // liste de catégories se limiterait uniquement à celle
          // sélectionnée et les autres chips disparaîtraient de
          // l'écran après un premier clic.
          if (_categorieSelectionnee.isEmpty) {
            _categories = produits.map((p) => p.categorie).toSet().toList()
              ..sort();
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Applique le filtre de recherche texte (local, insensible à la
  /// casse) sur les produits déjà chargés en mémoire. Ne fait AUCUN
  /// appel réseau : la recherche se fait entièrement côté client sur
  /// les données déjà récupérées par _charger().
  List<ProductModel> get _produitsAffiches {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _produits;
    return _produits.where((p) => p.nom.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B5E),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          // pop() : retour simple à l'écran d'où le catalogue a été
          // ouvert (probablement l'accueil).
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Tous les produits'),
      ),
      body: Column(
        children: [
          // Barre recherche
          // Champ de recherche texte connecté à _searchCtrl : chaque
          // frappe déclenche (via le listener posé dans initState) un
          // recalcul du getter _produitsAffiches et un nouvel affichage
          // filtré, sans requête réseau.
          Padding(
            padding: const EdgeInsets.all(14),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                const Icon(Icons.search, color: Color(0xFF999999), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Rechercher un produit…',
                      hintStyle: TextStyle(fontSize: 13, color: Color(0xFF999999)),
                    ),
                  ),
                ),
              ]),
            ),
          ),

          // Filtres catégorie
          // Chips horizontaux de filtre par catégorie, affichés
          // seulement si des catégories ont été détectées. Chaque clic
          // (voir _chipCategorie plus bas) relance une requête Supabase
          // via _charger().
          if (_categories.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: [
                  _chipCategorie('Toutes', ''),
                  ..._categories.map((c) => _chipCategorie(c, c)),
                ],
              ),
            ),
          const SizedBox(height: 10),

          // Grille produits
          // Affiche : un loader pendant le chargement, un message si
          // aucun produit ne correspond au filtre (catégorie + texte),
          // sinon une grille scrollable avec pull-to-refresh
          // (RefreshIndicator déclenche à nouveau _charger()).
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _produitsAffiches.isEmpty
                    ? const Center(
                        child: Text('Aucun produit trouvé',
                            style: TextStyle(color: Color(0xFF999999))))
                    : RefreshIndicator(
                        onRefresh: _charger,
                        child: GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.72,
                          ),
                          itemCount: _produitsAffiches.length,
                          itemBuilder: (_, i) => ProductCardWidget(
                            product: _produitsAffiches[i],
                            // push() : ouvre le détail produit,
                            // retour possible vers ce catalogue.
                            onTap: () => context.push('/client/product',
                                extra: _produitsAffiches[i]),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  /// Construit un chip (ChoiceChip) de filtre de catégorie. Au clic, on
  /// met à jour la catégorie sélectionnée puis on relance _charger()
  /// pour récupérer les produits correspondants depuis Supabase (le
  /// filtre catégorie, contrairement à la recherche texte, est appliqué
  /// côté serveur).
  Widget _chipCategorie(String label, String value) {
    final sel = _categorieSelectionnee == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: sel,
        onSelected: (_) {
          setState(() => _categorieSelectionnee = value);
          _charger();
        },
        selectedColor: const Color(0xFFEEF3FB),
        labelStyle: TextStyle(
          color: sel ? const Color(0xFF0D2B5E) : const Color(0xFF666666),
          fontWeight: sel ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
        side: BorderSide(
            color: sel ? const Color(0xFF0D2B5E) : const Color(0xFFCCCCCC)),
      ),
    );
  }

  @override
  void dispose() {
    // Libère le contrôleur de recherche pour éviter une fuite mémoire.
    _searchCtrl.dispose();
    super.dispose();
  }
}
