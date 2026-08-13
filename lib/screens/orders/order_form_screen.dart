import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/order_provider.dart';
import '../../models/order_model.dart';
import '../../providers/theme_provider.dart';
import '../../constants/app_colors.dart';

/// Order Form Screen — Claudimyr CASSIGNOL
/// Path : lib/screens/orders/order_form_screen.dart
///
/// Deuxième et dernière étape du tunnel de commande (après le panier) :
/// l'utilisateur saisit son adresse/zone de livraison, confirme son
/// numéro de téléphone, choisit un mode de paiement et peut ajouter une
/// note pour le vendeur. À la validation, la commande est envoyée en base
/// via une fonction Postgres transactionnelle (RPC `create_order_atomic`,
/// voir `_valider()` et OrderProvider.createOrder / DatabaseService) qui
/// traite TOUS les articles du panier en une seule transaction atomique
/// (commande + une ligne order_items par article + décrément du stock de
/// chaque produit) — nécessite `supabase/functions.sql` à jour (version
/// avec paramètre `p_items` en jsonb).
class OrderFormScreen extends StatefulWidget {
  const OrderFormScreen({super.key});
  @override
  State<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends State<OrderFormScreen> {
  // Clé du formulaire, utilisée pour déclencher la validation de tous les
  // TextFormField d'un coup (`_formKey.currentState!.validate()`).
  final _formKey = GlobalKey<FormState>();
  // Contrôleurs de texte : un par champ de saisie du formulaire. Ils sont
  // libérés (`dispose()`) en bas du fichier pour éviter les fuites mémoire.
  final _adresseCtrl = TextEditingController();
  final _telephoneCtrl = TextEditingController();
  final _confirmTelCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  // Zone de livraison choisie parmi `_zones` (chaîne vide = rien de
  // sélectionné, ce qui bloque la validation dans `_valider()`).
  String _zone = '';
  // Mode de paiement choisi. Seul 'livraison' (paiement à la livraison,
  // COD) est réellement sélectionnable actuellement : voir la section
  // "Paiement" plus bas dans `build()`, où l'option MonCash est affichée
  // mais désactivée (`onChanged: null`) car ce mode n'est pas encore
  // implémenté côté projet.
  String _modePaiement = 'livraison';
  // Bascule à `true` pendant l'appel réseau de création de commande, pour
  // désactiver le bouton "Confirmer" et afficher un indicateur de
  // chargement (évite les doubles soumissions).
  bool _isLoading = false;

  // Liste fixe des zones de livraison desservies (zone géographique des
  // Cayes et environs, cohérent avec le périmètre du projet ITAC).
  final List<String> _zones = [
    'Cayes Centre', 'Cayes Nord', 'Cayes Sud',
    'Torbeck', 'Saint-Jean', 'Camp-Perrin',
  ];

  @override
  void initState() {
    super.initState();
    // Pré-remplit le champ téléphone avec celui déjà enregistré sur le
    // profil du client, pour lui éviter de le retaper (mais il reste
    // modifiable, voir le texte d'aide affiché sous le champ dans build()).
    final auth = context.read<AuthProvider>();
    _telephoneCtrl.text = auth.currentUser?.telephone ?? '';
  }

  // Validateur du champ téléphone : format haïtien, 8 chiffres une fois
  // l'indicatif "+509" (s'il est saisi) et toute mise en forme retirés.
  String? _valTel(String? v) {
    if (v == null || v.trim().isEmpty) return 'Requis';
    var chiffres = v.replaceAll(RegExp(r'[^\d]'), '');
    if (chiffres.length == 11 && chiffres.startsWith('509')) {
      chiffres = chiffres.substring(3);
    }
    if (chiffres.length != 8) return 'Numéro invalide (8 chiffres attendus)';
    if (!RegExp(r'^[2-9]').hasMatch(chiffres)) return 'Numéro invalide';
    return null;
  }

  // Validateur du champ "confirmer le numéro" : on compare uniquement les
  // chiffres des deux champs (en ignorant la mise en forme) pour vérifier
  // que le client a bien retapé le même numéro — une double saisie destinée
  // à réduire le risque d'erreur de livraison liée à une faute de frappe.
  String? _valConfirm(String? v) {
    if (v == null || v.isEmpty) return 'Requis';
    final t1 = _telephoneCtrl.text.replaceAll(RegExp(r'[^\d]'), '');
    final t2 = v.replaceAll(RegExp(r'[^\d]'), '');
    if (t1 != t2) return 'Les numéros ne correspondent pas';
    return null;
  }

  // Point d'entrée appelé quand l'utilisateur appuie sur "Confirmer la
  // commande". Valide le formulaire, résout les infos du vendeur, puis
  // délègue la création de la commande au OrderProvider (qui appelle
  // lui-même la RPC Supabase `create_order_atomic`).
  Future<void> _valider() async {
    // 1) Validation classique des champs texte (adresse, téléphones...) via
    // les validateurs attachés à chaque TextFormField.
    if (!_formKey.currentState!.validate()) return;
    // 2) La zone de livraison n'est pas un TextFormField mais une sélection
    // par "chips" (Wrap de GestureDetector plus bas) : on la valide donc
    // manuellement ici, hors du mécanisme de Form.
    if (_zone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Sélectionnez une zone de livraison'),
        backgroundColor: Color(0xFFE63946),
      ));
      return;
    }
    // Active l'état de chargement (désactive le bouton, affiche un spinner).
    setState(() => _isLoading = true);

    final auth = context.read<AuthProvider>();
    final cart = context.read<CartProvider>();
    final orderProvider = context.read<OrderProvider>();

    // Garde-fou : si le panier est vide (ne devrait normalement pas arriver
    // puisqu'on ne peut accéder à cet écran qu'avec un panier non vide),
    // on abandonne silencieusement. Note : dans ce cas précis, `_isLoading`
    // reste à `true` car il n'est pas remis à `false` ici — cas limite
    // qui ne devrait pas se produire en pratique.
    if (cart.items.isEmpty) return;

    // Le vendeur/la boutique de la commande sont résolus à partir du
    // PREMIER article : le panier ne gère qu'une seule boutique à la fois
    // dans ce projet (ajouter un produit d'une autre boutique n'est pas
    // empêché côté UI, mais n'a jamais de sens ici puisqu'une commande
    // n'a qu'un seul vendeur/livraison). `item` sert uniquement à ça —
    // TOUS les articles du panier sont bien envoyés au serveur (voir
    // `items` construit plus bas), ce n'était pas le cas avant ce
    // correctif (seul `cart.items.first` était réellement commandé).
    final item = cart.items.first;

    // Résout le vendeur (proprietaire_id + téléphone) de la boutique du produit
    // On a besoin de deux informations sur le vendeur avant de pouvoir créer
    // la commande : son identifiant utilisateur (sellerId, requis par la
    // RPC create_order_atomic) et son numéro de téléphone (pour permettre
    // au client de le contacter via WhatsApp depuis l'écran de suivi).
    String sellerId;
    String vendeurTelephone = '';
    try {
      // Étape A : on part de l'id du produit du panier -> shopId -> on va
      // chercher dans la table `shops` le `proprietaire_id`, c'est-à-dire
      // l'id de l'utilisateur (vendeur) propriétaire de cette boutique.
      // `.single()` s'attend à exactement une ligne (sinon lève une
      // exception, capturée ci-dessous par le catch).
      final shopRow = await Supabase.instance.client
          .from('shops')
          .select('proprietaire_id')
          .eq('id', item.product.shopId)
          .single();
      sellerId = shopRow['proprietaire_id'] as String;
      // Étape B : on appelle la fonction Postgres `get_vendor_telephone`
      // via RPC pour récupérer le téléphone du vendeur. On ne peut PAS
      // faire un simple `select telephone from users where id = sellerId`
      // depuis le client, car la table `users` est protégée par une
      // politique RLS (Row Level Security) qui n'autorise en lecture que
      // `auth.uid() = id` (chacun ne peut lire que sa propre ligne). Pour
      // permettre malgré tout au client de connaître le téléphone du
      // vendeur (nécessaire pour le contact WhatsApp), `get_vendor_telephone`
      // est déclarée côté base en `SECURITY DEFINER` : elle s'exécute avec
      // les droits de son propriétaire (généralement un rôle privilégié)
      // et contourne donc la RLS de façon contrôlée, en ne renvoyant QUE le
      // numéro de téléphone (et rien d'autre du profil du vendeur) — un
      // moyen sûr d'exposer une donnée précise sans ouvrir toute la table.
      final result = await Supabase.instance.client
          .rpc('get_vendor_telephone', params: {'p_user_id': sellerId});
      vendeurTelephone = result as String? ?? '';
    } catch (e) {
      // Si l'une des deux requêtes échoue (boutique supprimée, erreur
      // réseau, etc.), on arrête le processus proprement et on informe
      // l'utilisateur plutôt que d'essayer de créer une commande avec des
      // informations vendeur incomplètes/incorrectes.
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Boutique introuvable — réessayez'),
          backgroundColor: Color(0xFFE63946),
        ));
      }
      return;
    }

    // Construit l'objet OrderModel avec toutes les infos de livraison
    // saisies dans le formulaire. `items: []` reste vide ici (l'OrderModel
    // en mémoire ne sert qu'à transporter les infos de livraison) : les
    // vrais articles sont transmis séparément à `orderProvider.createOrder`
    // via `items` ci-dessous, et c'est la fonction RPC côté serveur qui
    // crée les lignes `order_items` correspondantes. `total:
    // cart.totalAvecPromo` correspond bien à la somme de TOUS les articles
    // envoyés, plus de décalage entre le total affiché et ce qui est
    // réellement enregistré.
    final order = OrderModel(
      id: '', clientId: auth.currentUser!.id,
      shopId: item.product.shopId, sellerId: sellerId,
      items: [], total: cart.totalAvecPromo,
      statut: 'nouvelle',
      adresseLivraison: _adresseCtrl.text.trim(),
      zone: _zone,
      telephoneClient: _telephoneCtrl.text.trim(),
      noteVendeur: _noteCtrl.text.isEmpty ? null : _noteCtrl.text.trim(),
      createdAt: DateTime.now(),
    );

    // Un élément par article du panier — c'est cette liste complète (et
    // non plus un seul produit) qui est envoyée à la RPC
    // `create_order_atomic`, qui décrémente le stock et crée une ligne
    // `order_items` pour CHACUN.
    final items = cart.items.map((i) => {
          'product_id': i.product.id,
          'quantite': i.quantite,
          'nom': i.product.nom,
          'prix': i.product.prixAffiche,
          'couleur': i.couleur,
          'taille': i.taille,
        }).toList();

    // Délègue la création au provider, qui appelle en interne
    // DatabaseService -> Supabase RPC 'create_order_atomic'. C'est une
    // fonction Postgres transactionnelle : elle crée la commande ET une
    // ligne d'article par produit ET décrémente le stock de CHAQUE produit
    // en une seule transaction atomique côté base, pour éviter les
    // incohérences (ex. commande créée mais stock non décrémenté si l'app
    // plante entre les deux opérations). Si le stock d'UN SEUL article est
    // insuffisant, toute la RPC échoue (rien n'est décrémenté) et
    // orderProvider expose un message d'erreur adapté.
    final orderId = await orderProvider.createOrder(order: order, items: items);

    setState(() => _isLoading = false);

    if (orderId != null) {
      // Commande créée avec succès (tous les articles ont bien été
      // enregistrés et leur stock décrémenté) : on vide le panier puis on
      // navigue vers l'écran de suivi.
      cart.clear();
      // `mounted` est vérifié après les `await` précédents (résolution
      // vendeur + createOrder) car cet écran aurait pu être démonté entre
      // temps (par ex. si l'utilisateur a quitté l'app) ; utiliser
      // `context` après un `await` sans ce contrôle déclencherait le lint
      // "use_build_context_synchronously" et risquerait une erreur runtime.
      if (mounted) {
        // go() : on remplace la pile de navigation par l'écran de suivi.
        // On ne veut surtout PAS que l'utilisateur puisse appuyer sur
        // "retour" pour revenir sur ce formulaire de commande une fois la
        // commande passée (il ne doit pas pouvoir la re-soumettre). C'est
        // précisément la distinction go() vs push() qui avait causé des
        // bugs de navigation plus tôt dans le projet lorsqu'elle n'était
        // pas respectée à cet endroit.
        context.go('/order-tracking',
            extra: {
              'orderId': orderId,
              'vendeurTelephone': vendeurTelephone,
            });
      }
    } else if (mounted) {
      // Échec de la création (ex. stock insuffisant) : on affiche le
      // message d'erreur exposé par le provider.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(orderProvider.errorMessage ?? 'Erreur commande'),
        backgroundColor: const Color(0xFFE63946),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    // `watch` : nécessaire car le récapitulatif de commande affiché plus
    // bas doit se mettre à jour si le contenu du panier change pendant que
    // ce formulaire est ouvert.
    final cart = context.watch<CartProvider>();
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(isDark),
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
                  // go() ramène explicitement vers '/cart' en remplaçant la
                  // pile de navigation, plutôt que push()/pop() qui
                  // dépendrait de l'historique de navigation réel. C'est
                  // volontaire : on veut toujours revenir au panier depuis
                  // ce formulaire, quel que soit le chemin par lequel on y
                  // est arrivé.
                  onPressed: () => context.go('/cart'),
                ),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Détails de livraison',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                    Text('Étape 2 sur 2',
                        style: TextStyle(
                            color: Colors.white54, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Adresse
                    // Carte "Adresse de livraison" : champ texte libre pour
                    // l'adresse précise, plus une sélection de zone parmi
                    // une liste fixe de quartiers desservis (`_zones`).
                    _sectionCard(isDark, children: [
                      _label(Icons.location_on_outlined, 'Adresse de livraison', isDark),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _adresseCtrl,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Adresse requise';
                          if (v.trim().length < 5) return 'Adresse trop courte';
                          if (!RegExp(r'[A-Za-zÀ-ÿ]').hasMatch(v)) {
                            return 'L\'adresse ne peut pas être uniquement des chiffres';
                          }
                          return null;
                        },
                        decoration: _deco('Rue Borno, Les Cayes', isDark),
                      ),
                      const SizedBox(height: 14),
                      _label(Icons.map_outlined, 'Zone de livraison', isDark),
                      const SizedBox(height: 8),
                      // "Chips" cliquables représentant chaque zone
                      // possible ; la zone sélectionnée est mise en
                      // surbrillance (fond bleu foncé). Ce n'est pas un
                      // champ de Form classique, d'où la validation
                      // manuelle faite dans `_valider()`.
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: _zones.map((z) {
                          final sel = _zone == z;
                          return GestureDetector(
                            onTap: () => setState(() => _zone = z),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: sel
                                    ? const Color(0xFF0D2B5E)
                                    : AppColors.surface(isDark),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: sel
                                      ? const Color(0xFF0D2B5E)
                                      : AppColors.borderColor(isDark),
                                ),
                              ),
                              child: Text(z,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: sel
                                          ? Colors.white
                                          : AppColors.textSecondaryFor(isDark),
                                      fontWeight: sel
                                          ? FontWeight.bold
                                          : FontWeight.normal)),
                            ),
                          );
                        }).toList(),
                      ),
                    ]),
                    const SizedBox(height: 12),

                    // Téléphone
                    // Carte "Téléphone" : demande le numéro deux fois
                    // (saisie + confirmation) pour limiter le risque
                    // d'erreur de contact lors de la livraison.
                    _sectionCard(isDark, children: [
                      _label(Icons.phone_outlined, 'Numéro de téléphone', isDark),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _telephoneCtrl,
                        validator: _valTel,
                        keyboardType: TextInputType.phone,
                        decoration: _deco('+509 XXXX XXXX', isDark),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Pré-rempli depuis votre profil. Modifiable.',
                        style: TextStyle(
                            fontSize: 10, color: AppColors.textSecondaryFor(isDark)),
                      ),
                      const SizedBox(height: 12),
                      _label(Icons.phone_outlined, 'Confirmer le numéro', isDark),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _confirmTelCtrl,
                        validator: _valConfirm,
                        keyboardType: TextInputType.phone,
                        decoration: _deco('Ressaisir le numéro', isDark),
                      ),
                    ]),
                    const SizedBox(height: 12),

                    // Paiement — jan maket la (COD sèlman, MonCash pa la ankò)
                    // Section "Mode de paiement". Actuellement, un seul
                    // mode est réellement utilisable : le paiement à la
                    // livraison (COD, "Cash On Delivery" — le client paie
                    // en espèces au livreur). L'option MonCash (portefeuille
                    // mobile très utilisé en Haïti) est affichée pour
                    // montrer que le produit est prévu pour l'accueillir,
                    // mais elle est désactivée (`onChanged: null` rend le
                    // RadioListTile non cliquable, et son texte est grisé)
                    // car son intégration (paiement en ligne réel) n'est
                    // pas encore implémentée dans ce projet étudiant.
                    _sectionCard(isDark, children: [
                      _label(Icons.payments_outlined, 'PAIEMENT', isDark),
                      const SizedBox(height: 4),
                      // Option active : paiement à la livraison. C'est la
                      // seule valeur que `_modePaiement` peut réellement
                      // prendre pour l'instant (sa valeur par défaut).
                      RadioListTile<String>(
                        value: 'livraison',
                        groupValue: _modePaiement,
                        onChanged: (v) =>
                            setState(() => _modePaiement = v ?? 'livraison'),
                        activeColor: const Color(0xFF0D2B5E),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Row(children: const [
                          Icon(Icons.money, size: 16, color: Color(0xFF1D9E75)),
                          SizedBox(width: 6),
                          Text('Paiement à la livraison',
                              style: TextStyle(fontSize: 14)),
                        ]),
                      ),
                      // Option MonCash désactivée : `onChanged: null`
                      // empêche toute sélection (le bouton radio ne réagit
                      // pas au tap), et les couleurs grisées communiquent
                      // visuellement que l'option n'est "pas encore
                      // disponible" (voir le label "Bientôt dispo").
                      RadioListTile<String>(
                        value: 'moncash',
                        groupValue: _modePaiement,
                        onChanged: null,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Row(children: [
                          Icon(Icons.phone_android,
                              size: 16, color: AppColors.textSecondaryFor(isDark)),
                          const SizedBox(width: 6),
                          Text('MonCash — Bientôt dispo',
                              style: TextStyle(
                                  fontSize: 14, color: AppColors.textSecondaryFor(isDark))),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 12),

                    // Note vendeur
                    // Champ libre et optionnel (limité à 200 caractères)
                    // pour transmettre une instruction spéciale au vendeur
                    // (ex. horaire de livraison préféré).
                    _sectionCard(isDark, children: [
                      _label(Icons.note_outlined, 'Note pour le vendeur (optionnel)', isDark),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _noteCtrl,
                        maxLines: 2,
                        maxLength: 200,
                        decoration: _deco('Ex: Livrer après 17h...', isDark),
                      ),
                    ]),
                    const SizedBox(height: 12),

                    // Récap
                    // Résumé visuel du panier : liste tous les articles
                    // (`cart.items`), leur quantité et sous-total, puis le
                    // total général (avec économies éventuelles). ATTENTION
                    // (voir la note en tête de fichier) : ce récapitulatif
                    // reflète fidèlement TOUT le panier, mais au moment de
                    // la validation (`_valider()`), seul le premier article
                    // du panier est réellement transmis au serveur pour
                    // créer la commande. Ce récap peut donc, dans le cas
                    // d'un panier multi-articles, laisser croire à
                    // l'utilisateur que tout sera commandé alors que seul
                    // le premier article le sera.
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface(isDark),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(children: [
                        ...cart.items.map((item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(children: [
                            Expanded(child: Text(item.product.nom,
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis)),
                            Text('x${item.quantite}',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.textSecondaryFor(isDark))),
                            const SizedBox(width: 12),
                            Text('${item.sousTotal.toStringAsFixed(0)} HTG',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 12)),
                          ]),
                        )),
                        const Divider(height: 16),
                        if (cart.hasPromo)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Économies',
                                    style: TextStyle(
                                        color: Color(0xFF1D9E75), fontSize: 13)),
                                Text('-${cart.economies.toStringAsFixed(0)} HTG',
                                    style: const TextStyle(
                                        color: Color(0xFF1D9E75),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                              ],
                            ),
                          ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('${cart.totalAvecPromo.toStringAsFixed(0)} HTG',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.accentFor(isDark))),
                          ],
                        ),
                      ]),
                    ),
                    const SizedBox(height: 16),

                    // Bouton de soumission du formulaire. Désactivé
                    // (`onPressed: null`) pendant le chargement pour éviter
                    // les doubles clics/doubles commandes ; son contenu
                    // (icône + texte) change aussi pour donner un retour
                    // visuel clair ("Traitement…" avec spinner).
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
                        icon: _isLoading
                            ? const SizedBox(width: 16, height: 16,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.check_circle_outline, size: 18),
                        label: Text(
                          _isLoading ? 'Traitement…' : 'Confirmer la commande',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        onPressed: _isLoading ? null : _valider,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Petit helper réutilisable : construit une "carte" blanche arrondie
  // contenant un groupe de champs liés (adresse, téléphone, paiement...).
  // Évite de répéter la même décoration (couleur, arrondi, padding) à
  // chaque section du formulaire.
  Widget _sectionCard(bool isDark, {required List<Widget> children}) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surface(isDark),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );

  // Petit helper : construit un libellé de section avec une icône, utilisé
  // en tête de chaque `_sectionCard`.
  Widget _label(IconData icon, String t, bool isDark) => Row(children: [
    Icon(icon, size: 14, color: AppColors.accentFor(isDark)),
    const SizedBox(width: 6),
    Text(t, style: TextStyle(
        fontSize: 13, fontWeight: FontWeight.w600,
        color: AppColors.textPrimaryFor(isDark))),
  ]);

  // Petit helper : décoration commune (fond gris clair, bordures arrondies,
  // style de bordure au focus/erreur) appliquée à tous les TextFormField du
  // formulaire, pour garder une apparence homogène.
  InputDecoration _deco(String hint, bool isDark) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: AppColors.textSecondaryFor(isDark), fontSize: 13),
    filled: true,
    fillColor: AppColors.inputFill(isDark),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
            color: Color(0xFF0D2B5E), width: 1.5)),
    errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE63946))),
    contentPadding: const EdgeInsets.symmetric(
        horizontal: 14, vertical: 12),
  );

  // Libère les TextEditingController quand l'écran est détruit, comme
  // recommandé par Flutter, pour éviter les fuites mémoire.
  @override
  void dispose() {
    _adresseCtrl.dispose();
    _telephoneCtrl.dispose();
    _confirmTelCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }
}