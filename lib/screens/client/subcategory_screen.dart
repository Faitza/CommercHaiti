import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../models/product_model.dart';
import '../../widgets/product_card_widget.dart';

/// Sous-catégories & produits — Claudimyr CASSIGNOL
/// Branch : feature/client-home
/// Path : lib/screens/client/subcategory_screen.dart
///
/// Ekran sa a montre tout pwodwi yon boutik ki nan yon kategori
/// espesifik (egzanp : "Alimentation"), epi li pèmèt kliyan an filtre
/// plis pa sou-kategori (egzanp : "Boissons", "Snacks"...).
///
/// Cet écran affiche tous les produits d'une boutique appartenant à
/// une catégorie donnée (ex. « Alimentation »), et permet au client de
/// filtrer davantage par sous-catégorie (ex. « Boissons », « Snacks »
/// ...). Les catégories et sous-catégories sont des champs texte
/// libres saisis par le vendeur (pas une table de référence fixe),
/// d'où l'utilisation d'égalités exactes ci-dessous plutôt que d'un
/// référentiel de valeurs prédéfinies.
class SubcategoryScreen extends StatefulWidget {
  // Identifiant de la boutique dont on veut voir les produits.
  final String shopId;
  // Nom de la catégorie sélectionnée (texte libre défini par le
  // vendeur), utilisé comme filtre exact dans la requête Supabase.
  final String categorie;

  const SubcategoryScreen({
    super.key,
    required this.shopId,
    required this.categorie,
  });

  @override
  State<SubcategoryScreen> createState() => _SubcategoryScreenState();
}

class _SubcategoryScreenState extends State<SubcategoryScreen> {
  // Liste des produits actuellement affichés (déjà filtrés par
  // catégorie, et par sous-catégorie si une est sélectionnée).
  List<ProductModel> _produits = [];
  // Liste des sous-catégories disponibles, déduite dynamiquement des
  // produits chargés (pas une liste fixe en base) — voir toSet() plus
  // bas pour la déduplication.
  List<String> _sousCategories = [];
  // Sous-catégorie actuellement sélectionnée par l'utilisateur ;
  // chaîne vide = "Tous" (aucun filtre de sous-catégorie).
  String _sousCatSelectionnee = '';
  // Indique si la requête réseau est en cours.
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProduits();
  }

  /// Charge depuis Supabase les produits de la boutique correspondant à
  /// la catégorie (et, si sélectionnée, à la sous-catégorie), puis
  /// reconstruit dynamiquement la liste des sous-catégories disponibles
  /// à partir des résultats.
  Future<void> _loadProduits() async {
    try {
      // Requête Supabase (Postgres) sur la table "products" :
      // - .select() sans jointure : on récupère juste les colonnes du
      //   produit (contrairement à product_shops_screen qui joint la
      //   boutique).
      // - .eq('shop_id', ...) : ne garde que les produits appartenant à
      //   CETTE boutique précise.
      // - .eq('categorie', ...) : filtre exact sur le champ catégorie
      //   (texte libre saisi par le vendeur).
      // - .eq('disponible', true) : uniquement les produits que le
      //   vendeur a marqués comme disponibles à la vente.
      // Ceci est un appel one-shot (pas de .stream()) : les données ne
      // se rafraîchissent pas automatiquement si un vendeur modifie ses
      // produits pendant que l'écran est ouvert ; il faut relancer
      // _loadProduits() (ce qui est fait par exemple lors du choix
      // d'un filtre de sous-catégorie plus bas).
      var query = Supabase.instance.client
          .from('products')
          .select()
          .eq('shop_id', widget.shopId)
          .eq('categorie', widget.categorie)
          .eq('disponible', true);

      // Si une sous-catégorie est sélectionnée, on ajoute un filtre
      // supplémentaire exact sur la colonne sous_categorie avant
      // d'exécuter la requête.
      if (_sousCatSelectionnee.isNotEmpty) {
        query = query.eq('sous_categorie', _sousCatSelectionnee);
      }

      final rows = await query;
      // Convertit chaque ligne brute (Map) reçue de Supabase en un
      // ProductModel typé et exploitable par les widgets Flutter.
      final produits = rows
          .map((row) => ProductModel.fromMap(row, row['id']))
          .toList();

      // Reconstruit la liste des sous-catégories disponibles à partir
      // des produits eux-mêmes (et non d'une table séparée) :
      // .map() extrait le champ sousCategorie de chaque produit,
      // .toSet() élimine les doublons, .toList() reconvertit en liste
      // pour l'affichage des chips de filtre.
      final sousCats = produits
          .map((p) => p.sousCategorie)
          .toSet()
          .toList();

      setState(() {
        _produits = produits;
        _sousCategories = sousCats;
        _isLoading = false;
      });
    } catch (e) {
      // En cas d'erreur réseau, on arrête juste le chargement (état
      // "aucun produit" affiché par défaut).
      setState(() => _isLoading = false);
    }
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
          // pop() : revient simplement à l'écran précédent (probablement
          // la fiche boutique d'où cette catégorie a été ouverte via
          // push()).
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.categorie),
      ),
      body: Column(
        children: [
          // Filtre sous-catégories
          // Rangée horizontale de chips de filtre, affichée seulement
          // s'il existe au moins une sous-catégorie parmi les produits
          // chargés. "Tous" (valeur vide) réinitialise le filtre.
          if (_sousCategories.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _filterChip('Tous', ''),
                  ..._sousCategories.map((sc) => _filterChip(sc, sc)),
                ],
              ),
            ),

          // Produits
          // Grille de produits (2 colonnes) : loader pendant le
          // chargement, message si aucun produit ne correspond au
          // filtre, sinon une grille de ProductCardWidget cliquables.
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _produits.isEmpty
                    ? const Center(
                        child: Text('Aucun produit dans cette catégorie',
                            style: TextStyle(color: Color(0xFF999999))))
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.75,
                        ),
                        itemCount: _produits.length,
                        itemBuilder: (_, i) => ProductCardWidget(
                          product: _produits[i],
                          // push() empile l'écran détail produit :
                          // retour possible vers cette grille filtrée.
                          // "extra" transmet le ProductModel déjà chargé
                          // pour éviter une requête réseau
                          // supplémentaire côté écran détail.
                          onTap: () => context.push('/client/product',
                              extra: _produits[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  /// Construit un chip (ChoiceChip) de filtre de sous-catégorie.
  /// [label] est le texte affiché, [value] est la valeur réelle
  /// utilisée pour le filtre (chaîne vide pour "Tous").
  /// Au clic (onSelected), on met à jour la sous-catégorie sélectionnée
  /// puis on relance immédiatement _loadProduits() pour récupérer les
  /// produits correspondant au nouveau filtre depuis Supabase.
  Widget _filterChip(String label, String value) {
    final sel = _sousCatSelectionnee == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: sel,
        onSelected: (_) {
          setState(() => _sousCatSelectionnee = value);
          _loadProduits();
        },
        selectedColor: const Color(0xFFEEF3FB),
        labelStyle: TextStyle(
          color: sel ? const Color(0xFF0D2B5E) : const Color(0xFF666666),
          fontWeight: sel ? FontWeight.bold : FontWeight.normal,
        ),
        side: BorderSide(
            color: sel ? const Color(0xFF0D2B5E) : const Color(0xFFCCCCCC)),
      ),
    );
  }
}
