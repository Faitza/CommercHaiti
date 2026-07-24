import 'package:flutter/material.dart';
import '../models/review_model.dart';
import '../services/database_service.dart';

/// Bottom sheet "Laisser un avis" — après une commande livrée.
/// Path : lib/widgets/review_dialog_widget.dart
///
/// Composé de deux parties : `ReviewDialogWidget` est une classe utilitaire
/// statique qui sert uniquement de point d'entrée pour afficher le bottom
/// sheet (comme un "constructeur" de dialogue) ; `_ReviewSheet` (privée,
/// préfixée `_`) est le vrai widget avec état qui gère la note en étoiles,
/// le commentaire et l'envoi de l'avis vers Supabase.
class ReviewDialogWidget {
  /// Ouvre le bottom sheet de notation par-dessus l'écran actuel.
  /// `isScrollControlled: true` permet au bottom sheet de prendre plus de
  /// hauteur que la moitié de l'écran (utile ici car le clavier apparaît
  /// pour le champ commentaire) ; les coins du haut sont arrondis pour un
  /// look "carte qui glisse depuis le bas".
  static Future<void> show(
    BuildContext context, {
    required String shopId,
    required String clientId,
    required String orderId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ReviewSheet(
        shopId: shopId,
        clientId: clientId,
        orderId: orderId,
      ),
    );
  }
}

/// Widget interne (privé) contenant le formulaire d'avis : sélection
/// d'une note de 1 à 5 étoiles, champ commentaire optionnel, bouton
/// d'envoi. Reçoit les identifiants nécessaires (boutique, client,
/// commande) pour construire l'avis à enregistrer.
class _ReviewSheet extends StatefulWidget {
  final String shopId;
  final String clientId;
  final String orderId;
  const _ReviewSheet({
    required this.shopId,
    required this.clientId,
    required this.orderId,
  });

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  // Instance du service base de données pour insérer l'avis (createReview
  // -> table `reviews` sur Supabase).
  final _db = DatabaseService();
  // Contrôleur du champ texte du commentaire.
  final _commentaireCtrl = TextEditingController();
  // Note sélectionnée par l'utilisateur (1 à 5 étoiles), 5 par défaut.
  int _note = 5;
  // Empêche les envois multiples et affiche un indicateur de chargement
  // pendant la requête réseau.
  bool _isLoading = false;

  /// Construit un ReviewModel à partir des données saisies puis l'envoie à
  /// `DatabaseService.createReview`. L'id est laissé vide (`''`) car il
  /// est généré côté base de données (clé primaire auto). Le commentaire
  /// est `trim()`é (espaces enlevés) puis mis à `null` s'il est vide,
  /// plutôt que d'enregistrer une chaîne vide — un commentaire est donc
  /// vraiment optionnel en base. En cas de succès : ferme le bottom sheet
  /// et affiche un SnackBar de remerciement ; en cas d'erreur : affiche un
  /// SnackBar rouge avec le message d'erreur. `finally` garantit que
  /// `_isLoading` repasse à `false` dans tous les cas (succès, erreur, ou
  /// widget démonté). Les vérifications `mounted` évitent d'appeler
  /// setState()/Navigator sur un widget déjà retiré de l'arbre pendant
  /// l'attente asynchrone.
  Future<void> _envoyer() async {
    setState(() => _isLoading = true);
    try {
      final review = ReviewModel(
        id: '',
        shopId: widget.shopId,
        clientId: widget.clientId,
        orderId: widget.orderId,
        note: _note,
        commentaire: _commentaireCtrl.text.trim().isEmpty
            ? null
            : _commentaireCtrl.text.trim(),
        createdAt: DateTime.now(),
      );
      await _db.createReview(review);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Merci pour votre avis !'),
          backgroundColor: Color(0xFF1D9E75),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : ${e.toString()}'),
          backgroundColor: const Color(0xFFE63946),
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // `viewInsets.bottom` = hauteur du clavier virtuel quand il est
    // affiché ; on l'ajoute au padding bas pour que le contenu (et surtout
    // le bouton "Envoyer") remonte au-dessus du clavier au lieu d'être
    // masqué par lui.
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        // mainAxisSize.min = la colonne ne prend que la hauteur nécessaire
        // à son contenu (important dans un bottom sheet, sinon elle
        // essaierait de remplir tout l'écran).
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Laisser un avis',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D2B5E))),
          const SizedBox(height: 16),
          // ── Sélecteur de note : 5 étoiles cliquables ──
          // `List.generate(5, ...)` crée 5 IconButton, un par étoile
          // possible (valeur 1 à 5, i+1 car i part de 0). Chaque étoile
          // est "pleine" (star_rounded) si sa valeur est <= à la note
          // actuellement sélectionnée, sinon "vide" (star_border_rounded)
          // — technique classique pour un sélecteur d'étoiles où cliquer
          // sur la 3e étoile remplit les étoiles 1, 2 et 3.
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final valeur = i + 1;
                return IconButton(
                  onPressed: () => setState(() => _note = valeur),
                  icon: Icon(
                    valeur <= _note ? Icons.star_rounded : Icons.star_border_rounded,
                    color: const Color(0xFFF5A623),
                    size: 32,
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),
          // ── Champ commentaire optionnel (3 lignes max, 200 caractères max) ──
          TextField(
            controller: _commentaireCtrl,
            maxLines: 3,
            maxLength: 200,
            decoration: InputDecoration(
              hintText: 'Commentaire (optionnel)…',
              filled: true,
              fillColor: const Color(0xFFF5F5F5),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
            ),
          ),
          // ── Bouton d'envoi ──
          // Désactivé (`onPressed: null`) pendant le chargement pour
          // empêcher un double envoi ; affiche un petit spinner à la place
          // du texte "Envoyer" tant que la requête est en cours.
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D2B5E),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isLoading ? null : _envoyer,
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Envoyer',
                      style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  /// Libère le contrôleur de texte quand le widget est détruit — évite une
  /// fuite mémoire (bonne pratique obligatoire pour tout
  /// TextEditingController créé manuellement).
  @override
  void dispose() {
    _commentaireCtrl.dispose();
    super.dispose();
  }
}
