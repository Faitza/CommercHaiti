import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/order_provider.dart';
import '../../models/order_model.dart';

/// Order Form Screen — Claudimyr CASSIGNOL
/// Path : lib/screens/orders/order_form_screen.dart
///
/// Deuxième et dernière étape du tunnel de commande (après le panier) :
/// l'utilisateur saisit son adresse/zone de livraison, confirme son
/// numéro de téléphone, choisit un mode de paiement et peut ajouter une
/// note pour le vendeur. À la validation, la commande est envoyée en base
/// via une fonction Postgres transactionnelle (RPC `create_order_atomic`,
/// voir `_valider()` et OrderProvider.createOrder / DatabaseService).
///
/// ⚠️ LIMITATION IMPORTANTE À CONNAÎTRE (pour la soutenance) : même si le
/// récapitulatif affiché plus bas dans `build()` additionne TOUS les
/// articles du panier (`cart.items.map(...)` et `cart.totalAvecPromo`),
/// la commande réellement envoyée au serveur ne contient qu'UN SEUL
/// article : `cart.items.first` (voir `_valider()`). Le panier peut
/// contenir plusieurs produits/boutiques différents, mais
/// `create_order_atomic` ne sait créer qu'une commande pour un seul
/// article à la fois. C'est une limitation connue de l'implémentation
/// actuelle (pas un bug de calcul du total affiché : le total affiché est
/// correct, mais tout ce qui n'est pas le premier article du panier n'est
/// tout simplement pas transmis au serveur lors de la commande).
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

    // ⚠️ LIMITATION CONNUE : on ne prend QUE le premier article du panier
    // (`cart.items.first`) pour construire la commande envoyée au serveur,
    // même si le panier contient plusieurs articles (potentiellement de
    // boutiques différentes). Le récapitulatif visuel plus bas (dans
    // build()) affiche pourtant bien tous les articles et leur total —
    // cet écart entre "ce qui est montré" et "ce qui est réellement
    // envoyé" est une limitation actuelle du projet à garder en tête, pas
    // un choix voulu de l'UX.
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
    // saisies dans le formulaire. Notez que `items: []` est laissé vide ici
    // (les vrais détails de l'article — produit/quantité/prix/variantes —
    // sont transmis séparément à `orderProvider.createOrder` ci-dessous et
    // c'est la fonction RPC côté serveur qui se charge de créer la ligne
    // dans `order_items`). `total: cart.totalAvecPromo` utilise bien le
    // total de TOUT le panier (voir la remarque sur la limitation en tête
    // de fichier : le total affiché/enregistré peut donc représenter plus
    // que ce qui est effectivement commandé côté `order_items`).
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

    // Délègue la création au provider, qui appelle en interne
    // DatabaseService -> Supabase RPC 'create_order_atomic'. C'est une
    // fonction Postgres transactionnelle : elle crée la commande ET la
    // ligne d'article ET décrémente le stock du produit en une seule
    // transaction atomique côté base, pour éviter les incohérences
    // (ex. commande créée mais stock non décrémenté si l'app plante entre
    // les deux opérations). Si le stock est insuffisant, la RPC échoue et
    // orderProvider expose un message d'erreur adapté.
    final orderId = await orderProvider.createOrder(
      order: order, productId: item.product.id,
      quantite: item.quantite, nomProduit: item.product.nom,
      prixProduit: item.product.prixAffiche,
      couleur: item.couleur, taille: item.taille,
    );

    setState(() => _isLoading = false);

    if (orderId != null) {
      // Commande créée avec succès : on vide le panier (le seul article
      // effectivement commandé — et donc, avec la limitation décrite plus
      // haut, potentiellement d'autres articles jamais commandés — sont
      // tous retirés du panier ici) puis on navigue vers l'écran de suivi.
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
                    _sectionCard(children: [
                      _label(Icons.location_on_outlined, 'Adresse de livraison'),
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
                        decoration: _deco('Rue Borno, Les Cayes'),
                      ),
                      const SizedBox(height: 14),
                      _label(Icons.map_outlined, 'Zone de livraison'),
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
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: sel
                                      ? const Color(0xFF0D2B5E)
                                      : const Color(0xFFDDDDDD),
                                ),
                              ),
                              child: Text(z,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: sel
                                          ? Colors.white
                                          : const Color(0xFF444444),
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
                    _sectionCard(children: [
                      _label(Icons.phone_outlined, 'Numéro de téléphone'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _telephoneCtrl,
                        validator: _valTel,
                        keyboardType: TextInputType.phone,
                        decoration: _deco('+509 XXXX XXXX'),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Pré-rempli depuis votre profil. Modifiable.',
                        style: TextStyle(
                            fontSize: 10, color: Color(0xFF999999)),
                      ),
                      const SizedBox(height: 12),
                      _label(Icons.phone_outlined, 'Confirmer le numéro'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _confirmTelCtrl,
                        validator: _valConfirm,
                        keyboardType: TextInputType.phone,
                        decoration: _deco('Ressaisir le numéro'),
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
                    _sectionCard(children: [
                      _label(Icons.payments_outlined, 'PAIEMENT'),
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
                        title: Row(children: const [
                          Icon(Icons.phone_android,
                              size: 16, color: Color(0xFFAAAAAA)),
                          SizedBox(width: 6),
                          Text('MonCash — Bientôt dispo',
                              style: TextStyle(
                                  fontSize: 14, color: Color(0xFFAAAAAA))),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 12),

                    // Note vendeur
                    // Champ libre et optionnel (limité à 200 caractères)
                    // pour transmettre une instruction spéciale au vendeur
                    // (ex. horaire de livraison préféré).
                    _sectionCard(children: [
                      _label(Icons.note_outlined, 'Note pour le vendeur (optionnel)'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _noteCtrl,
                        maxLines: 2,
                        maxLength: 200,
                        decoration: _deco('Ex: Livrer après 17h...'),
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
                        color: Colors.white,
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
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF666666))),
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
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0D2B5E))),
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
  Widget _sectionCard({required List<Widget> children}) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );

  // Petit helper : construit un libellé de section avec une icône, utilisé
  // en tête de chaque `_sectionCard`.
  Widget _label(IconData icon, String t) => Row(children: [
    Icon(icon, size: 14, color: const Color(0xFF0D2B5E)),
    const SizedBox(width: 6),
    Text(t, style: const TextStyle(
        fontSize: 13, fontWeight: FontWeight.w600,
        color: Color(0xFF1A1F36))),
  ]);

  // Petit helper : décoration commune (fond gris clair, bordures arrondies,
  // style de bordure au focus/erreur) appliquée à tous les TextFormField du
  // formulaire, pour garder une apparence homogène.
  InputDecoration _deco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 13),
    filled: true,
    fillColor: const Color(0xFFF5F5F5),
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