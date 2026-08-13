import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/cart_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/product_model.dart';
import '../../widgets/product_card_widget.dart';
import '../auth/guest_home_screen.dart';
import '../../providers/theme_provider.dart';
import '../../constants/app_colors.dart';

/// Détail produit — Claudimyr CASSIGNOL
/// Branch : feature/client-home
/// Path : lib/screens/client/product_detail_screen.dart
///
/// Ekran fich detay yon pwodwi : foto (avèk stock ki mete ajou an tan
/// reyèl), non, pri, seleksyon koulè/gwosè, kantite, bouton "Panier"
/// ak "Commander" (acha dirèk), epi yon seksyon "Vous aimerez aussi…"
/// ki montre pwodwi ki sanble. Se youn nan ekran ki pi rich nan
/// aplikasyon an paske li melanje : yon .stream() Supabase pou stock
/// tan reyèl, plizyè rekèt "one-shot" pou pwodwi ki sanble (avèk yon
/// sistèm repli/fallback), ak jesyon eta lokal pou seleksyon
/// koulè/gwosè/kantite.
///
/// Écran de fiche détail d'un produit : photos (avec le stock mis à
/// jour en temps réel), nom, prix, sélection de couleur/taille,
/// quantité, boutons "Panier" et "Commander" (achat direct), et une
/// section "Vous aimerez aussi…" affichant des produits similaires.
/// C'est l'un des écrans les plus riches de l'application car il
/// combine : un .stream() Supabase pour le stock en temps réel,
/// plusieurs requêtes "one-shot" pour les produits similaires (avec un
/// système de repli/fallback), et une gestion d'état locale pour la
/// sélection de couleur/taille/quantité.
class ProductDetailScreen extends StatefulWidget {
  // Produit initial, transmis par l'écran précédent (carte produit)
  // via "extra" — sert de valeur de départ avant que le flux temps
  // réel (StreamBuilder plus bas) ne prenne le relais avec les données
  // les plus fraîches possibles.
  final ProductModel product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  // Index de la photo actuellement affichée dans le carrousel (pour
  // les points indicateurs de page en bas de l'image).
  int _photoIndex = 0;
  // Couleur choisie par l'utilisateur (null tant qu'aucune n'est
  // sélectionnée, ou si le produit n'a pas de variante couleur).
  String? _couleurSelectionnee;
  // Taille choisie par l'utilisateur (même logique que la couleur).
  String? _tailleSelectionnee;
  // Quantité choisie, modifiable via les boutons +/-, bornée entre 1
  // et le stock disponible.
  int _quantite = 1;
  ProductModel? _productLive; // Stock temps réel
  // _productLive contient la version la plus à jour du produit, mise
  // à jour en continu par le StreamBuilder branché sur Supabase
  // .stream() plus bas dans build(). Tant qu'aucune donnée temps réel
  // n'est encore arrivée, on retombe sur widget.product (voir les
  // "_productLive ?? widget.product" utilisés partout dans le fichier).
  List<ProductModel> _produitsSimilaires = [];
  // Nom de la boutique propriétaire du produit, chargé séparément (la
  // table "products" ne contient que shopId, pas le nom de la
  // boutique).
  String _shopNom = '';

  @override
  void initState() {
    super.initState();
    // Initialise _productLive avec les données déjà connues, en
    // attendant que le stream temps réel les remplace par une version
    // à jour.
    _productLive = widget.product;
    _chargerSimilaires();
    _chargerBoutique();
  }

  /// Récupère le nom de la boutique propriétaire du produit, pour
  /// l'afficher sous le titre du produit (ex. "Vendu par Boutique X").
  Future<void> _chargerBoutique() async {
    try {
      // Requête Supabase (Postgres) sur la table "shops" :
      // - .select('nom') : on ne récupère QUE la colonne nom (pas
      //   besoin du reste de la fiche boutique ici).
      // - .eq('id', ...) : la boutique propriétaire de ce produit.
      // - .maybeSingle() : s'attend à 0 ou 1 résultat (contrairement à
      //   .single() qui lèverait une erreur si aucune ligne n'est
      //   trouvée) — renvoie null si la boutique n'existe plus.
      // Appel one-shot (pas de .stream()) : le nom de la boutique ne
      // change quasiment jamais, un rafraîchissement temps réel n'est
      // pas nécessaire ici.
      final row = await Supabase.instance.client
          .from('shops')
          .select('nom')
          .eq('id', widget.product.shopId)
          .maybeSingle();
      if (mounted) setState(() => _shopNom = row?['nom'] as String? ?? '');
    } catch (_) {
      // Erreur silencieuse : si la requête échoue, _shopNom reste vide
      // et le bloc d'affichage du nom de boutique (plus bas) ne
      // s'affiche simplement pas.
    }
  }

  /// BF-023 : "Vous aimerez aussi…" — 4 produits.
  /// Priorité même sous-catégorie, puis même catégorie, puis n'importe quel
  /// autre produit dispo — pour ne jamais laisser la section vide quand le
  /// produit a une sous-catégorie/catégorie unique (catégories en texte libre
  /// côté vendeur, donc souvent aucun autre produit ne matche exactement).
  ///
  /// Explication détaillée du système de repli à 3 niveaux :
  ///
  /// Le problème : "catégorie" et "sous_categorie" sont des champs
  /// TEXTE LIBRE que chaque vendeur tape lui-même (pas une liste
  /// contrôlée / un référentiel fixe partagé entre vendeurs). Deux
  /// vendeurs peuvent donc écrire "Boissons" et "boisson" pour la même
  /// idée, ou bien un vendeur peut avoir créé une sous-catégorie très
  /// spécifique ("Jus de fruits locaux") qu'aucun autre produit dans
  /// toute la base n'utilise. Si on cherchait uniquement des produits
  /// avec une sous_categorie strictement identique (.eq exact), la
  /// section "Vous aimerez aussi…" resterait souvent VIDE pour ces
  /// produits à sous-catégorie unique — ce qui est une mauvaise
  /// expérience utilisateur (une section vide au milieu de la fiche
  /// produit).
  ///
  /// La solution : on essaie 3 requêtes de plus en plus larges, dans
  /// l'ordre, et on s'arrête dès qu'on a réuni 4 produits :
  ///   1) Même sous-catégorie exacte (le plus pertinent) — jusqu'à 4
  ///      résultats.
  ///   2) Si on n'a toujours pas 4 produits : même catégorie (plus
  ///      large que la sous-catégorie) — jusqu'à 8 résultats
  ///      supplémentaires demandés (pour compenser les doublons déjà
  ///      vus à l'étape 1, qui seront ignorés par le Set "vus").
  ///   3) Si on n'a toujours pas 4 produits : n'importe quel autre
  ///      produit disponible dans toute la plateforme (dernier
  ///      recours) — jusqu'à 8 résultats supplémentaires.
  /// Le produit actuel (widget.product.id) est toujours exclu via
  /// .neq('id', ...) pour ne jamais se recommander lui-même. Le Set
  /// "vus" évite d'ajouter deux fois le même produit si, par exemple,
  /// il apparaît à la fois dans le résultat de l'étape 1 et de l'étape
  /// 2 (peu probable ici car les étapes sont progressivement plus
  /// larges, mais reste une sécurité utile).
  Future<void> _chargerSimilaires() async {
    try {
      final client = Supabase.instance.client;
      // Ensemble des IDs de produits déjà retenus (ou à exclure),
      // initialisé avec l'ID du produit courant pour ne jamais se
      // recommander soi-même.
      final vus = <String>{widget.product.id};
      // Liste finale des produits similaires à afficher (max 4).
      final resultats = <ProductModel>[];

      /// Fonction locale utilitaire : parcourt les [rows] renvoyées par
      /// une requête Supabase, convertit chaque ligne en ProductModel,
      /// et l'ajoute à [resultats] SEULEMENT si son ID n'a pas déjà été
      /// vu (vus.add() renvoie false si l'élément était déjà présent
      /// dans le Set, ce qui sert ici de test de déduplication en une
      /// seule ligne). S'arrête dès que 4 résultats sont réunis, même
      /// s'il reste des lignes à traiter.
      void ajouter(List rows) {
        for (final r in rows) {
          if (resultats.length >= 4) break;
          final p = ProductModel.fromMap(r, r['id']);
          if (vus.add(p.id)) resultats.add(p);
        }
      }

      // Niveau 1 (le plus précis) : produits de la même sous-catégorie
      // exacte que le produit consulté, disponibles, en excluant le
      // produit lui-même. On demande jusqu'à 4 lignes car c'est
      // exactement le nombre maximum qu'on veut afficher.
      ajouter(await client
          .from('products')
          .select()
          .eq('sous_categorie', widget.product.sousCategorie)
          .eq('disponible', true)
          .neq('id', widget.product.id)
          .limit(4));

      // Niveau 2 (repli intermédiaire) : uniquement si le niveau 1 n'a
      // pas suffi à réunir 4 produits. On élargit à la CATÉGORIE
      // (moins précise que la sous-catégorie) et on demande jusqu'à 8
      // lignes cette fois, pour avoir de la marge après déduplication
      // avec les résultats déjà obtenus au niveau 1.
      if (resultats.length < 4) {
        ajouter(await client
            .from('products')
            .select()
            .eq('categorie', widget.product.categorie)
            .eq('disponible', true)
            .neq('id', widget.product.id)
            .limit(8));
      }

      // Niveau 3 (dernier recours) : si même la catégorie ne suffit
      // pas, on prend n'importe quel autre produit disponible sur
      // toute la plateforme, sans filtre de catégorie du tout. Cela
      // garantit que la section "Vous aimerez aussi…" n'est vide QUE
      // s'il n'existe vraiment aucun autre produit disponible ailleurs
      // (cas extrême, typiquement en tout début de vie de la
      // plateforme).
      if (resultats.length < 4) {
        ajouter(await client
            .from('products')
            .select()
            .eq('disponible', true)
            .neq('id', widget.product.id)
            .limit(8));
      }

      if (mounted) setState(() => _produitsSimilaires = resultats);
    } catch (_) {
      // Erreur silencieuse : la section "Vous aimerez aussi…" reste
      // vide et ne s'affiche simplement pas (voir le "if
      // (_produitsSimilaires.isNotEmpty)" plus bas).
    }
  }

  /// Détermine si le bouton "Ajouter au panier" / "Commander" doit être
  /// activable pour le produit [p] : il faut que le produit soit
  /// marqué disponible, qu'il ne soit pas en rupture de stock, ET que
  /// l'utilisateur ait fini de choisir couleur/taille si le produit en
  /// propose (voir _selectionComplete ci-dessous).
  bool _peutAjouter(ProductModel p) =>
      p.disponible &&
      p.stockStatus != StockStatus.epuise &&
      _selectionComplete;

  /// Vrai si l'utilisateur a bien choisi une couleur (quand le produit
  /// propose des couleurs) ET une taille (quand le produit propose des
  /// tailles). Un produit sans variante couleur/taille est toujours
  /// considéré comme "complet".
  bool get _selectionComplete {
    if (widget.product.couleurs.isNotEmpty && _couleurSelectionnee == null)
      return false;
    if (widget.product.tailles.isNotEmpty && _tailleSelectionnee == null)
      return false;
    return true;
  }

  /// Ajoute le produit (avec la couleur/taille/quantité sélectionnées)
  /// au panier partagé de l'utilisateur, et affiche une confirmation
  /// visuelle (SnackBar).
  void _ajouterAuPanier() {
    final auth = context.read<AuthProvider>();
    // Un invité non connecté ne peut pas avoir de panier persistant :
    // on lui propose de s'inscrire à la place d'ajouter réellement au
    // panier.
    if (!auth.isLoggedIn) {
      GuestHomeScreen.showInscriptionSheet(context);
      return;
    }
    // On utilise _productLive (la version la plus à jour reçue via le
    // stream temps réel) si elle est disponible, sinon on retombe sur
    // widget.product (valeur initiale) — voir l'opérateur ?? partout
    // dans ce fichier pour ce même motif.
    context.read<CartProvider>().addItem(
      product: _productLive ?? widget.product,
      quantite: _quantite,
      couleur: _couleurSelectionnee,
      taille: _tailleSelectionnee,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ajouté au panier !'),
          backgroundColor: Color(0xFF1D9E75),
          duration: Duration(seconds: 2)),
    );
  }

  /// "Commander" — achat direct sans passer par le panier partagé : ce
  /// produit devient la seule ligne de la commande (le panier ne gère
  /// qu'une seule ligne à la validation, voir order_form_screen).
  ///
  /// Autrement dit, ce bouton "Commander directement" est un raccourci
  /// pour l'utilisateur pressé : au lieu du parcours classique
  /// "Ajouter au panier -> aller au panier -> valider", on VIDE
  /// d'abord le panier existant (context.read<CartProvider>()..clear())
  /// pour ne pas mélanger cette commande avec d'éventuels articles déjà
  /// présents (le formulaire de commande ne traite qu'une seule ligne
  /// à la fois, voir order_form_screen), puis on y ajoute UNIQUEMENT ce
  /// produit (avec sa couleur/taille/quantité sélectionnées), et enfin
  /// on navigue directement vers le formulaire de commande. C'est donc
  /// un flux "achat en un clic" en plus du flux panier classique.
  void _commanderDirectement() {
    context.read<CartProvider>()
      ..clear()
      ..addItem(
        product: _productLive ?? widget.product,
        quantite: _quantite,
        couleur: _couleurSelectionnee,
        taille: _tailleSelectionnee,
      );
    // context.go() remplace toute la pile de navigation par le
    // formulaire de commande : une fois la commande validée ou
    // abandonnée, on ne doit PAS pouvoir revenir en arrière vers cette
    // fiche produit avec un panier déjà vidé/modifié entre-temps — go()
    // fait donc du formulaire de commande une nouvelle "racine" de
    // navigation, cohérent avec le comportement du bouton panier
    // ailleurs dans l'app (voir client_home_screen.dart).
    context.go('/order-form');
  }

  @override
  Widget build(BuildContext context) {
    // p est le produit affiché à l'écran : la version temps réel si
    // elle est disponible, sinon la version initiale transmise par
    // l'écran précédent.
    final p = _productLive ?? widget.product;
    final auth = context.watch<AuthProvider>();
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(isDark),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Carrousel photos avec stock temps réel — plein écran, jan maket la
            //
            // StreamBuilder branché directement sur un flux Supabase
            // .stream(...) : contrairement à un simple .select() (qui
            // ne récupère les données qu'une seule fois), .stream()
            // ouvre un ABONNEMENT TEMPS RÉEL (realtime) à la ligne
            // "products" dont l'id correspond au produit affiché. Dès
            // que cette ligne change en base (par exemple le vendeur
            // modifie le stock, le prix, ou marque le produit
            // indisponible pendant que le client regarde la fiche),
            // Supabase pousse automatiquement la nouvelle version au
            // client, et ce StreamBuilder reconstruit l'écran avec les
            // données à jour — SANS que l'utilisateur ait besoin de
            // rafraîchir manuellement la page. C'est particulièrement
            // utile ici pour éviter qu'un client commande un produit
            // dont le stock vient de tomber à zéro pendant sa
            // consultation.
            // - primaryKey: ['id'] indique à Supabase quelle colonne
            //   identifie une ligne de façon unique pour ce flux.
            // - .eq('id', widget.product.id) restreint le flux à CE
            //   produit précis (pas toute la table).
            StreamBuilder(
              stream: Supabase.instance.client
                  .from('products')
                  .stream(primaryKey: ['id'])
                  .eq('id', widget.product.id),
              builder: (context, snapshot) {
                // Dès qu'une nouvelle version du produit arrive via le
                // flux, on met à jour _productLive (variable d'état
                // partagée avec le reste du widget, utilisée aussi dans
                // _ajouterAuPanier / _commanderDirectement).
                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  _productLive = ProductModel.fromMap(
                      snapshot.data!.first, snapshot.data!.first['id']);
                }
                final prod = _productLive ?? widget.product;
                final nbPhotos = prod.photos.isEmpty ? 1 : prod.photos.length;

                return Stack(
                  children: [
                    // Carrousel horizontal des photos du produit
                    // (PageView) ; s'il n'y a aucune photo, on affiche
                    // quand même une "page" avec une icône placeholder
                    // (nbPhotos = 1 dans ce cas).
                    SizedBox(
                      height: 300,
                      child: PageView.builder(
                        itemCount: nbPhotos,
                        onPageChanged: (i) => setState(() => _photoIndex = i),
                        itemBuilder: (_, i) => prod.photos.isEmpty
                            ? Container(color: const Color(0xFFEEF3FB),
                                child: const Icon(Icons.image_outlined,
                                    size: 60, color: Color(0xFF0D2B5E)))
                            : Image.network(prod.photos[i], fit: BoxFit.cover,
                                width: double.infinity),
                      ),
                    ),
                    // Bouton retour flottant — jan maket la (pa gen barre navy)
                    // Bouton retour rond flottant par-dessus l'image
                    // (l'écran n'a pas d'AppBar classique, la barre bleu
                    // marine habituelle n'est pas utilisée ici pour
                    // laisser toute la place à la photo).
                    Positioned(
                      top: 8, left: 8,
                      child: SafeArea(
                        child: CircleAvatar(
                          backgroundColor: Colors.black26,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new,
                                color: Colors.white, size: 18),
                            // pop() : retour simple à l'écran précédent
                            // (ex. grille produits, carrousel accueil).
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ),
                    ),
                    // Badge de réduction, affiché si le produit (version
                    // temps réel) est actuellement en promotion.
                    if (prod.hasPromo)
                      Positioned(bottom: 14, left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                              color: const Color(0xFFE63946),
                              borderRadius: BorderRadius.circular(20)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.local_fire_department,
                                color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text('-${prod.pourcentageReduction}%',
                                style: const TextStyle(color: Colors.white,
                                    fontWeight: FontWeight.bold, fontSize: 12)),
                          ]),
                        ),
                      ),
                    // Points indicateurs de page
                    // Petits points en bas à droite indiquant la
                    // position actuelle dans le carrousel de photos
                    // (affichés seulement s'il y a plus d'une photo).
                    if (nbPhotos > 1)
                      Positioned(
                        bottom: 14, right: 16,
                        child: Row(
                          children: List.generate(nbPhotos, (i) =>
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(left: 4),
                              width: _photoIndex == i ? 16 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: _photoIndex == i
                                    ? Colors.white
                                    : Colors.white54,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            )),
                        ),
                      ),
                    // Voile noir semi-transparent "Non disponible",
                    // affiché par-dessus les photos si le produit
                    // (selon les dernières données temps réel) n'est
                    // plus disponible ou est en rupture de stock — ceci
                    // peut apparaître EN DIRECT pendant que le client
                    // regarde la fiche, grâce au StreamBuilder.
                    if (!prod.disponible ||
                        prod.stockStatus == StockStatus.epuise)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withOpacity(0.5),
                          child: const Center(
                            child: Text('Non disponible',
                                style: TextStyle(color: Colors.white,
                                    fontSize: 20, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nom produit + prix — jan maket la (l'un à côté de l'autre)
                  // Rangée avec le nom du produit à gauche (extensible)
                  // et le prix à droite, avec le prix barré d'origine
                  // en dessous si une promo est active.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(p.nom,
                            style: TextStyle(fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimaryFor(isDark))),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${p.prixAffiche.toStringAsFixed(0)} HTG',
                              style: TextStyle(fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.accentFor(isDark))),
                          if (p.hasPromo)
                            Text('${p.prix.toStringAsFixed(0)} HTG',
                                style: TextStyle(fontSize: 12,
                                    color: AppColors.textSecondaryFor(isDark),
                                    decoration: TextDecoration.lineThrough)),
                        ],
                      ),
                    ],
                  ),
                  // Nom de la boutique venderesse, affiché seulement une
                  // fois chargé par _chargerBoutique().
                  if (_shopNom.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(children: [
                        Icon(Icons.storefront_outlined,
                            size: 14, color: AppColors.textSecondaryFor(isDark)),
                        const SizedBox(width: 4),
                        Text(_shopNom,
                            style: TextStyle(
                                color: AppColors.textSecondaryFor(isDark), fontSize: 13)),
                      ]),
                    ),

                  // Stock bas
                  // Avertissement affiché quand le stock du produit est
                  // qualifié de "faible" par le modèle (stockStatus),
                  // pour inciter à l'achat rapide.
                  if (p.stockStatus == StockStatus.faible)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Plus que ${p.stock} en stock !',
                          style: const TextStyle(color: Color(0xFFF5A623),
                              fontWeight: FontWeight.w600)),
                    ),
                  const SizedBox(height: 16),

                  // Sélecteur couleur
                  // Affiché seulement si le produit propose des
                  // variantes de couleur. Chaque pastille est colorée
                  // en convertissant le code couleur hexadécimal
                  // (ex. "#FF0000") stocké en base en Color Flutter :
                  // on retire le "#" puis on préfixe par "0xFF" (canal
                  // alpha opaque) avant de parser en int.
                  if (p.couleurs.isNotEmpty) ...[
                    const Text('Couleur', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: p.couleurs.map((c) {
                        final sel = _couleurSelectionnee == c;
                        return GestureDetector(
                          onTap: () => setState(() => _couleurSelectionnee = c),
                          child: Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: Color(int.parse('0xFF${c.replaceAll('#', '')}')),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: sel ? const Color(0xFF0D2B5E) : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Sélecteur taille
                  // Affiché seulement si le produit propose des tailles
                  // ; chaque option est un "bouton" texte cliquable qui
                  // se met en surbrillance (fond bleu marine) une fois
                  // sélectionné.
                  if (p.tailles.isNotEmpty) ...[
                    const Text('Taille', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: p.tailles.map((t) {
                        final sel = _tailleSelectionnee == t;
                        return GestureDetector(
                          onTap: () => setState(() => _tailleSelectionnee = t),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: sel ? const Color(0xFF0D2B5E) : AppColors.scaffoldBg(isDark),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: sel
                                  ? const Color(0xFF0D2B5E)
                                  : AppColors.borderColor(isDark)),
                            ),
                            child: Text(t, style: TextStyle(
                                color: sel ? Colors.white : AppColors.textPrimaryFor(isDark),
                                fontWeight: FontWeight.w600)),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Quantité
                  // Sélecteur +/- pour la quantité désirée, borné entre
                  // 1 (bouton "-" désactivé en dessous) et p.stock
                  // (bouton "+" désactivé au-delà, pour ne jamais
                  // dépasser le stock disponible).
                  Row(children: [
                    const Text('Quantité', style: TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    IconButton(
                      onPressed: _quantite > 1
                          ? () => setState(() => _quantite--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                      color: AppColors.accentFor(isDark),
                    ),
                    Text('$_quantite', style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryFor(isDark))),
                    IconButton(
                      onPressed: _quantite < p.stock
                          ? () => setState(() => _quantite++)
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                      color: AppColors.accentFor(isDark),
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // Bouton panier — ou bandeau connexion pour le visiteur (maquette)
                  // Cette zone affiche l'un de 3 états mutuellement
                  // exclusifs, selon la situation :
                  //  1) Utilisateur non connecté -> bandeau invitant à
                  //     s'inscrire/se connecter (achat impossible en
                  //     mode invité).
                  //  2) Utilisateur connecté mais produit non
                  //     disponible -> bouton grisé désactivé.
                  //  3) Utilisateur connecté et produit disponible ->
                  //     les deux vrais boutons d'action : "Panier" et
                  //     "Commander" (achat direct).
                  if (!auth.isLoggedIn)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF0D2B5E)),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.lock_outline,
                                  size: 16, color: AppColors.accentFor(isDark)),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                    'Connectez-vous pour ajouter au panier',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.accentFor(isDark))),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFE63946),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                  // go('/role-selection') : remplace la
                                  // pile de navigation, car
                                  // l'inscription/connexion démarre un
                                  // tout nouveau parcours (l'utilisateur
                                  // ne doit pas pouvoir "revenir" en
                                  // arrière au milieu du flux
                                  // d'authentification vers cette fiche
                                  // produit avec un état incohérent).
                                  onPressed: () => context.go('/role-selection'),
                                  child: const Text('S\'inscrire',
                                      style: TextStyle(color: Colors.white)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                        color: Color(0xFF0D2B5E)),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                  onPressed: () => context.go('/role-selection'),
                                  child: Text('Connexion',
                                      style: TextStyle(
                                          color: AppColors.accentFor(isDark),
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  else if (!p.disponible)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.borderColor(isDark),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: null,
                        icon: const Icon(Icons.shopping_cart_outlined,
                            color: Colors.white),
                        label: const Text('Non disponible pour l\'acheteur',
                            style: TextStyle(color: Colors.white,
                                fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    )
                  else
                    // Deux choix, jan yo mande : mete nan panier OU
                    // kòmande dirèkteman san pase pa paj panyen an.
                    //
                    // Deux boutons côte à côte : "Panier" (ajoute
                    // simplement à la liste d'achats, via
                    // _ajouterAuPanier) et "Commander" (achat direct
                    // immédiat de CE produit uniquement, via
                    // _commanderDirectement — voir l'explication
                    // détaillée sur cette méthode plus haut). Les deux
                    // sont désactivés tant que _peutAjouter(p) est
                    // faux (produit indisponible, en rupture, ou
                    // sélection couleur/taille incomplète).
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                    color: _peutAjouter(p)
                                        ? const Color(0xFF0D2B5E)
                                        : AppColors.borderColor(isDark)),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed:
                                  _peutAjouter(p) ? _ajouterAuPanier : null,
                              icon: Icon(Icons.shopping_cart_outlined,
                                  color: _peutAjouter(p)
                                      ? AppColors.accentFor(isDark)
                                      : AppColors.borderColor(isDark)),
                              label: Text('Panier',
                                  style: TextStyle(
                                      color: _peutAjouter(p)
                                          ? AppColors.accentFor(isDark)
                                          : AppColors.borderColor(isDark),
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          // flex: 2 : ce bouton "Commander" prend deux
                          // fois plus de largeur que le bouton
                          // "Panier", car son libellé inclut le
                          // montant total (plus long) et c'est
                          // l'action principale mise en avant.
                          flex: 2,
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _peutAjouter(p)
                                    ? const Color(0xFFE63946)
                                    : AppColors.borderColor(isDark),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              onPressed: _peutAjouter(p)
                                  ? _commanderDirectement
                                  : null,
                              icon: const Icon(Icons.flash_on,
                                  color: Colors.white),
                              // Le libellé affiche directement le
                              // montant total (prix affiché x
                              // quantité), pour que l'utilisateur voie
                              // immédiatement combien il va payer avant
                              // de cliquer sur "Commander".
                              label: Text(
                                  'Commander · ${(p.prixAffiche * _quantite).toStringAsFixed(0)} HTG',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      ],
                    ),

                  // Message d'aide affiché quand l'utilisateur est
                  // connecté, le produit est disponible, mais la
                  // sélection couleur/taille n'est pas encore complète
                  // (explique pourquoi les boutons sont grisés).
                  if (auth.isLoggedIn && p.disponible && !_selectionComplete)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Sélectionnez couleur et taille avant d\'ajouter',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondaryFor(isDark), fontSize: 12)),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // Vous aimerez aussi… — BF-023
            // Section carrousel horizontal des produits similaires
            // (résultat du système de repli à 3 niveaux expliqué en
            // détail dans _chargerSimilaires() plus haut). N'est
            // affichée que si au moins un produit similaire a été
            // trouvé.
            if (_produitsSimilaires.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('Vous aimerez aussi…',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryFor(isDark))),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 190,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _produitsSimilaires.length,
                  itemBuilder: (_, i) => SizedBox(
                    width: 130,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: ProductCardWidget(
                        product: _produitsSimilaires[i],
                        // context.pushReplacement() : remplace la
                        // fiche produit ACTUELLE dans la pile par la
                        // nouvelle fiche produit similaire, au lieu de
                        // l'empiler par-dessus (ce qu'aurait fait
                        // push()) ou de vider toute la pile (ce
                        // qu'aurait fait go()). Résultat : si
                        // l'utilisateur enchaîne "produit A -> produit
                        // similaire B -> produit similaire C", le
                        // bouton retour le ramène directement à l'écran
                        // d'AVANT le produit A (ex. la grille ou
                        // l'accueil), pas à B puis A — on évite ainsi
                        // d'empiler indéfiniment des fiches produits
                        // les unes sur les autres au fil des clics sur
                        // "Vous aimerez aussi…".
                        onTap: () => context.pushReplacement(
                            '/client/product',
                            extra: _produitsSimilaires[i]),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
