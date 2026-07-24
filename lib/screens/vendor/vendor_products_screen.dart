import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../models/product_model.dart';

/// Liste produits Vendeur — Faitza COLAS
/// Branch : feature/vendor-catalog
/// Path : lib/screens/vendor/vendor_products_screen.dart
///
/// Ecran qui affiche la liste complete des produits de la boutique du
/// vendeur connecte (catalogue). Le vendeur peut y rechercher un produit,
/// voir son stock en temps reel, l'activer/desactiver (disponible ou non
/// a la vente), le modifier ou le supprimer, et ajouter un nouveau produit.
class VendorProductsScreen extends StatefulWidget {
  const VendorProductsScreen({super.key});

  @override
  State<VendorProductsScreen> createState() => _VendorProductsScreenState();
}

class _VendorProductsScreenState extends State<VendorProductsScreen> {
  // Service qui centralise les appels Supabase liés aux produits
  // (update/delete). Voir lib/services/database_service.dart.
  final _db = DatabaseService();
  // Controleur du champ de recherche : permet de lire/ecouter le texte tape.
  final _searchCtrl = TextEditingController();
  // Texte de recherche courant (en minuscules) utilisé pour filtrer la
  // liste des produits affichés localement (filtrage cote client, pas de
  // requete Supabase supplementaire).
  String _query = '';

  @override
  void initState() {
    super.initState();
    // A chaque frappe dans le champ de recherche, on met a jour `_query`
    // et on redessine l'ecran (setState) pour filtrer la liste affichée.
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    // Toujours liberer les controleurs de texte pour eviter les fuites
    // memoire quand le widget est retire de l'arbre.
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // IMPORTANT : on utilise `AuthProvider.shopId` (l'UUID reel de la
    // boutique dans la table `shops`, resolu via une recherche sur
    // `shops.proprietaire_id`) et NON `shopCode` (le code lisible
    // affiché a l'utilisateur, ex: "MFL-2026-4892"). `shopCode` n'est
    // qu'un identifiant d'affichage — il ne correspond pas a une colonne
    // d'identifiant relationnel utilisable pour filtrer `products.shop_id`.
    // `context.watch` reabonne ce widget aux changements d'AuthProvider
    // (utile si le shopId se resout apres le premier build).
    final shopId = context.watch<AuthProvider>().shopId ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      body: Column(
        children: [
          // TopBar —  titre + kantite + bouton + wouj
          Container(
            color: const Color(0xFF0D2B5E),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              bottom: 14, left: 16, right: 16,
            ),
            child: Column(
              children: [
                // StreamBuilder branché sur `products.stream(...)` :
                // `.stream(primaryKey: ['id'])` ouvre un abonnement Supabase
                // Realtime sur la table `products` (au lieu d'un simple
                // `.select()` ponctuel). Chaque fois qu'une ligne est
                // ajoutée/modifiée/supprimée côté Postgres (ex : le vendeur
                // ajoute un produit depuis un autre écran, ou un client
                // passe une commande qui décrémente le stock), Supabase
                // pousse la nouvelle liste ici et Flutter reconstruit
                // automatiquement ce widget — pas besoin de rafraîchir
                // manuellement. `.eq('shop_id', shopId)` filtre pour ne
                // recevoir que les produits de la boutique du vendeur
                // connecté. Ici ce premier StreamBuilder ne sert qu'à
                // afficher le compteur "$nb produits" dans l'en-tête.
                StreamBuilder(
                  stream: Supabase.instance.client
                      .from('products')
                      .stream(primaryKey: ['id'])
                      .eq('shop_id', shopId),
                  builder: (context, snapshot) {
                    final nb = snapshot.data?.length ?? 0;
                    return Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new,
                              color: Colors.white, size: 18),
                          onPressed: () => context.go('/vendor/dashboard'),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Mes produits',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold)),
                              Text('$nb produits',
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 12)),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFE63946),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.add, color: Colors.white),
                            onPressed: () => context.push('/vendor/add-product'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(children: [
                    const Icon(Icons.search, color: Colors.white54, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: 'Rechercher un produit…',
                          hintStyle: TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),

          Expanded(
            // Deuxième StreamBuilder, identique en source (même requête
            // temps réel sur `products` filtrée par `shop_id`), mais cette
            // fois utilisé pour construire la vraie liste de cartes
            // produits affichée à l'écran.
            child: StreamBuilder(
              stream: Supabase.instance.client
                  .from('products')
                  .stream(primaryKey: ['id'])
                  .eq('shop_id', shopId),
              builder: (context, snapshot) {
                // Tant que la première réponse du stream n'est pas arrivée,
                // on affiche un indicateur de chargement.
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                // Aucune donnée reçue ou boutique sans produit : message
                // d'état vide invitant à utiliser le bouton "+".
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text('Aucun produit — appuyez sur + pour en ajouter',
                        style: TextStyle(color: Color(0xFF999999))),
                  );
                }
                // Chaque ligne brute (Map<String, dynamic>) renvoyée par
                // Supabase est convertie en objet Dart fortement typé
                // ProductModel via son constructeur `fromMap`.
                var products = snapshot.data!
                    .map((row) => ProductModel.fromMap(row, row['id']))
                    .toList();
                // Filtrage local (côté client) par nom de produit selon le
                // texte tapé dans la barre de recherche — aucune requête
                // Supabase supplémentaire n'est faite, on filtre la liste
                // déjà reçue via le stream.
                if (_query.isNotEmpty) {
                  products = products
                      .where((p) => p.nom.toLowerCase().contains(_query))
                      .toList();
                }

                // Affiche chaque produit filtré sous forme de carte
                // (_ProductListTile), dans une liste scrollable.
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: products.length,
                  itemBuilder: (_, i) => _ProductListTile(
                    product: products[i],
                    db: _db,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte affichant un produit dans la liste : photo, nom, prix, stock
/// (avec barre de progression et alerte couleur), interrupteur de
/// disponibilité et boutons modifier/supprimer.
class _ProductListTile extends StatelessWidget {
  final ProductModel product;
  final DatabaseService db;
  const _ProductListTile({required this.product, required this.db});

  @override
  Widget build(BuildContext context) {
    // Barre de progression du stock : on prend 20 unités comme "plein"
    // (valeur de référence arbitraire côté UI) et on borne entre 0 et 1.
    final fraction = (product.stock / 20).clamp(0.0, 1.0);
    // Code couleur du stock — correspond à la règle BF-033 (alerte stock
    // bas ≤ 5 unités) : rouge si épuisé (0), orange si stock bas (≤5),
    // vert sinon.
    final Color stockColor = product.stock == 0
        ? const Color(0xFFE63946)
        : product.stock <= 5
            ? const Color(0xFFF5A623)
            : const Color(0xFF1D9E75);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 64, height: 64,
                  child: product.vignette != null
                      ? Image.network(product.vignette!, fit: BoxFit.cover)
                      : Container(
                          color: const Color(0xFFEEF3FB),
                          child: const Icon(Icons.image_outlined,
                              color: Color(0xFF0D2B5E))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.nom,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                        '${product.categorie.isEmpty ? "—" : product.categorie} · ${product.prix.toStringAsFixed(0)} HTG',
                        style: const TextStyle(
                            color: Color(0xFF999999), fontSize: 12)),
                    const SizedBox(height: 6),
                    Row(children: [
                      Text('Stock : ${product.stock}',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12, color: stockColor)),
                      const SizedBox(width: 6),
                      if (product.stock == 0)
                        const Text('Épuisé',
                            style: TextStyle(
                                fontSize: 11, color: Color(0xFFE63946),
                                fontWeight: FontWeight.bold))
                      else if (product.stock <= 5)
                        const Text('Stock bas',
                            style: TextStyle(
                                fontSize: 11, color: Color(0xFFF5A623),
                                fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: fraction,
                        minHeight: 5,
                        backgroundColor: const Color(0xFFEEEEEE),
                        color: stockColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  _iconBtn(Icons.edit_outlined, const Color(0xFFEEF3FB),
                      const Color(0xFF0D2B5E),
                      () => context.push('/vendor/edit-product',
                          extra: product.id)),
                  const SizedBox(height: 6),
                  _iconBtn(Icons.delete_outline, const Color(0xFFFDEAEA),
                      const Color(0xFFE63946),
                      () => _supprimer(context)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(product.disponible ? 'Dispo' : 'Indispo',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: product.disponible
                          ? const Color(0xFF1D9E75)
                          : const Color(0xFFE63946))),
              // Interrupteur "Disponible/Indisponible" : bascule
              // immédiatement la colonne `disponible` du produit en base
              // via `DatabaseService.updateProduct` (UPDATE Supabase ciblé
              // sur l'id du produit). Le StreamBuilder parent recevra
              // automatiquement la mise à jour et rafraîchira l'affichage.
              Switch(
                value: product.disponible,
                activeColor: const Color(0xFF1D9E75),
                onChanged: (v) =>
                    db.updateProduct(product.id, {'disponible': v}),
              ),
            ],
          ),
          if (!product.disponible)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F4F8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Non disponible pour l\'acheteur',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Color(0xFF999999))),
            ),
        ],
      ),
    );
  }

  // Petit bouton icône réutilisable (fond coloré + icône) utilisé pour
  // "modifier" (bleu) et "supprimer" (rouge).
  Widget _iconBtn(IconData icon, Color bg, Color fg, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
              color: bg, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: fg),
        ),
      );

  /// Affiche une boîte de dialogue de confirmation avant de supprimer
  /// définitivement le produit (action irréversible). Si l'utilisateur
  /// confirme, on appelle `DatabaseService.deleteProduct` qui exécute un
  /// DELETE Supabase sur la ligne correspondante dans `products`.
  Future<void> _supprimer(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ce produit ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE63946)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await db.deleteProduct(product.id);
    }
  }
}
