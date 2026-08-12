import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/shop_model.dart';
import '../../models/product_model.dart';
import '../../widgets/shop_logo_widget.dart';
import '../../widgets/whatsapp_button_widget.dart';
import '../../providers/auth_provider.dart';
import '../../providers/favorite_provider.dart';
import '../auth/guest_home_screen.dart';

/// Détail boutique — Claudimyr CASSIGNOL
/// Branch : feature/client-home
/// Path : lib/screens/client/boutique_detail_screen.dart
///
/// Ekran detay yon boutik : li montre logo, deskripsyon, estatistik
/// (nòt, avi, kantite pwodwi), yon bouton WhatsApp pou kontakte
/// machann lan, kategori pwodwi yo, pwodwi popilè yo, ak avi kliyan
/// yo. Se yon melanj de done chaje yon sèl fwa (produits, catégories,
/// telefòn) ak yon sou-widget separe (_AvisSection) ki chaje pwòp
/// done pa li.
///
/// Écran de détail d'une boutique : il affiche le logo, la
/// description, des statistiques (note, avis, nombre de produits), un
/// bouton WhatsApp pour contacter le vendeur, les catégories de
/// produits, les produits populaires, et les avis clients. C'est un
/// mélange de données chargées une seule fois (produits, catégories,
/// téléphone) et d'un sous-widget séparé (_AvisSection) qui charge ses
/// propres données indépendamment.
class BoutiqueDetailScreen extends StatefulWidget {
  // Modèle de la boutique déjà chargé, transmis directement par
  // l'écran précédent (via "extra" dans context.push()), ce qui évite
  // une requête réseau supplémentaire juste pour réafficher les infos
  // déjà connues (nom, logo, note...).
  final ShopModel shop;
  const BoutiqueDetailScreen({super.key, required this.shop});

  @override
  State<BoutiqueDetailScreen> createState() => _BoutiqueDetailScreenState();
}

class _BoutiqueDetailScreenState extends State<BoutiqueDetailScreen> {
  // Liste des catégories uniques trouvées parmi les produits de cette
  // boutique (déduite dynamiquement, pas stockée en base séparément).
  List<String> _categories = [];
  // Liste des produits disponibles de la boutique.
  List<ProductModel> _produits = [];
  // Numéro de téléphone du vendeur, récupéré via une fonction RPC
  // sécurisée (voir _loadData ci-dessous) ; utilisé pour le bouton
  // WhatsApp. Vide tant qu'il n'a pas été chargé ou si l'appel échoue.
  String _telephoneVendeur = '';
  // Indique si le chargement initial (produits + catégories +
  // téléphone) est en cours.
  bool _isLoading = true;

  /// Icône selon le nom de la catégorie (mots-clés) — au lieu d'un
  /// cycle par position qui donnait des icônes sans rapport (ex. une
  /// feuille pour "Vêtements").
  ///
  /// Comme les catégories sont du texte libre saisi par chaque vendeur
  /// (pas une liste fixe), on ne peut pas simplement mapper "catégorie
  /// n°1 -> icône n°1". À la place, cette fonction cherche des
  /// mots-clés (en minuscule, via toLowerCase()) dans le nom de la
  /// catégorie pour choisir une icône cohérente avec le sens du mot,
  /// et retombe sur une icône générique (Icons.category_outlined) si
  /// aucun mot-clé connu n'est trouvé.
  static IconData _iconPourCategorie(String nom) {
    final n = nom.toLowerCase();
    if (n.contains('fruit') || n.contains('légum') || n.contains('legum') ||
        n.contains('aliment') || n.contains('épice') || n.contains('epice')) {
      return Icons.eco_outlined;
    }
    if (n.contains('vêtement') || n.contains('vetement') ||
        n.contains('mode') || n.contains('robe')) {
      return Icons.checkroom_outlined;
    }
    if (n.contains('électro') || n.contains('electro') ||
        n.contains('tech')) {
      return Icons.devices_outlined;
    }
    if (n.contains('cuisine') || n.contains('resto') ||
        n.contains('nourriture')) {
      return Icons.fastfood_outlined;
    }
    if (n.contains('maison') || n.contains('déco') || n.contains('deco')) {
      return Icons.home_outlined;
    }
    // Aucun mot-clé reconnu -> icône par défaut générique.
    return Icons.category_outlined;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Charge en une fois : les produits disponibles de la boutique, les
  /// catégories uniques qu'on en déduit, et le numéro de téléphone du
  /// vendeur (via RPC sécurisée) pour le bouton WhatsApp.
  Future<void> _loadData() async {
    try {
      // Charger produits de la boutique
      //
      // Requête Supabase (Postgres) sur la table "products" :
      // - .eq('shop_id', ...) : uniquement les produits de cette
      //   boutique précise.
      // - .eq('disponible', true) : uniquement ceux marqués
      //   disponibles par le vendeur.
      // Appel one-shot (pas de .stream()) : la liste ne se met pas à
      // jour automatiquement si le vendeur modifie ses produits pendant
      // que le client regarde cet écran.
      final rows = await Supabase.instance.client
          .from('products')
          .select()
          .eq('shop_id', widget.shop.id)
          .eq('disponible', true);

      final produits = rows
          .map((row) => ProductModel.fromMap(row, row['id']))
          .toList();

      // Extraire catégories uniques
      // .toSet() élimine les doublons (plusieurs produits peuvent
      // partager la même catégorie), .toList() reconvertit en liste
      // pour l'affichage.
      final cats = produits.map((p) => p.categorie).toSet().toList();

      // Téléphone du vendeur (pour le bouton WhatsApp) — via RPC
      // car la table users est protégée par RLS pour les autres profils.
      //
      // .rpc('get_vendor_telephone', ...) appelle une FONCTION
      // POSTGRES côté serveur Supabase (pas une simple requête SELECT
      // sur une table). Normalement, la table "users" est protégée par
      // des règles RLS (Row Level Security) qui empêchent un client de
      // lire directement les données personnelles (dont le téléphone)
      // d'un autre utilisateur — ici le vendeur. La fonction
      // get_vendor_telephone est déclarée en base avec l'attribut
      // SECURITY DEFINER : elle s'exécute avec les droits de son
      // propriétaire (souvent un rôle admin), ce qui lui permet de
      // "court-circuiter" la RLS de façon contrôlée et de ne renvoyer
      // QUE le numéro de téléphone du vendeur demandé (p_user_id),
      // sans exposer le reste de sa fiche utilisateur. C'est un moyen
      // sûr d'exposer une information précise sans affaiblir la
      // sécurité globale de la table users.
      String telephone = '';
      try {
        final result = await Supabase.instance.client.rpc(
            'get_vendor_telephone',
            params: {'p_user_id': widget.shop.proprietaireId});
        telephone = result as String? ?? '';
      } catch (_) {
        // Si la RPC échoue (ex. vendeur introuvable), on laisse
        // simplement telephone vide : le bouton WhatsApp ne
        // s'affichera pas plus bas (voir "if
        // (_telephoneVendeur.isNotEmpty)").
      }

      setState(() {
        _produits = produits;
        _categories = cats;
        _telephoneVendeur = telephone;
        _isLoading = false;
      });
    } catch (e) {
      // Erreur sur le chargement principal (produits) : on arrête le
      // loader, les listes restent vides.
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      // Structure simple Column [en-tête fixe, contenu scrollable] — jan
      // maket la montre : logo à gauche, nom de la boutique à droite à
      // côté de lui, description dans une carte séparée en dessous.
      // (Remplace l'ancien SliverAppBar/FlexibleSpaceBar avec logo centré
      // en grand, qui ne correspondait pas au maquette.)
      body: Column(
        children: [
          // En-tête bleu marine compact : bouton retour, logo, nom +
          // note/statut, cœur favori — tous alignés sur une seule rangée.
          Container(
            color: const Color(0xFF0D2B5E),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              bottom: 14, left: 4, right: 16,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white, size: 20),
                  // pop() : retour à l'écran précédent (liste de
                  // boutiques, favoris, etc.).
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ShopLogoWidget(
                  logoURL: widget.shop.logoUrl,
                  initiales: widget.shop.initiales,
                  size: 44,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.shop.nom,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                      Row(children: [
                        const Icon(Icons.star_rounded,
                            size: 14, color: Color(0xFFF5A623)),
                        const SizedBox(width: 2),
                        Text(widget.shop.rating.toStringAsFixed(1),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                        Text(
                            widget.shop.isOpen
                                ? ' · Ouvert' : ' · Fermé',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                      ]),
                    ],
                  ),
                ),
                // Bouton cœur (favori). Consumer2 écoute à la fois
                // AuthProvider et FavoriteProvider et reconstruit
                // uniquement ce petit widget quand l'un des deux change
                // (plus efficace qu'un watch() global qui reconstruirait
                // tout l'écran).
                Consumer2<AuthProvider, FavoriteProvider>(
                  builder: (context, auth, favProvider, _) {
                    final estFavori = favProvider.isFavorite(widget.shop.id);
                    return IconButton(
                      icon: Icon(
                          estFavori ? Icons.favorite : Icons.favorite_border,
                          color: estFavori
                              ? const Color(0xFFE63946)
                              : Colors.white),
                      onPressed: () {
                        // Un invité (non connecté) ne peut pas ajouter de
                        // favori : on lui propose plutôt de s'inscrire.
                        if (!auth.isLoggedIn) {
                          GuestHomeScreen.showInscriptionSheet(context);
                          return;
                        }
                        favProvider.toggleFavorite(widget.shop.id);
                      },
                    );
                  },
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
              children: [
                // Carte description : icône boutique + texte descriptif,
                // avec en dessous le délai de livraison et le nombre de
                // produits — jan maket la montre.
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5EE),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.storefront_outlined,
                            color: Color(0xFF1D9E75), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.shop.description,
                                style: const TextStyle(
                                    fontSize: 13, color: Color(0xFF444444))),
                            const SizedBox(height: 6),
                            Row(children: [
                              const Icon(Icons.access_time,
                                  size: 12, color: Color(0xFF999999)),
                              const SizedBox(width: 4),
                              Text(
                                  widget.shop.zonesLivraison.isNotEmpty
                                      ? widget.shop.zonesLivraison.first.delaiAffiche
                                      : '30-45 min',
                                  style: const TextStyle(
                                      fontSize: 11, color: Color(0xFF999999))),
                              Text(' · ${_produits.length} produits',
                                  style: const TextStyle(
                                      fontSize: 11, color: Color(0xFF999999))),
                            ]),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Bouton WhatsApp
                // Affiché seulement si on a réussi à récupérer un
                // numéro de téléphone valide via la RPC plus haut.
                // WhatsAppButtonWidget encapsule probablement
                // l'ouverture d'un lien wa.me/<numéro> pour lancer une
                // conversation WhatsApp directement avec le vendeur.
                if (_telephoneVendeur.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: WhatsAppButtonWidget(
                      telephone: _telephoneVendeur,
                      label: 'Contacter via WhatsApp',
                    ),
                  ),
                const SizedBox(height: 16),

                // Catégories
                // Affiche un loader tant que _loadData() n'est pas
                // terminé, sinon la liste des catégories (si non vide)
                // puis les produits populaires puis les avis clients.
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  if (_categories.isNotEmpty) ...[
                    _sectionTitle('Catégories'),
                    // Rangée horizontale de "cartes catégorie" : chacune
                    // affiche une icône (déduite du nom via
                    // _iconPourCategorie) et le nom de la catégorie.
                    SizedBox(
                      height: 96,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _categories.length,
                        itemBuilder: (_, i) => GestureDetector(
                          // push() : ouvre l'écran des sous-catégories
                          // pour cette catégorie précise, en empilant
                          // par-dessus l'écran détail boutique (retour
                          // possible ici après consultation). On
                          // transmet shopId + categorie dans une Map
                          // "extra" plutôt que des query params GoRouter
                          // classiques.
                          onTap: () => context.push('/client/subcategory',
                              extra: {
                                'shopId': widget.shop.id,
                                'categorie': _categories[i],
                              }),
                          child: Container(
                            width: 84,
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 6, offset: const Offset(0, 2),
                              )],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 40, height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEEF3FB),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                      _iconPourCategorie(_categories[i]),
                                      color: const Color(0xFF0D2B5E),
                                      size: 20),
                                ),
                                const SizedBox(height: 6),
                                Text(_categories[i],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1A1F36))),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Produits populaires boutique
                  // Grille (2 colonnes) affichant au maximum les 4
                  // premiers produits de la boutique (voir
                  // .take(4).length utilisé comme itemCount, mais noter
                  // que itemBuilder indexe directement dans _produits :
                  // ceci fonctionne car itemCount limite bien le nombre
                  // d'appels du builder à 4 maximum).
                  if (_produits.isNotEmpty) ...[
                    _sectionTitle('Produits populaires'),
                    GridView.builder(
                      // shrinkWrap + NeverScrollableScrollPhysics :
                      // cette grille ne défile pas elle-même, elle
                      // prend juste la hauteur nécessaire à son
                      // contenu et laisse le CustomScrollView parent
                      // gérer le défilement global de la page.
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.75,
                      ),
                      itemCount: _produits.take(4).length,
                      itemBuilder: (_, i) {
                        final p = _produits[i];
                        return GestureDetector(
                          // push() : ouvre la fiche détail du produit,
                          // avec retour possible vers cette page
                          // boutique.
                          onTap: () =>
                              context.push('/client/product', extra: p),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Image du produit (vignette) si
                                // disponible, sinon une icône
                                // placeholder générique.
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(12)),
                                    child: p.vignette != null
                                        ? Image.network(p.vignette!,
                                            fit: BoxFit.cover,
                                            width: double.infinity)
                                        : Container(
                                            color: const Color(0xFFEEF3FB),
                                            child: const Icon(
                                                Icons.image_outlined,
                                                color: Color(0xFF0D2B5E))),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(p.nom,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                      Text(
                                          '${p.prixAffiche.toStringAsFixed(0)} HTG',
                                          style: const TextStyle(
                                              color: Color(0xFF0D2B5E),
                                              fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],

                  // Avis clients
                  // Section déléguée à un sous-widget dédié
                  // (_AvisSection), qui gère lui-même son propre
                  // chargement Supabase indépendamment du reste de
                  // l'écran (voir plus bas).
                  _sectionTitle('Avis clients'),
                  _AvisSection(shopId: widget.shop.id),
                ],
                const SizedBox(height: 80),
              ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Petit titre de section réutilisé (Catégories, Produits populaires,
  /// Avis clients...).
  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Text(t, style: const TextStyle(fontSize: 16,
            fontWeight: FontWeight.bold, color: Color(0xFF0D2B5E))),
      );

}

/// Sous-widget indépendant qui affiche les avis clients d'une
/// boutique. Il est séparé du reste de l'écran pour pouvoir charger et
/// gérer son propre état de chargement sans dépendre du _loadData()
/// principal de BoutiqueDetailScreen.
class _AvisSection extends StatefulWidget {
  final String shopId;
  const _AvisSection({required this.shopId});

  @override
  State<_AvisSection> createState() => _AvisSectionState();
}

class _AvisSectionState extends State<_AvisSection> {
  // Liste brute des avis (chaque élément = une ligne de la table
  // "reviews").
  List<Map<String, dynamic>> _avis = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  /// Récupère les 10 derniers avis laissés pour cette boutique.
  Future<void> _charger() async {
    try {
      // Requête Supabase (Postgres) sur la table "reviews" :
      // - .eq('shop_id', ...) : uniquement les avis de cette boutique.
      // - .order('created_at', ascending: false) : du plus récent au
      //   plus ancien.
      // - .limit(10) : au maximum 10 avis, pour ne pas surcharger
      //   l'écran ni le réseau.
      // Appel one-shot (pas de .stream()) : un nouvel avis posté par un
      // autre client pendant que cet écran est ouvert n'apparaîtra pas
      // automatiquement, il faudrait rouvrir l'écran.
      final rows = await Supabase.instance.client
          .from('reviews')
          .select()
          .eq('shop_id', widget.shopId)
          .order('created_at', ascending: false)
          .limit(10);
      if (mounted) {
        setState(() {
          _avis = List<Map<String, dynamic>>.from(rows);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // État "chargement" : petit spinner.
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    // État "vide" : aucun avis pour cette boutique pour l'instant.
    if (_avis.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: const Text('Aucun avis pour l\'instant',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF999999))),
        ),
      );
    }
    // État normal : une carte par avis, avec 5 étoiles (pleines selon
    // la note, vides sinon) et le commentaire textuel s'il existe.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: _avis.map((r) {
          // r['note'] peut être null en base -> ?? 0 pour éviter un
          // crash de cast, puis "as int" pour typer la valeur.
          final note = (r['note'] ?? 0) as int;
          final commentaire = r['commentaire'] as String?;
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Génère 5 icônes étoile : pleine (star_rounded) pour
                // les indices < note, vide (star_border_rounded)
                // sinon — c'est ce qui dessine visuellement "3/5",
                // "5/5", etc.
                Row(
                  children: List.generate(5, (i) => Icon(
                      i < note ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 16, color: const Color(0xFFF5A623))),
                ),
                // Le commentaire texte n'est affiché que s'il existe et
                // n'est pas vide (un client peut avoir laissé une note
                // sans commentaire).
                if (commentaire != null && commentaire.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(commentaire,
                      style: const TextStyle(color: Color(0xFF444444))),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
