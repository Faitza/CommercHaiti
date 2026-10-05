import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_colors.dart';

/// Paiement MonCash avec confirmation manuelle (voir
/// supabase/migration_moncash.sql) : le client envoie l'argent au numéro
/// MonCash de la boutique, saisit le numéro de transaction, puis le
/// vendeur confirme qu'il l'a bien reçu.

/// Couleur MonCash (rouge Digicel), utilisée seulement pour l'icône.
const _moncashRouge = Color(0xFFD71920);

/// Montant formaté comme dans le reste de l'app : « 1250 HTG ».
String montantHtg(double total) => '${total.toStringAsFixed(0)} HTG';

/// Encadré « Envoyez X HTG au numéro … ».
class MoncashInstructions extends StatelessWidget {
  final String numero;
  final double total;
  const MoncashInstructions(
      {super.key, required this.numero, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lightRed,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(TextSpan(
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            children: [
              const TextSpan(text: '1. Envoyez '),
              TextSpan(
                  text: montantHtg(total),
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              const TextSpan(text: ' avec MonCash au '),
              TextSpan(
                  text: numero,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              const TextSpan(text: '.'),
            ],
          )),
          const SizedBox(height: 4),
          const Text(
            '2. Entrez ci-dessous le numéro de transaction reçu par SMS.',
            style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

/// Validation du numéro de transaction saisi par le client.
String? validerReferenceMoncash(String? v) {
  if (v == null || v.trim().length < 4) return 'Numéro de transaction requis';
  return null;
}

/// Section paiement de l'écran de suivi (client).
///
/// - MonCash en attente / confirmé / refusé : affiche l'état.
/// - Refusé, ou paiement à la livraison alors que la boutique accepte
///   MonCash : le client peut (re)saisir un numéro de transaction.
class MoncashSuiviWidget extends StatefulWidget {
  final String orderId;
  final String shopId;
  final String statut;
  final double total;
  final String modePaiement;
  final String? reference;
  final String? paiementStatut;
  final bool isDark;

  const MoncashSuiviWidget({
    super.key,
    required this.orderId,
    required this.shopId,
    required this.statut,
    required this.total,
    required this.modePaiement,
    required this.reference,
    required this.paiementStatut,
    required this.isDark,
  });

  @override
  State<MoncashSuiviWidget> createState() => _MoncashSuiviWidgetState();
}

class _MoncashSuiviWidgetState extends State<MoncashSuiviWidget> {
  final _refCtrl = TextEditingController();
  String? _numero;
  bool _formulaireOuvert = false;
  bool _envoi = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _chargerNumero();
  }

  @override
  void didUpdateWidget(covariant MoncashSuiviWidget old) {
    super.didUpdateWidget(old);
    if (_numero == null && old.shopId != widget.shopId) _chargerNumero();
  }

  @override
  void dispose() {
    _refCtrl.dispose();
    super.dispose();
  }

  Future<void> _chargerNumero() async {
    if (widget.shopId.isEmpty) return;
    try {
      final row = await Supabase.instance.client
          .from('shops')
          .select()
          .eq('id', widget.shopId)
          .maybeSingle();
      final numero = (row?['moncash_numero'] as String?)?.trim();
      if (mounted && numero != null && numero.isNotEmpty) {
        setState(() => _numero = numero);
      }
    } catch (_) {}
  }

  Future<void> _declarer() async {
    final erreur = validerReferenceMoncash(_refCtrl.text);
    if (erreur != null) {
      setState(() => _erreur = erreur);
      return;
    }
    setState(() {
      _envoi = true;
      _erreur = null;
    });
    try {
      await Supabase.instance.client.rpc('declarer_paiement_moncash', params: {
        'p_order_id': widget.orderId,
        'p_reference': _refCtrl.text.trim(),
      });
      if (mounted) {
        setState(() {
          _envoi = false;
          _formulaireOuvert = false;
          _refCtrl.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _envoi = false;
          _erreur = "Envoi impossible. Vérifiez votre connexion et réessayez.";
        });
      }
    }
  }

  Widget _etat(IconData icon, Color couleur, Color fond, String titre,
      String? detail) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: fond, borderRadius: BorderRadius.circular(12)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: couleur),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titre,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              if (detail != null)
                Text(detail,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _formulaire() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MoncashInstructions(numero: _numero!, total: widget.total),
        const SizedBox(height: 8),
        TextField(
          controller: _refCtrl,
          enabled: !_envoi,
          decoration: InputDecoration(
            hintText: 'Numéro de transaction MonCash',
            errorText: _erreur,
            filled: true,
            fillColor: AppColors.inputFill(widget.isDark),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            onPressed: _envoi ? null : _declarer,
            child: _envoi
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Envoyer le numéro de transaction'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final terminee =
        widget.statut == 'livree' || widget.statut == 'annulee';
    final ref = widget.reference;

    if (widget.modePaiement == 'moncash') {
      switch (widget.paiementStatut) {
        case 'confirme':
          return _etat(Icons.verified, AppColors.green, AppColors.lightGreen,
              'Paiement MonCash confirmé', ref != null ? 'Réf. $ref' : null);
        case 'refuse':
          return Column(children: [
            _etat(Icons.error_outline, AppColors.red, AppColors.lightRed,
                "Le vendeur n'a pas reçu ce paiement",
                'Réf. ${ref ?? '—'} — vérifiez le numéro de transaction.'),
            if (!terminee && _numero != null) ...[
              const SizedBox(height: 8),
              _formulaire(),
            ],
          ]);
        case 'en_attente':
          return _etat(Icons.hourglass_top, AppColors.amber,
              AppColors.lightAmber, 'Paiement MonCash envoyé',
              'Réf. ${ref ?? '—'} — en attente de confirmation du vendeur.');
      }
    }

    // Paiement à la livraison : proposer MonCash si la boutique l'accepte.
    if (terminee || _numero == null) return const SizedBox.shrink();
    if (!_formulaireOuvert) {
      return SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          onPressed: () => setState(() => _formulaireOuvert = true),
          icon: const Icon(Icons.phone_android, color: _moncashRouge, size: 18),
          label: const Text('Payer plutôt avec MonCash'),
        ),
      );
    }
    return _formulaire();
  }
}

/// Section paiement du détail de commande côté vendeur : montre le mode
/// de paiement et, pour MonCash, permet de confirmer la réception.
class MoncashVendeurWidget extends StatefulWidget {
  final String orderId;
  final String modePaiement;
  final String? reference;
  final String? paiementStatut;
  final double total;

  const MoncashVendeurWidget({
    super.key,
    required this.orderId,
    required this.modePaiement,
    required this.reference,
    required this.paiementStatut,
    required this.total,
  });

  @override
  State<MoncashVendeurWidget> createState() => _MoncashVendeurWidgetState();
}

class _MoncashVendeurWidgetState extends State<MoncashVendeurWidget> {
  late String? _statut = widget.paiementStatut;
  bool _envoi = false;

  Future<void> _repondre(bool recu) async {
    setState(() => _envoi = true);
    try {
      await Supabase.instance.client.rpc('confirmer_paiement_moncash',
          params: {'p_order_id': widget.orderId, 'p_recu': recu});
      if (mounted) setState(() => _statut = recu ? 'confirme' : 'refuse');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enregistrement impossible, réessayez.'),
          backgroundColor: AppColors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.modePaiement != 'moncash') {
      return const Row(children: [
        Icon(Icons.money, size: 16, color: AppColors.green),
        SizedBox(width: 6),
        Text('Paiement à la livraison', style: TextStyle(fontSize: 13)),
      ]);
    }

    final libelle = switch (_statut) {
      'confirme' => 'Paiement reçu ✔',
      'refuse' => 'Marqué « pas reçu » — le client doit corriger',
      _ => 'À vérifier dans votre MonCash',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.phone_android, size: 16, color: _moncashRouge),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
                'MonCash · ${montantHtg(widget.total)} · réf. ${widget.reference ?? '—'}',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 4),
        Text(libelle,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        if (_statut == 'en_attente') ...[
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: Colors.white),
                onPressed: _envoi ? null : () => _repondre(true),
                child: const Text('Paiement reçu'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.red,
                    side: const BorderSide(color: AppColors.red)),
                onPressed: _envoi ? null : () => _repondre(false),
                child: const Text('Pas reçu'),
              ),
            ),
          ]),
        ],
      ],
    );
  }
}
