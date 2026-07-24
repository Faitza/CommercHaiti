import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../models/shop_model.dart';
import '../../models/product_model.dart';
import '../../widgets/shop_logo_widget.dart';

/// Boutiques proposant un produit — Claudimyr CASSIGNOL
/// Branch : feature/client-home
/// Path : lib/screens/client/product_shops_screen.dart
/// Affiché quand client clique sur un produit populaire depuis l'accueil
///
/// Ekran sa a reponn kesyon "ki boutik ki gen pwodwi sa a ?" : kliyan
/// klike sou yon pwodwi popilè nan paj akèy la, epi ekran sa a fè yon
/// rechèch Supabase pou jwenn tout ofrann pwodwi ki gen menm non an nan
/// diferan boutik, avèk enfòmasyon boutik la mare ansanm.
///
/// Cet écran répond à la question « quelles boutiques vendent ce
/// produit ? » : le client clique sur un produit populaire depuis
/// l'accueil, et cet écran effectue une recherche Supabase pour
/// trouver toutes les offres de produits portant le même nom, dans
/// différentes boutiques, en récupérant aussi les infos de la boutique
/// associée.
class ProductShopsScreen extends StatefulWidget {
  // Nom du produit recherché (transmis par l'écran d'accueil via un
  // paramètre de route). Sert de critère de recherche texte.
  final String productNom;

  const ProductShopsScreen({super.key, required this.productNom});

  @override
  State<ProductShopsScreen> createState() => _ProductShopsScreenState();
}

class _ProductShopsScreenState extends State<ProductShopsScreen> {
  // Résultats bruts de la requête Supabase : chaque élément est une
  // Map représentant une ligne de la table "products", enrichie de la
  // boutique associée (clé "shops") grâce à la jointure demandée dans
  // le .select().
  List<Map<String, dynamic>> _results = [];
  // Indique si le chargement réseau est en cours, pour afficher un
  // spinner tant que la réponse Supabase n'est pas arrivée.
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Lance la recherche dès que l'écran est créé.
    _loadBoutiques();
  }

  /// Interroge Supabase pour trouver, dans TOUTES les boutiques, les
  /// produits disponibles dont le nom ressemble à widget.productNom.
  Future<void> _loadBoutiques() async {
    try {
      // Chercher produits avec ce nom dans toutes les boutiques
      //
      // Requête Supabase (Postgres) sur la table "products" :
      // - .select('*, shops(*)') : sélectionne toutes les colonnes du
      //   produit ET, grâce à la relation de clé étrangère déclarée en
      //   base, effectue une jointure automatique pour ramener aussi
      //   toutes les colonnes de la boutique liée (shops) sous forme
      //   d'objet imbriqué "shops" dans chaque ligne résultat.
      // - .ilike('nom', '%...%') : recherche insensible à la casse
      //   (ILIKE) où la colonne "nom" contient la chaîne productNom
      //   n'importe où (jokers % de part et d'autre) — équivalent d'un
      //   "contient" texte plutôt qu'une égalité stricte.
      // - .eq('disponible', true) : ne garde que les produits marqués
      //   disponibles par le vendeur.
      // Cette requête n'est PAS un .stream() : c'est un appel one-shot
      // (pas de rafraîchissement automatique si les données changent
      // ailleurs pendant que l'écran est ouvert).
      final rows = await Supabase.instance.client
          .from('products')
          .select('*, shops(*)')
          .ilike('nom', '%${widget.productNom}%')
          .eq('disponible', true);

      setState(() {
        _results = List<Map<String, dynamic>>.from(rows);
        _isLoading = false;
      });
    } catch (e) {
      // En cas d'erreur réseau/Supabase, on arrête simplement le
      // chargement (la liste _results reste vide -> état "aucun
      // résultat" affiché). Aucune remontée d'erreur à l'utilisateur
      // ici (amélioration possible mais hors périmètre du commentaire).
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
          // pop() retire cet écran de la pile et revient à l'accueil
          // d'où il a été ouvert (cohérent avec un accès via push()).
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.productNom),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(24),
          child: Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Boutiques disponibles',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ),
      ),
      // Affiche : un loader pendant le chargement, un message si aucune
      // boutique ne vend ce produit, sinon la liste des offres.
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty
              ? const Center(
                  child: Text('Aucune boutique ne propose ce produit',
                      style: TextStyle(color: Color(0xFF999999))))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _results.length,
                  itemBuilder: (_, i) {
                    final row = _results[i];
                    // Reconstruit un ProductModel typé à partir de la
                    // Map brute reçue de Supabase (row['id'] sert d'ID
                    // du document/ligne).
                    final product = ProductModel.fromMap(row, row['id']);
                    // Récupère la sous-map "shops" injectée par la
                    // jointure Supabase (peut être null si la relation
                    // n'a pas pu être résolue, ex. boutique supprimée).
                    final shopData = row['shops'] as Map<String, dynamic>?;

                    // Garde-fou : si pas de boutique associée, on
                    // n'affiche rien pour cette ligne plutôt que de
                    // planter sur un accès null.
                    if (shopData == null) return const SizedBox();

                    final shop = ShopModel.fromMap(shopData, shopData['id']);

                    return GestureDetector(
                      // push() empile l'écran détail boutique par-dessus
                      // celui-ci : retour possible vers cette liste de
                      // boutiques après consultation.
                      onTap: () => context.push('/client/boutique-detail',
                          extra: shop),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            ShopLogoWidget(
                              logoURL: shop.logoUrl,
                              initiales: shop.initiales,
                              size: 50,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(shop.nom,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  // Note moyenne de la boutique.
                                  Row(
                                    children: [
                                      const Icon(Icons.star_rounded,
                                          size: 14, color: Color(0xFFF5A623)),
                                      const SizedBox(width: 2),
                                      Text(shop.rating.toStringAsFixed(1),
                                          style: const TextStyle(fontSize: 12,
                                              color: Color(0xFF666666))),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Colonne prix, alignée à droite : prix
                            // affiché (prixAffiche, potentiellement déjà
                            // remisé) en gras, et si le produit est en
                            // promo (hasPromo), le prix d'origine barré
                            // en dessous.
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${product.prixAffiche.toStringAsFixed(0)} HTG',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0D2B5E),
                                      fontSize: 16),
                                ),
                                if (product.hasPromo)
                                  Text(
                                    '${product.prix.toStringAsFixed(0)} HTG',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF999999),
                                        decoration: TextDecoration.lineThrough),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
