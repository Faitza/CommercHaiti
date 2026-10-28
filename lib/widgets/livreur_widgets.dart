import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_colors.dart';
import '../models/order_model.dart';
import '../l10n/traduction.dart';

/// Lien WhatsApp vers un numéro haïtien, avec message prérempli. Ajoute
/// l'indicatif 509 quand le numéro n'a que 8 chiffres (wa.me l'exige).
Uri lienWhatsApp(String telephone, {String? message}) {
  var numero = telephone.replaceAll(RegExp(r'[^\d]'), '');
  if (numero.length == 8) numero = '509$numero';
  return Uri.https('wa.me', '/$numero',
      message == null ? null : {'text': message});
}

Future<void> ouvrirWhatsApp(BuildContext context, String telephone,
    {String? message}) async {
  try {
    final ok = await launchUrl(lienWhatsApp(telephone, message: message),
        mode: LaunchMode.externalApplication);
    if (ok) return;
  } catch (_) {}
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(traduire("Impossible d'ouvrir WhatsApp — vérifiez qu'il est installé")),
      backgroundColor: AppColors.red,
    ));
  }
}

/// Section « Livreur » du détail de commande (vendeur) : choisir le
/// livreur parmi « Mes livreurs », puis lui envoyer la commande par
/// WhatsApp (adresse, zone, téléphone du client, articles, montant).
class LivreurVendeurWidget extends StatefulWidget {
  final OrderModel order;
  const LivreurVendeurWidget({super.key, required this.order});

  @override
  State<LivreurVendeurWidget> createState() => _LivreurVendeurWidgetState();
}

class _LivreurVendeurWidgetState extends State<LivreurVendeurWidget> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _livreurs = [];
  late String? _livreurId = widget.order.livreurId;
  late String? _nom = widget.order.livreurNom;
  late String? _telephone = widget.order.livreurTelephone;
  bool _envoi = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final rows = await _supabase
          .from('livreurs')
          .select('id, nom, telephone')
          .eq('shop_id', widget.order.shopId)
          .eq('actif', true)
          .order('nom');
      if (mounted) setState(() => _livreurs = List<Map<String, dynamic>>.from(rows));
    } catch (_) {}
  }

  Future<void> _assigner(String? id) async {
    setState(() => _envoi = true);
    try {
      final row = await _supabase
          .from('orders')
          .update({'livreur_id': id})
          .eq('id', widget.order.id)
          .select('livreur_id, livreur_nom, livreur_telephone')
          .single();
      if (mounted) {
        setState(() {
          _livreurId = row['livreur_id'];
          _nom = row['livreur_nom'];
          _telephone = row['livreur_telephone'];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(traduire('Assignation impossible. Réessayez.')),
          backgroundColor: AppColors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  String _messageLivreur() {
    final o = widget.order;
    final articles = o.items
        .map((i) => '- ${i.quantite} × ${i.nom}')
        .join('\n');
    final paiement = o.modePaiement == 'moncash'
        ? (o.paiementStatut == 'confirme'
            ? traduire('Déjà payé (MonCash)')
            : traduire('MonCash — à vérifier avec le vendeur'))
        : traduire('À encaisser : {montant} HTG',
            {'montant': o.total.toStringAsFixed(0)});
    return '${traduire('Livraison CommercHaiti #{num}', {'num': o.id.substring(0, 6).toUpperCase()})}\n'
        '${traduire('Adresse : {adresse} ({zone})', {'adresse': traduire(o.adresseLivraison), 'zone': traduire(o.zone)})}\n'
        '${traduire('Client : {telephone}', {'telephone': o.telephoneClient})}\n'
        '${articles.isEmpty ? '' : '$articles\n'}'
        '$paiement';
  }

  @override
  Widget build(BuildContext context) {
    // Le livreur assigné peut avoir été mis en pause : on le garde dans
    // la liste pour que le menu affiche bien la valeur actuelle.
    final options = [..._livreurs];
    if (_livreurId != null && !options.any((l) => l['id'] == _livreurId)) {
      options.add({'id': _livreurId, 'nom': _nom ?? context.tr('Livreur'), 'telephone': _telephone});
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.delivery_dining, size: 18, color: AppColors.navy),
          const SizedBox(width: 6),
          Text(context.tr('Livreur'),
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 8),
        if (options.isEmpty)
          Text(context.tr('Ajoutez vos livreurs dans Paramètres → Mes livreurs.'),
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))
        else
          DropdownButtonFormField<String?>(
            initialValue: _livreurId,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            hint: Text(context.tr('Choisir un livreur')),
            items: [
              DropdownMenuItem<String?>(
                  value: null, child: Text(context.tr('Aucun livreur'))),
              for (final l in options)
                DropdownMenuItem<String?>(
                  value: l['id'] as String,
                  child: Text('${l['nom']} · ${l['telephone'] ?? ''}'),
                ),
            ],
            onChanged: _envoi ? null : _assigner,
          ),
        if (_telephone != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.whatsapp,
                  side: const BorderSide(color: AppColors.whatsapp)),
              icon: const Icon(Icons.send, size: 16),
              label: Text(context.tr('Envoyer la commande au livreur (WhatsApp)')),
              onPressed: () =>
                  ouvrirWhatsApp(context, _telephone!, message: _messageLivreur()),
            ),
          ),
        ],
      ],
    );
  }
}

/// Carte « Votre livreur » de l'écran de suivi (client).
class LivreurClientWidget extends StatelessWidget {
  final String nom;
  final String telephone;
  final bool isDark;
  const LivreurClientWidget(
      {super.key, required this.nom, required this.telephone, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        const CircleAvatar(
          backgroundColor: AppColors.lightBlue,
          child: Icon(Icons.delivery_dining, color: AppColors.navy),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('Votre livreur'),
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textSecondaryFor(isDark))),
              Text('$nom · $telephone',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryFor(isDark))),
            ],
          ),
        ),
        IconButton(
          tooltip: context.tr('Appeler'),
          icon: const Icon(Icons.call, color: AppColors.green),
          onPressed: () => launchUrl(Uri(scheme: 'tel', path: telephone)),
        ),
        IconButton(
          tooltip: 'WhatsApp',
          icon: const Icon(Icons.chat, color: AppColors.whatsapp),
          onPressed: () => ouvrirWhatsApp(context, telephone),
        ),
      ]),
    );
  }
}
