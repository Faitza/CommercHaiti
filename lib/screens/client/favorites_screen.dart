import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/favorite_provider.dart';
import '../../widgets/shop_logo_widget.dart';

/// Boutiques favorites — menu hamburger client (section 12.2/12.3)
/// Path : lib/screens/client/favorites_screen.dart
///
/// Ekran ki afiche lis boutik yon kliyan mete kòm "favori" (li klike sou
/// kè a nan lòt ekran yo). Se yon StatelessWidget paske tout eta a
/// (lis favori yo) rete jere nan FavoriteProvider, pa nan ekran an
/// menm.
///
/// Écran listant les boutiques qu'un client a marquées comme
/// "favorites" (via l'icône cœur ailleurs dans l'app). C'est un
/// StatelessWidget car tout l'état (la liste des favoris) est géré
/// centralement par FavoriteProvider, pas par cet écran lui-même.
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // context.watch() rend ce build() réactif : dès que FavoriteProvider
    // notifie un changement (ajout/retrait d'un favori), la liste
    // affichée ici se met à jour automatiquement.
    final shops = context.watch<FavoriteProvider>().favoriteShops;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B5E),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          // Navigator.of(context).pop() retire simplement cet écran du
          // dessus de la pile de navigation et revient à l'écran
          // précédent (contrairement à context.go() qui remplacerait
          // toute la pile). Ici c'est le bon choix car Favoris est
          // toujours ouvert via push() depuis le menu hamburger.
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Mes favoris'),
      ),
      // Affiche soit un état vide (aucun favori), soit la liste des
      // boutiques favorites.
      body: shops.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border,
                      size: 60, color: Color(0xFFCCCCCC)),
                  SizedBox(height: 12),
                  Text('Aucune boutique favorite pour l\'instant',
                      style: TextStyle(color: Color(0xFF999999))),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: shops.length,
              itemBuilder: (_, i) {
                final shop = shops[i];
                return GestureDetector(
                  // context.push() empile l'écran de détail boutique
                  // par-dessus Favoris : le bouton retour ramènera bien
                  // ici. On transmet directement l'objet "shop" via
                  // "extra" pour éviter un rechargement réseau inutile.
                  onTap: () => context.push('/client/boutique-detail',
                      extra: shop),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        // Logo/initiales de la boutique.
                        ShopLogoWidget(
                            logoURL: shop.logoUrl,
                            initiales: shop.initiales,
                            size: 44),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(shop.nom,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              // Note moyenne de la boutique (1 décimale).
                              Row(children: [
                                const Icon(Icons.star_rounded,
                                    size: 14, color: Color(0xFFF5A623)),
                                const SizedBox(width: 2),
                                Text(shop.rating.toStringAsFixed(1),
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF666666))),
                              ]),
                            ],
                          ),
                        ),
                        // Bouton cœur toujours plein (rouge) ici puisque
                        // cette liste ne contient que des boutiques déjà
                        // favorites : un tap retire la boutique de la
                        // liste de favoris via toggleFavorite(), ce qui
                        // déclenche un notifyListeners() dans le
                        // provider et fait disparaître la carte de la
                        // liste au prochain rebuild.
                        IconButton(
                          icon: const Icon(Icons.favorite,
                              color: Color(0xFFE63946)),
                          onPressed: () => context
                              .read<FavoriteProvider>()
                              .toggleFavorite(shop.id),
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
