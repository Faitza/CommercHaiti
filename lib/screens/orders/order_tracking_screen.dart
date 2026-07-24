import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/order_provider.dart';
import '../../widgets/order_status_badge.dart';
import '../../widgets/whatsapp_button_widget.dart';
import '../../widgets/receipt_buttons_widget.dart';

/// Order Tracking Screen — Claudimyr CASSIGNOL
/// Path : lib/screens/orders/order_tracking_screen.dart
///
/// Écran affiché juste après la création d'une commande (et accessible
/// depuis l'historique). Il montre en temps réel où en est la commande
/// (statut + timeline) grâce à un `StreamBuilder` branché directement sur
/// Supabase Realtime : dès que la ligne `orders` change côté serveur
/// (le vendeur accepte, prépare, livre...), l'UI se met à jour toute seule,
/// sans avoir besoin de rafraîchir la page ou de re-fetch manuellement.
class OrderTrackingScreen extends StatelessWidget {
  // Identifiant de la commande à suivre (clé primaire dans la table `orders`).
  final String orderId;
  // Numéro de téléphone du vendeur, transmis par l'écran précédent (via
  // `extra` du GoRouter) pour pouvoir afficher le bouton "Contacter le
  // vendeur" sans refaire une requête réseau ici.
  final String vendeurTelephone;

  const OrderTrackingScreen({
    super.key,
    required this.orderId,
    required this.vendeurTelephone,
  });

  // Liste statique des étapes possibles du cycle de vie d'une commande,
  // dans l'ordre chronologique attendu. Chaque étape porte : le code
  // `statut` tel qu'il est stocké en base, le `label` affiché à l'utilisateur
  // et l'icône associée. Cette liste sert à construire la timeline verticale
  // plus bas (on compare le statut courant de la commande à cette liste pour
  // savoir quelles étapes sont déjà "passées").
  static const List<Map<String, dynamic>> _etapes = [
    {'statut': 'nouvelle',    'label': 'En attente du vendeur', 'icon': Icons.access_time},
    {'statut': 'acceptee',    'label': 'Acceptée',              'icon': Icons.check_circle_outline},
    {'statut': 'preparation', 'label': 'En préparation',        'icon': Icons.inventory_2_outlined},
    {'statut': 'livraison',   'label': 'En livraison',          'icon': Icons.local_shipping_outlined},
    {'statut': 'livree',      'label': 'Livrée',                'icon': Icons.celebration_outlined},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      body: Column(
        children: [
          // TopBar
          Container(
            color: const Color(0xFF061A3A),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              bottom: 12, left: 4, right: 16,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white, size: 20),
                  // Important : on utilise context.go() et non context.push()
                  // ici. go() REMPLACE toute la pile de navigation par la
                  // route donnée, alors que push() empilerait une nouvelle
                  // page par-dessus l'écran actuel. On veut go() sur ce
                  // bouton "retour" pour éviter qu'un utilisateur puisse
                  // revenir en arrière jusqu'à l'écran de suivi d'une
                  // commande déjà passée (ce qui créait des piles de
                  // navigation incohérentes / des retours en arrière vers
                  // des écrans obsolètes — bug corrigé plus tôt dans le
                  // projet).
                  onPressed: () => context.go('/client/home'),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Suivi commande',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                    Text(
                      '#${orderId.length >= 6 ? orderId.substring(0, 6).toUpperCase() : orderId}',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Kontni Realtime
          // Contenu principal, mis à jour en temps réel.
          Expanded(
            child: StreamBuilder(
              // `.stream(primaryKey: ['id'])` ouvre un flux Supabase
              // Realtime sur la table `orders`, filtré avec `.eq('id',
              // orderId)` pour ne recevoir que les changements concernant
              // CETTE commande précise. `primaryKey: ['id']` est requis par
              // Supabase pour savoir identifier de façon unique chaque ligne
              // reçue dans le flux.
              stream: Supabase.instance.client
                  .from('orders')
                  .stream(primaryKey: ['id'])
                  .eq('id', orderId),
              builder: (context, snapshot) {
                // Valeurs par défaut tant que le flux n'a pas encore livré
                // de donnée (premier chargement).
                String statut = 'nouvelle';
                double total = 0;
                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  // Le flux renvoie une liste de lignes correspondant au
                  // filtre ; ici il ne peut y avoir qu'une seule commande
                  // avec cet id, donc on prend `.first`.
                  statut = snapshot.data!.first['statut'] ?? 'nouvelle';
                  total = (snapshot.data!.first['total'] ?? 0).toDouble();
                }

                // On retrouve l'index de l'étape courante dans `_etapes`
                // pour savoir jusqu'où colorer la timeline (toutes les
                // étapes dont l'index est <= indexActuel sont "passées").
                final indexActuel = _etapes
                    .indexWhere((e) => e['statut'] == statut);

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      // Statut principal
                      // Carte du haut : badge de statut (couleur/texte selon
                      // `statut`) + montant total si connu.
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            OrderStatusBadge(statut: statut),
                            const SizedBox(height: 8),
                            if (total > 0)
                              Text('${total.toStringAsFixed(0)} HTG',
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0D2B5E))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Timeline
                      // Carte affichant la timeline verticale : une ligne par
                      // étape de `_etapes`, avec un cercle (icône) relié par
                      // un petit trait vertical à l'étape suivante.
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          // On parcourt `_etapes` avec son index (`asMap()
                          // .entries`) car on a besoin de savoir la position
                          // de chaque étape pour la comparer à `indexActuel`.
                          children: _etapes.asMap().entries.map((entry) {
                            final i = entry.key;
                            final etape = entry.value;
                            // Étape déjà atteinte (colorée en bleu foncé).
                            final estPasse = i <= indexActuel;
                            // Étape en cours (texte en gras).
                            final estActuel = i == indexActuel;

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(children: [
                                  Container(
                                    width: 36, height: 36,
                                    decoration: BoxDecoration(
                                      color: estPasse
                                          ? const Color(0xFF0D2B5E)
                                          : const Color(0xFFF2F4F8),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: estPasse
                                            ? const Color(0xFF0D2B5E)
                                            : const Color(0xFFCCCCCC),
                                      ),
                                    ),
                                    child: Icon(
                                      etape['icon'] as IconData,
                                      size: 16,
                                      color: estPasse
                                          ? Colors.white
                                          : const Color(0xFFCCCCCC),
                                    ),
                                  ),
                                  if (i < _etapes.length - 1)
                                    Container(
                                      width: 2, height: 28,
                                      color: estPasse
                                          ? const Color(0xFF0D2B5E)
                                          : const Color(0xFFEEEEEE),
                                    ),
                                ]),
                                const SizedBox(width: 12),
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    etape['label'] as String,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: estActuel
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: estPasse
                                          ? const Color(0xFF0D2B5E)
                                          : const Color(0xFF999999),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Reçu PDF — BF-030
                      // Le bouton de génération/partage du reçu PDF n'est
                      // proposé que lorsque la commande est effectivement
                      // livrée (référence "BF-030" = ticket/exigence
                      // fonctionnelle du cahier des charges du projet).
                      if (statut == 'livree') ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ReceiptButtonsWidget(orderId: orderId),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Bouton WhatsApp
                      // Affiché seulement si on a reçu un numéro de vendeur
                      // valide (voir `vendeurTelephone`, résolu dans
                      // order_form_screen.dart via `get_vendor_telephone`).
                      if (vendeurTelephone.isNotEmpty)
                        WhatsAppButtonWidget(
                          telephone: vendeurTelephone,
                          label: 'Contacter le vendeur en urgence',
                        ),
                      const SizedBox(height: 10),

                      // Bouton Annuler
                      // L'annulation client n'est possible QUE si la
                      // commande est encore au statut 'nouvelle' (le
                      // vendeur ne l'a pas encore acceptée). Dès qu'elle
                      // avance dans le cycle (acceptee/preparation/...),
                      // on affiche un message d'information à la place
                      // (bloc `else if` ci-dessous) au lieu du bouton.
                      if (statut == 'nouvelle')
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: Color(0xFFE63946)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.cancel_outlined,
                                color: Color(0xFFE63946), size: 16),
                            label: const Text('Annuler la commande',
                                style: TextStyle(
                                    color: Color(0xFFE63946))),
                            onPressed: () =>
                                _confirmerAnnulation(context),
                          ),
                        )
                      // Sinon, tant que la commande n'est ni livrée ni déjà
                      // annulée, on explique pourquoi l'annulation n'est
                      // plus disponible.
                      else if (statut != 'livree' && statut != 'annulee')
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F4F8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(children: [
                            const Icon(Icons.info_outline,
                                size: 14, color: Color(0xFF999999)),
                            const SizedBox(width: 8),
                            const Text(
                              'Annulation impossible — commande déjà acceptée',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF999999)),
                            ),
                          ]),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Affiche une boîte de dialogue de confirmation avant d'annuler la
  // commande, pour éviter les annulations accidentelles (clic malencontreux).
  void _confirmerAnnulation(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Annuler la commande ?'),
        content: const Text(
            'Cette action est irréversible. Le vendeur sera informé.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Non, garder'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE63946)),
            onPressed: () async {
              // On ferme d'abord la boîte de dialogue...
              Navigator.pop(context);
              // ...puis on déclenche l'annulation côté serveur via le
              // provider (opération asynchrone : appel réseau Supabase).
              final ok = await context
                  .read<OrderProvider>()
                  .cancelOrder(orderId);
              // `context.mounted` est vérifié après le `await` car ce
              // widget aurait pu être démonté pendant l'attente (par
              // exemple si l'utilisateur a navigué ailleurs) ; utiliser un
              // BuildContext démonté provoquerait une erreur/lint
              // "use_build_context_synchronously". Si l'annulation a
              // réussi, on revient à l'accueil avec go() (remplace la
              // pile — on ne veut pas pouvoir "revenir" sur le suivi d'une
              // commande qui vient d'être annulée).
              if (ok && context.mounted) context.go('/client/home');
            },
            child: const Text('Oui, annuler',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}