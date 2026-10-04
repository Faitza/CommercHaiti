import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_colors.dart';
import '../services/storage_service.dart';

/// Section « Un problème avec cette commande ? » de l'écran de suivi.
///
/// - Pas de litige : bouton « Signaler un problème » (dès que la commande
///   a été acceptée ; avant, le client peut simplement l'annuler).
/// - Litige ouvert : rappel du motif + message « l'équipe CommercHaiti
///   examine votre signalement ».
/// - Litige résolu : la décision de l'admin.
///
/// Le litige est ouvert par la fonction serveur `ouvrir_litige` (voir
/// supabase/migration_litige_client.sql) puis traité dans l'admin web.
class LitigeSectionWidget extends StatelessWidget {
  final String orderId;
  final String statut;
  final String? litigeStatut;
  final String? litigeMotif;
  final String? litigeResolution;
  final bool isDark;

  const LitigeSectionWidget({
    super.key,
    required this.orderId,
    required this.statut,
    required this.litigeStatut,
    required this.litigeMotif,
    required this.litigeResolution,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (litigeStatut == 'ouvert' || litigeStatut == 'resolu') {
      final resolu = litigeStatut == 'resolu';
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: resolu ? AppColors.lightGreen : AppColors.lightAmber,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(resolu ? Icons.verified_outlined : Icons.report_outlined,
                  size: 18,
                  color: resolu ? AppColors.green : AppColors.amber),
              const SizedBox(width: 8),
              Text(resolu ? 'Problème traité' : 'Problème signalé',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
            ]),
            const SizedBox(height: 6),
            if (litigeMotif != null && litigeMotif!.isNotEmpty)
              Text(litigeMotif!,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Text(
              resolu
                  ? 'Décision : ${litigeResolution ?? '—'}'
                  : "L'équipe CommercHaiti examine votre signalement et "
                      'vous contactera.',
              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
            ),
          ],
        ),
      );
    }

    // Pas encore acceptée : le client peut annuler (bouton plus haut).
    if (statut == 'nouvelle') return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      height: 46,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.textSecondaryFor(isDark)),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        icon: Icon(Icons.report_problem_outlined,
            color: AppColors.textPrimaryFor(isDark), size: 16),
        label: Text('Signaler un problème',
            style: TextStyle(color: AppColors.textPrimaryFor(isDark))),
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: AppColors.surface(isDark),
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (_) => _LitigeForm(orderId: orderId, isDark: isDark),
        ),
      ),
    );
  }
}

class _LitigeForm extends StatefulWidget {
  final String orderId;
  final bool isDark;
  const _LitigeForm({required this.orderId, required this.isDark});

  @override
  State<_LitigeForm> createState() => _LitigeFormState();
}

class _LitigeFormState extends State<_LitigeForm> {
  static const _motifs = [
    'Commande pas reçue',
    'Produit abîmé ou de mauvaise qualité',
    'Mauvais produit reçu',
    'Quantité incorrecte',
    'Autre',
  ];

  final _description = TextEditingController();
  final _picker = ImagePicker();
  final List<XFile> _photos = [];
  String? _motif;
  bool _envoi = false;
  String? _erreur;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _ajouterPhoto() async {
    if (_photos.length >= 3) return;
    final file = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    if (file != null && mounted) setState(() => _photos.add(file));
  }

  Future<void> _envoyer() async {
    if (_motif == null) {
      setState(() => _erreur = 'Choisissez ce qui ne va pas');
      return;
    }
    final details = _description.text.trim();
    if (_motif == 'Autre' && details.length < 5) {
      setState(() => _erreur = 'Décrivez le problème');
      return;
    }
    setState(() {
      _envoi = true;
      _erreur = null;
    });

    final storage = StorageService();
    final urls = <String>[];
    for (final p in _photos) {
      final url = await storage.uploadLitigePhoto(
          file: p, orderId: widget.orderId);
      if (url != null) urls.add(url);
    }

    try {
      await Supabase.instance.client.rpc('ouvrir_litige', params: {
        'p_order_id': widget.orderId,
        'p_motif': details.isEmpty ? _motif : '$_motif — $details',
        'p_photos': urls,
      });
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Problème signalé. L'équipe CommercHaiti vous contactera."),
        backgroundColor: AppColors.green,
      ));
    } catch (e) {
      final msg = e.toString();
      setState(() {
        _envoi = false;
        _erreur = msg.contains('litige_deja_ouvert')
            ? 'Un problème est déjà signalé pour cette commande.'
            : msg.contains('commande_pas_encore_acceptee')
                ? "La commande n'est pas encore acceptée : vous pouvez l'annuler."
                : "Envoi impossible. Vérifiez votre connexion et réessayez.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Signaler un problème',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimaryFor(isDark))),
            const SizedBox(height: 4),
            Text("Votre signalement est envoyé à l'équipe CommercHaiti.",
                style: TextStyle(
                    fontSize: 12, color: AppColors.textSecondaryFor(isDark))),
            const SizedBox(height: 12),
            RadioGroup<String>(
              groupValue: _motif,
              onChanged: (v) {
                if (!_envoi) setState(() => _motif = v);
              },
              child: Column(children: [
                for (final m in _motifs)
                  RadioListTile<String>(
                    value: m,
                    enabled: !_envoi,
                    title: Text(m,
                        style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimaryFor(isDark))),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
              ]),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _description,
              enabled: !_envoi,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'Détails (facultatif)',
                filled: true,
                fillColor: AppColors.inputFill(isDark),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (var i = 0; i < _photos.length; i++)
                  Chip(
                    avatar: const Icon(Icons.photo, size: 16),
                    label: Text('Photo ${i + 1}'),
                    onDeleted:
                        _envoi ? null : () => setState(() => _photos.removeAt(i)),
                  ),
                if (_photos.length < 3)
                  TextButton.icon(
                    onPressed: _envoi ? null : _ajouterPhoto,
                    icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                    label: const Text('Ajouter une photo'),
                  ),
              ],
            ),
            if (_erreur != null) ...[
              const SizedBox(height: 8),
              Text(_erreur!,
                  style: const TextStyle(color: AppColors.red, fontSize: 12)),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.red,
                    foregroundColor: Colors.white),
                onPressed: _envoi ? null : _envoyer,
                child: _envoi
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Envoyer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
