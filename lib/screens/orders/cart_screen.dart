import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/cart_provider.dart';
import '../../models/cart_item_model.dart';

/// Cart Screen — Claudimyr CASSIGNOL
/// Path : lib/screens/orders/cart_screen.dart
///
/// Affiche le contenu du panier d'achat du client (`CartProvider`, géré en
/// mémoire côté app, pas encore persisté en base tant que la commande n'est
/// pas validée). Permet de modifier les quantités, retirer des articles,
/// vider le panier, et lancer le passage de commande.
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // `watch` : ce widget doit se reconstruire à chaque changement du
    // panier (ajout/suppression d'article, changement de quantité...).
    final cart = context.watch<CartProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      body: Column(
        children: [
          // TopBar
          Container(
            color: const Color(0xFF0D2B5E),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              bottom: 12, left: 4, right: 16,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white, size: 20),
                  // context.go() REMPLACE la pile de navigation par
                  // '/client/home' (contrairement à context.push() qui
                  // empilerait une nouvelle route par-dessus). On veut ce
                  // comportement ici pour repartir sur une pile "propre" à
                  // l'accueil, plutôt que d'accumuler des écrans successifs
                  // — cette distinction go()/push() a été source de bugs de
                  // navigation (retours en arrière incohérents) plus tôt
                  // dans le projet, d'où l'attention portée à bien choisir
                  // la bonne méthode à chaque endroit.
                  onPressed: () => context.go('/client/home'),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Mon Panier',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                      Text('${cart.totalArticles} article(s)',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 10)),
                    ],
                  ),
                ),
                // Icône "vider le panier" affichée uniquement s'il y a des
                // articles (inutile de la montrer sur un panier déjà vide).
                if (cart.items.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.white54, size: 22),
                    onPressed: () => _confirmerVider(context, cart),
                  ),
              ],
            ),
          ),

          // Kontni
          // Contenu principal : soit un état "panier vide" avec incitation
          // à aller voir les boutiques, soit la liste des articles.
          Expanded(
            child: cart.items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF3FB),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Icons.shopping_cart_outlined,
                              size: 40, color: Color(0xFF0D2B5E)),
                        ),
                        const SizedBox(height: 16),
                        const Text('Votre panier est vide',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1F36))),
                        const SizedBox(height: 8),
                        const Text('Ajoutez des produits pour commander',
                            style: TextStyle(
                                fontSize: 13, color: Color(0xFF666666))),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D2B5E),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.store_outlined, size: 16),
                          label: const Text('Voir les boutiques'),
                          // go() ici aussi : on repart proprement vers la
                          // liste des boutiques plutôt que d'empiler une
                          // route supplémentaire.
                          onPressed: () => context.go('/client/boutiques'),
                        ),
                      ],
                    ),
                  )
                // Liste défilante d'une carte par article du panier. Les
                // callbacks onRemove/onDecrement/onIncrement délèguent
                // directement au CartProvider (removeItem/updateQuantite),
                // qui notifie ses listeners et fait donc se reconstruire cet
                // écran automatiquement (grâce à context.watch plus haut).
                : ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: cart.items.length,
                    itemBuilder: (_, i) => _CartItemCard(
                      item: cart.items[i],
                      index: i,
                      onRemove: () => cart.removeItem(i),
                      // Diminue la quantité de 1 (le CartProvider est
                      // responsable de gérer le cas limite, ex. suppression
                      // automatique si la quantité tombe à 0).
                      onDecrement: () => cart.updateQuantite(i, cart.items[i].quantite - 1),
                      onIncrement: () => cart.updateQuantite(i, cart.items[i].quantite + 1),
                    ),
                  ),
          ),

          // Total + Bouton commander
          // Barre du bas, visible seulement si le panier contient au moins
          // un article : récapitule les économies (promos), le total à
          // payer, et propose le bouton pour passer à l'étape suivante
          // (formulaire de commande).
          if (cart.items.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10, offset: const Offset(0, -2),
                )],
              ),
              child: Column(
                children: [
                  // Récapitulatif détaillé : Sous-total (prix normal, sans
                  // promo), Économies promo (si applicable), Livraison
                  // (gratuite — pas de frais de livraison dans ce projet),
                  // puis une séparation avant le Total final.
                  _recapLigne('Sous-total',
                      '${cart.totalNormal.toStringAsFixed(0)} HTG'),
                  if (cart.hasPromo)
                    _recapLigne('Économies promo',
                        '-${cart.economies.toStringAsFixed(0)} HTG',
                        color: const Color(0xFF1D9E75)),
                  _recapLigne('Livraison', 'Gratuite',
                      color: const Color(0xFF1D9E75)),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('${cart.totalAvecPromo.toStringAsFixed(0)} HTG',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0D2B5E))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE63946),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                      label: Text(
                          'Commander · ${cart.totalAvecPromo.toStringAsFixed(0)} HTG',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                      // go() : on avance vers le formulaire de commande en
                      // remplaçant la pile, pas en l'empilant. Cela évite
                      // qu'un utilisateur revienne "en arrière" depuis le
                      // formulaire directement sur le panier après avoir
                      // déjà validé/quitté le flux de commande — c'est
                      // cohérent avec le choix fait dans order_form_screen
                      // (qui utilise aussi go() pour aller vers l'écran de
                      // suivi une fois la commande créée).
                      onPressed: () => context.go('/order-form'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Une ligne du récapitulatif (Sous-total / Économies promo / Livraison) :
  // libellé à gauche, valeur à droite. `color` optionnelle pour les lignes
  // à mettre en avant (économies, livraison gratuite — en vert).
  Widget _recapLigne(String label, String valeur, {Color? color}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(
                color: color ?? const Color(0xFF666666), fontSize: 13)),
            Text(valeur, style: TextStyle(
                color: color ?? const Color(0xFF1A1F36),
                fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      );

  // Boîte de dialogue de confirmation avant de vider entièrement le panier
  // (action destructive, on demande confirmation pour éviter les erreurs).
  void _confirmerVider(BuildContext context, CartProvider cart) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Vider le panier ?'),
        content: const Text('Tous les articles seront supprimés.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE63946)),
            onPressed: () {
              cart.clear();
              Navigator.pop(context);
            },
            child: const Text('Vider', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// Carte représentant un seul article du panier : photo, nom, variantes
// (couleur/taille éventuelles), sous-total et contrôles de quantité (+/-),
// plus un bouton pour retirer l'article. Widget purement d'affichage —
// toute la logique métier (calculs, mutation du panier) reste dans
// CartProvider et est transmise via les callbacks.
class _CartItemCard extends StatelessWidget {
  final CartItem item;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _CartItemCard({
    required this.item, required this.index,
    required this.onRemove, required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 6, offset: const Offset(0, 2),
        )],
      ),
      child: Row(
        children: [
          // Foto pwodui
          // Photo du produit (miniature/vignette) ou icône de secours si le
          // produit n'a pas d'image renseignée.
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 64, height: 64,
              child: item.product.vignette != null
                  ? Image.network(item.product.vignette!, fit: BoxFit.cover)
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
                Text(item.product.nom,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                // Variantes
                // N'affiche cette ligne que si une couleur et/ou une taille
                // a été choisie pour ce produit (variantes optionnelles).
                if (item.couleur != null || item.taille != null)
                  Text(
                    [
                      if (item.couleur != null) 'Couleur: ${item.couleur}',
                      if (item.taille != null) 'Taille: ${item.taille}',
                    ].join(' · '),
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFF888888)),
                  ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${item.sousTotal.toStringAsFixed(0)} HTG',
                        style: const TextStyle(
                            color: Color(0xFF0D2B5E),
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                    // Bouton kantite
                    // Contrôles +/- pour ajuster la quantité de cet article
                    // directement depuis la carte, sans passer par un écran
                    // dédié.
                    Row(children: [
                      GestureDetector(
                        onTap: onDecrement,
                        child: Container(
                          width: 26, height: 26,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF3FB),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.remove,
                              size: 14, color: Color(0xFF0D2B5E)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text('${item.quantite}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                      GestureDetector(
                        onTap: onIncrement,
                        child: Container(
                          width: 26, height: 26,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D2B5E),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.add,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ]),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Bouton siprime
          // Icône "croix" pour retirer complètement cet article du panier.
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close,
                size: 18, color: Color(0xFFCCCCCC)),
          ),
        ],
      ),
    );
  }
}