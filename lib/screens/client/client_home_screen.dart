import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shop_provider.dart';
import '../../providers/favorite_provider.dart';
import '../../providers/theme_provider.dart';
import '../../models/product_model.dart';
import '../../models/shop_model.dart';
import '../../widgets/shop_logo_widget.dart';
import '../../widgets/app_drawer_widget.dart';
import '../../constants/app_colors.dart';

/// Client Home Screen — Claudimyr CASSIGNOL
/// Path : lib/screens/client/client_home_screen.dart
///
/// Ekran akèy prensipal pou kliyan konekte a : li montre yon barre
/// rechèch, pwomosyon, pwodwi popilè, ak lis boutik ouvè. Se ekran ki
/// pi konplèks nan seksyon kliyan an paske li melanje plizyè sous
/// done : yon flux tan reyèl (boutik yo, via ShopProvider.listenShops),
/// plizyè rekèt Supabase "one-shot" (pwodwi popilè, pwomosyon,
/// rechèch), ak yon Provider pou favori yo.
///
/// Écran d'accueil principal pour le client connecté : il affiche une
/// barre de recherche, des promotions, les produits populaires, et la
/// liste des boutiques ouvertes. C'est l'écran le plus complexe de la
/// section client car il combine plusieurs sources de données : un
/// flux temps réel (les boutiques, via ShopProvider.listenShops), des
/// requêtes Supabase "one-shot" (produits populaires, promotions,
/// recherche), et un Provider pour la gestion des favoris.
class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key});
  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  // Produits les plus commandés (section "Produits populaires").
  List<ProductModel> _topProduits = [];
  // Produits actuellement en promotion (prix_promo renseigné).
  List<ProductModel> _promoProduits = [];
  // Résultats de la recherche produit en cours (rempli par
  // _runSearch()).
  List<ProductModel> _searchProduits = [];
  // Indique si le chargement initial (produits populaires + promos)
  // est en cours.
  bool _isLoading = true;
  // Indique si une recherche produit est en cours d'exécution (appel
  // réseau Supabase déclenché par la saisie utilisateur).
  bool _isSearching = false;
  // Contrôleur du champ de recherche (produits & boutiques).
  final _searchCtrl = TextEditingController();
  // Clé du Scaffold, utilisée pour ouvrir le menu latéral (endDrawer)
  // par programmation (bouton hamburger), sans passer par un widget
  // Drawer/AppBar classique.
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  // Texte de recherche courant, normalisé en minuscule, utilisé pour
  // savoir si on doit afficher les résultats de recherche (_query
  // non vide) ou le contenu normal de l'accueil.
  String _query = '';

  @override
  void initState() {
    super.initState();
    // Charge produits populaires + promotions dès l'ouverture.
    _loadData();
    // Démarre l'écoute temps réel des boutiques (ShopProvider tient
    // probablement un flux Supabase .stream() en interne) : la liste
    // "Boutiques ouvertes" plus bas se met donc à jour automatiquement
    // si une boutique change de statut (ouvre/ferme) pendant que
    // l'utilisateur est sur cet écran.
    context.read<ShopProvider>().listenShops();
    final auth = context.read<AuthProvider>();
    // Si un utilisateur est connecté, démarre aussi l'écoute temps réel
    // de ses favoris (pour que le cœur des cartes produit/boutique
    // reflète l'état à jour sans rechargement manuel).
    if (auth.currentUser != null) {
      context.read<FavoriteProvider>().listenFavorites(auth.currentUser!.id);
    }
    // Écoute chaque frappe dans le champ de recherche : met à jour
    // _query (pour basculer l'affichage) et déclenche une recherche
    // Supabase à chaque changement de texte (pas de debounce visible
    // ici, donc potentiellement une requête réseau par frappe).
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.trim();
      setState(() => _query = q.toLowerCase());
      _runSearch(q);
    });
  }

  /// Recherche des produits dont le nom contient [q] (recherche
  /// insensible à la casse côté serveur). Les boutiques correspondantes
  /// sont, elles, filtrées localement dans _buildSearchResults() à
  /// partir de la liste déjà en mémoire (ShopProvider), pas via une
  /// nouvelle requête réseau.
  Future<void> _runSearch(String q) async {
    if (q.isEmpty) {
      // Champ vidé : on efface juste les résultats de recherche produit
      // (le contenu normal de l'accueil réapparaît car _query devient
      // vide aussi).
      setState(() => _searchProduits = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      // Requête Supabase (Postgres) sur la table "products" :
      // - .ilike('nom', '%$q%') : recherche insensible à la casse,
      //   "contient" la chaîne saisie n'importe où dans le nom.
      // - .eq('disponible', true) : uniquement les produits en vente.
      // - .limit(20) : au maximum 20 résultats.
      // Appel one-shot (pas de .stream()).
      final rows = await Supabase.instance.client
          .from('products')
          .select()
          .ilike('nom', '%$q%')
          .eq('disponible', true)
          .limit(20);
      // Double garde : le widget doit toujours être monté ET le texte
      // du champ ne doit pas avoir changé depuis le lancement de cette
      // requête (l'utilisateur a peut-être retapé pendant l'attente
      // réseau). Sans cette vérification, une réponse "en retard"
      // pourrait écraser des résultats plus récents avec des résultats
      // obsolètes correspondant à une saisie antérieure.
      if (!mounted || _searchCtrl.text.trim() != q) return;
      setState(() {
        _searchProduits =
            rows.map((r) => ProductModel.fromMap(r, r['id'])).toList();
        _isSearching = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  void dispose() {
    // Libère le contrôleur de recherche pour éviter une fuite mémoire.
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Charge les 10 produits les plus commandés (section "Produits
  /// populaires") et les produits actuellement en promotion (section
  /// "Promotions du jour"), via deux requêtes Supabase séparées.
  Future<void> _loadData() async {
    try {
      // Requête 1 : produits populaires.
      // - .eq('disponible', true) : produits en vente uniquement.
      // - .order('total_commandes', ascending: false) : du plus
      //   commandé au moins commandé.
      // - .limit(10) : les 10 premiers.
      final rows = await Supabase.instance.client
          .from('products')
          .select()
          .eq('disponible', true)
          .order('total_commandes', ascending: false)
          .limit(10);
      // Requête 2 : produits en promotion.
      // - .not('prix_promo', 'is', null) : ne garde que les lignes où
      //   la colonne prix_promo N'EST PAS null, c'est-à-dire les
      //   produits pour lesquels le vendeur a défini un prix promo.
      final promoRows = await Supabase.instance.client
          .from('products')
          .select()
          .eq('disponible', true)
          .not('prix_promo', 'is', null)
          .limit(10);
      setState(() {
        _topProduits = rows.map((r) => ProductModel.fromMap(r, r['id'])).toList();
        _promoProduits = promoRows
            .map((r) => ProductModel.fromMap(r, r['id']))
            // Filtre local supplémentaire : hasPromo est probablement un
            // getter du modèle qui vérifie que le prix promo est
            // réellement inférieur au prix normal (sécurité en plus du
            // simple "prix_promo non null" côté requête).
            .where((p) => p.hasPromo)
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // context.watch() : ce widget se reconstruit automatiquement à
    // chaque changement dans ces 3 providers (utilisateur, boutiques,
    // thème sombre/clair).
    final auth = context.watch<AuthProvider>();
    final shops = context.watch<ShopProvider>().shops;
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.scaffoldBg(isDark),
      // Menu latéral (tiroir) ouvert depuis la droite (endDrawer),
      // contenant les raccourcis principaux de navigation du compte
      // client.
      endDrawer: AppDrawerWidget(
        headerTitle: 'Bonjour ${auth.prenom}',
        headerSubtitle: 'CommercHaiti · Les Cayes',
        settingsRoute: '/params',
        items: [
          DrawerMenuItem(Icons.storefront_outlined, 'Boutiques',
              onTap: () {
            // Ferme d'abord le tiroir (pop du Drawer, pas de l'écran),
            // puis empile l'écran Boutiques par-dessus l'accueil :
            // push() permet de revenir à l'accueil avec le bouton
            // retour.
            Navigator.pop(context);
            context.push('/client/boutiques');
          }),
          DrawerMenuItem(Icons.category_outlined, 'Catégories', onTap: () {
            // "Catégories" mène maintenant vers le catalogue complet
            // (/client/all-products), qui affiche justement les filtres
            // de catégorie en évidence — distinct de "Boutiques" (liste
            // des boutiques) qu'il dupliquait avant.
            Navigator.pop(context);
            context.push('/client/all-products');
          }),
          DrawerMenuItem(Icons.grid_view_outlined, 'Tous les produits',
              onTap: () {
            Navigator.pop(context);
            context.push('/client/all-products');
          }),
          DrawerMenuItem(Icons.favorite_border, 'Favoris', onTap: () {
            Navigator.pop(context);
            context.push('/client/favorites');
          }),
          DrawerMenuItem(Icons.person_outline, 'Profil', onTap: () {
            Navigator.pop(context);
            context.push('/client/edit-profile');
          }),
        ],
      ),
      body: Column(
        children: [
          // TopBar bleu marine
          // Bandeau supérieur : logo/marque + localisation, bouton
          // panier, bouton menu hamburger, message de bienvenue
          // personnalisé et barre de recherche.
          Container(
            color: const Color(0xFF0D2B5E),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              bottom: 8, left: 16, right: 16,
            ),
            child: Column(
              children: [
                // Ranje 1 — Mak CommercHaiti + lokalizasyon (jan maket la montre)
                // Première rangée : logo panier + nom "CommercHaiti" +
                // ville, puis boutons panier et menu.
                Row(
                  children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE63946),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.shopping_cart,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CommercHaiti',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800)),
                          Row(children: [
                            Icon(Icons.location_on,
                                size: 10, color: Colors.white54),
                            SizedBox(width: 2),
                            Text('Les Cayes',
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 10)),
                          ]),
                        ],
                      ),
                    ),
                    // Panier
                    // context.go() remplace toute la pile de navigation
                    // par l'écran Panier : depuis l'accueil, on
                    // considère le panier comme une nouvelle "racine"
                    // de navigation plutôt qu'un écran empilé — cela
                    // évite d'accumuler Accueil -> Panier -> Accueil ->
                    // Panier... dans la pile si l'utilisateur navigue
                    // beaucoup entre les deux via la bottom nav / ce
                    // bouton.
                    GestureDetector(
                      onTap: () => context.go('/cart'),
                      child: Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.shopping_cart_outlined,
                            color: Colors.white, size: 18),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Menu hamburger
                    // Ouvre le endDrawer défini plus haut via la
                    // GlobalKey du Scaffold.
                    GestureDetector(
                      onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
                      child: Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.menu,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Ranje 2 — BF-013 : message de bienvenue personnalisé
                // Deuxième rangée : message de bienvenue utilisant le
                // prénom de l'utilisateur connecté (auth.prenom).
                Row(
                  children: [
                    const Icon(Icons.waving_hand,
                        color: Color(0xFFF5A623), size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Bonjour ${auth.prenom},',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800)),
                          const Text('Que voulez-vous aujourd\'hui ?',
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Barre rechèch — BF-013 : recherche produits & boutiques
                // Champ de recherche connecté à _searchCtrl ; une croix
                // apparaît pour vider le champ dès qu'une saisie est
                // présente (_query.isNotEmpty).
                Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Colors.white54, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: 'Rechercher produits ou boutiques…',
                            hintStyle: TextStyle(
                                color: Colors.white54, fontSize: 12),
                          ),
                        ),
                      ),
                      if (_query.isNotEmpty)
                        GestureDetector(
                          onTap: () => _searchCtrl.clear(),
                          child: const Icon(Icons.close,
                              color: Colors.white54, size: 16),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Kontni prensipal
          // Contenu principal : si une recherche est en cours (_query
          // non vide), on affiche les résultats de recherche ; sinon on
          // affiche le contenu normal de l'accueil (promotions,
          // produits populaires, boutiques ouvertes), avec
          // pull-to-refresh (RefreshIndicator relance _loadData()).
          Expanded(
            child: _query.isNotEmpty
                ? _buildSearchResults(shops)
                : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Bannière + section Promotions — BF-024/section 14
                    // Section affichée uniquement s'il existe au moins
                    // un produit en promotion : bannière rouge dégradée
                    // suivie d'un carrousel horizontal de cartes
                    // produit.
                    if (_promoProduits.isNotEmpty) ...[
                      Container(
                        margin: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE63946), Color(0xFFc0303c)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(children: [
                          const Icon(Icons.local_offer,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text('Promotions du jour ! (${_promoProduits.length})',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                        ]),
                      ),
                      SizedBox(
                        height: 180,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          itemCount: _promoProduits.length,
                          itemBuilder: (_, i) => _ProduitCard(
                            product: _promoProduits[i],
                            // push() : ouvre le détail produit,
                            // retour possible vers l'accueil.
                            onTap: () => context.push('/client/product',
                                extra: _promoProduits[i]),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Produits populaires
                    // Carrousel horizontal des 10 produits les plus
                    // commandés (chargés par _loadData()). "Voir tout"
                    // ouvre le catalogue complet.
                    _sectionTitle('Produits populaires',
                        onTap: () => context.push('/client/all-products')),
                    SizedBox(
                      height: 180,
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              itemCount: _topProduits.length,
                              itemBuilder: (_, i) => _ProduitCard(
                                product: _topProduits[i],
                                // Remarque : ici, contrairement aux
                                // autres cartes produit de cet écran,
                                // le clic ouvre '/client/product-shops'
                                // (liste des boutiques qui vendent ce
                                // produit, identifié par son NOM
                                // seulement, via "extra:
                                // _topProduits[i].nom") plutôt que la
                                // fiche détail du produit lui-même.
                                onTap: () => context.push(
                                  '/client/product-shops',
                                  extra: _topProduits[i].nom,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),

                    // Boutiques ouvertes
                    // Liste verticale (non scrollable indépendamment,
                    // shrinkWrap + NeverScrollableScrollPhysics : elle
                    // suit le défilement du SingleChildScrollView
                    // parent) de toutes les boutiques connues via
                    // ShopProvider (mises à jour en temps réel).
                    // "Voir tout" utilise context.go() ici (et non
                    // push()) : cela remplace la pile de navigation, ce
                    // qui signifie qu'on ne pourra pas revenir en
                    // arrière vers cet accueil avec le bouton retour
                    // depuis l'écran Boutiques dans ce cas précis — à
                    // comparer avec le Drawer plus haut qui utilise
                    // push() pour le même écran. Cette incohérence
                    // go()/push() entre les deux points d'entrée vers
                    // /client/boutiques est le genre de détail qui a
                    // déjà causé des bugs de navigation dans ce projet.
                    _sectionTitle('Boutiques ouvertes',
                        onTap: () => context.go('/client/boutiques')),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      itemCount: shops.length,
                      itemBuilder: (_, i) => _BoutiqueCard(
                        shop: shops[i],
                        // push() : détail boutique empilé, retour
                        // possible vers l'accueil.
                        onTap: () => context.push(
                          '/client/boutique-detail',
                          extra: shops[i],
                        ),
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

      // Bottom Navigation — 3 bouton
      // Barre de navigation basse : Accueil (actif ici, onTap vide
      // volontairement car on est déjà sur cet écran), Panier,
      // Commandes. Les deux derniers utilisent go() car ce sont des
      // sections "racines" équivalentes à l'accueil dans la navigation
      // principale de l'app.
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface(isDark),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12, offset: const Offset(0, -2),
          )],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(icon: Icons.home, label: 'Accueil', active: true,
                    onTap: () {}),
                _NavItem(icon: Icons.shopping_cart_outlined, label: 'Panier',
                    onTap: () => context.go('/cart')),
                _NavItem(icon: Icons.inventory_2_outlined, label: 'Commandes',
                    onTap: () => context.go('/order-history')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Construit l'affichage des résultats de recherche (produits +
  /// boutiques) lorsque _query n'est pas vide. Les produits proviennent
  /// de _searchProduits (déjà chargés via une requête Supabase dans
  /// _runSearch()) ; les boutiques, elles, sont filtrées LOCALEMENT à
  /// partir de la liste [shops] déjà en mémoire (ShopProvider), sans
  /// requête réseau supplémentaire — d'où l'utilisation d'un simple
  /// .where() + .contains() ici plutôt qu'un appel Supabase.
  Widget _buildSearchResults(List<ShopModel> shops) {
    final boutiquesTrouvees =
        shops.where((s) => s.nom.toLowerCase().contains(_query)).toList();

    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (boutiquesTrouvees.isEmpty && _searchProduits.isEmpty) {
      return Center(
        child: Text('Aucun résultat pour « ${_searchCtrl.text} »',
            style: const TextStyle(color: Color(0xFF999999))),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 14),
      children: [
        if (_searchProduits.isNotEmpty) ...[
          _sectionTitle('Produits (${_searchProduits.length})'),
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: _searchProduits.length,
              itemBuilder: (_, i) => _ProduitCard(
                product: _searchProduits[i],
                onTap: () => context.push('/client/product',
                    extra: _searchProduits[i]),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (boutiquesTrouvees.isNotEmpty) ...[
          _sectionTitle('Boutiques (${boutiquesTrouvees.length})'),
          ...boutiquesTrouvees.map((shop) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _BoutiqueCard(
                  shop: shop,
                  onTap: () =>
                      context.push('/client/boutique-detail', extra: shop),
                ),
              )),
        ],
      ],
    );
  }

  /// Titre de section réutilisé avec un lien optionnel "Voir tout" à
  /// droite (affiché seulement si un callback [onTap] est fourni).
  Widget _sectionTitle(String t, {VoidCallback? onTap}) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(t, style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.bold,
            color: Color(0xFF1A1F36))),
        if (onTap != null)
          GestureDetector(
            onTap: onTap,
            child: const Text('Voir tout',
                style: TextStyle(fontSize: 12, color: Color(0xFF0D2B5E))),
          ),
      ],
    ),
  );
}

/// Carte produit compacte utilisée dans les carrousels horizontaux
/// (Promotions, Produits populaires, résultats de recherche) : image,
/// badge de réduction éventuel, bouton favori, nom et prix.
class _ProduitCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onTap;
  const _ProduitCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Widget privé séparé de _ClientHomeScreenState : il a besoin de sa
    // propre lecture d'isDark (pas d'accès direct au isDark de l'écran
    // parent).
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: AppColors.surface(isDark),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6, offset: const Offset(0, 2),
          )],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                // Image du produit (vignette), ou icône placeholder si
                // aucune image n'est disponible.
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: SizedBox(
                    height: 100, width: double.infinity,
                    child: product.vignette != null
                        ? Image.network(product.vignette!, fit: BoxFit.cover)
                        : Container(
                            color: const Color(0xFFEEF3FB),
                            child: const Icon(Icons.image_outlined,
                                color: Color(0xFF0D2B5E), size: 36)),
                  ),
                ),
                // Badge pourcentage de réduction, affiché seulement si
                // le produit a une promo active.
                if (product.hasPromo)
                  Positioned(
                    top: 6, left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE63946),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('-${product.pourcentageReduction}%',
                          style: const TextStyle(color: Colors.white,
                              fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  ),
                // Bouton cœur (favori) superposé en haut à droite de
                // l'image. Consumer<FavoriteProvider> permet de ne
                // reconstruire QUE ce petit bouton quand l'état des
                // favoris change, sans reconstruire toute la carte
                // produit.
                //
                // ATTENTION (comportement à noter, pas à corriger
                // ici) : le bouton appelle
                // favProvider.toggleFavorite(product.shopId), donc il
                // met en favori/retire des favoris la BOUTIQUE
                // (shopId) du produit, pas le produit lui-même — et
                // c'est aussi product.shopId (pas l'ID produit) qui
                // sert à décider si le cœur est plein (estFavori).
                // C'est cohérent avec le fait que le système de
                // favoris de l'app porte sur les boutiques (voir
                // FavoritesScreen), mais peut prêter à confusion
                // visuellement puisque le cœur est affiché sur une
                // carte "produit".
                Positioned(
                  top: 4, right: 4,
                  child: Consumer<FavoriteProvider>(
                    builder: (context, favProvider, _) {
                      final estFavori = favProvider.isFavorite(product.shopId);
                      return GestureDetector(
                        onTap: () =>
                            favProvider.toggleFavorite(product.shopId),
                        child: Container(
                          width: 26, height: 26,
                          decoration: const BoxDecoration(
                              color: Colors.white70, shape: BoxShape.circle),
                          child: Icon(
                              estFavori ? Icons.favorite : Icons.favorite_border,
                              size: 14,
                              color: estFavori
                                  ? const Color(0xFFE63946)
                                  : const Color(0xFF999999)),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            // Nom du produit + prix (avec prix barré si promo active).
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.nom, maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: AppColors.textPrimaryFor(isDark),
                          fontWeight: FontWeight.w600, fontSize: 12)),
                  const SizedBox(height: 2),
                  Row(children: [
                    Text('${product.prixAffiche.toStringAsFixed(0)} HTG',
                        style: TextStyle(
                            color: AppColors.accentFor(isDark),
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                    if (product.hasPromo) ...[
                      const SizedBox(width: 4),
                      Text('${product.prix.toStringAsFixed(0)}',
                          style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondaryFor(isDark),
                              decoration: TextDecoration.lineThrough)),
                    ],
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carte boutique compacte utilisée dans la liste "Boutiques ouvertes"
/// et dans les résultats de recherche : logo, nom, note, badge
/// Ouvert/Fermé.
class _BoutiqueCard extends StatelessWidget {
  final ShopModel shop;
  final VoidCallback onTap;
  const _BoutiqueCard({required this.shop, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Widget privé séparé de _ClientHomeScreenState : même raison que
    // _ProduitCard, il lit lui-même isDark.
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface(isDark),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6, offset: const Offset(0, 2),
          )],
        ),
        child: Row(
          children: [
            ShopLogoWidget(
               logoURL: shop.logoUrl,
                initiales: shop.initiales,
                size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(shop.nom, style: TextStyle(
                      color: AppColors.textPrimaryFor(isDark),
                      fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.star, size: 11, color: Color(0xFFF5A623)),
                    const SizedBox(width: 2),
                    Text('${shop.rating.toStringAsFixed(1)} · ${shop.totalAvis} avis',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondaryFor(isDark))),
                  ]),
                ],
              ),
            ),
            // Badge Ouvert/Fermé, calculé côté modèle/provider selon
            // les horaires de la boutique.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: shop.isOpen
                    ? const Color(0xFFE8F5EE)
                    : const Color(0xFFFDEAEA),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(shop.isOpen ? 'Ouvert' : 'Fermé',
                  style: TextStyle(
                      color: shop.isOpen
                          ? const Color(0xFF1D9E75)
                          : const Color(0xFFE63946),
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Élément de la barre de navigation basse (icône + libellé), dont la
/// couleur change selon l'état [active] (ici, seul "Accueil" est
/// marqué actif en dur, puisque cet écran EST l'accueil).
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    this.active = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              color: active
                  ? const Color(0xFF0D2B5E)
                  : const Color(0xFF999999),
              size: 22),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: active
                      ? const Color(0xFF0D2B5E)
                      : const Color(0xFF999999),
                  fontWeight: active
                      ? FontWeight.bold
                      : FontWeight.normal)),
        ],
      ),
    );
  }
}
