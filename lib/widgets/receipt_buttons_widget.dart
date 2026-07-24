import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../models/order_model.dart';
import '../services/receipt_service.dart';
import 'receipt_image_widget.dart';

/// Boutons Télécharger / Partager le reçu PDF — BF-030 — + un bouton
/// "Partager en image" (PNG) en complément, plus pratique pour WhatsApp.
/// Charge lui-même la commande complète (items + boutique) à partir de
/// [orderId] afin de fonctionner depuis n'importe quel écran (suivi,
/// historique, détail vendeur) sans dépendre des données déjà en mémoire.
/// Path : lib/widgets/receipt_buttons_widget.dart
///
/// TECHNIQUE CLÉ (image "screenshot" d'un widget invisible) : pour
/// produire une image PNG du reçu, on ne peut pas simplement "dessiner sur
/// une image" en Flutter — il faut faire dessiner un VRAI widget par le
/// moteur de rendu, puis capturer ce rendu comme une image. La méthode
/// utilisée ici est :
///   1. Insérer `ReceiptImageWidget` dans l'`Overlay` (une couche
///      superposée à toute l'app, normalement utilisée pour les tooltips,
///      menus, etc.) mais positionné hors de l'écran visible
///      (`left: -9999`) — il est donc bel et bien construit et dessiné par
///      Flutter, mais l'utilisateur ne le voit jamais.
///   2. L'entourer d'un `RepaintBoundary`, un widget qui isole une zone du
///      rendu dans sa propre "couche" — condition nécessaire pour pouvoir
///      appeler `.toImage()` dessus et en extraire les pixels.
///   3. Attendre un court instant (`Future.delayed`) pour laisser Flutter
///      dessiner au moins une frame avant de capturer.
///   4. Convertir l'image capturée en PNG et la partager, puis retirer
///      l'OverlayEntry (nettoyage — sinon le widget invisible resterait
///      en mémoire indéfiniment).
class ReceiptButtonsWidget extends StatefulWidget {
  // Id de la commande dont on veut générer le reçu ; toutes les données
  // nécessaires (items, boutique) sont rechargées à partir de cet id.
  final String orderId;
  const ReceiptButtonsWidget({super.key, required this.orderId});

  @override
  State<ReceiptButtonsWidget> createState() => _ReceiptButtonsWidgetState();
}

class _ReceiptButtonsWidgetState extends State<ReceiptButtonsWidget> {
  // Service qui génère/télécharge/partage le PDF (voir receipt_service.dart).
  final _receiptService = ReceiptService();
  // Clé utilisée pour retrouver, dans l'arbre de widgets, le
  // RenderRepaintBoundary correspondant au reçu image invisible, afin de
  // pouvoir le capturer en image (voir _partagerImage).
  final _captureKey = GlobalKey();
  // Affiche un indicateur de chargement pendant que les données de la
  // commande sont récupérées et que l'action (PDF/image) s'exécute.
  bool _isLoading = false;

  /// Recharge depuis Supabase toutes les données nécessaires pour générer
  /// un reçu : la commande elle-même (`orders`), ses articles
  /// (`order_items`), puis le nom de la boutique (`shops`). Utilise le
  /// type "record" Dart `(OrderModel, String)` pour retourner deux valeurs
  /// sans créer de classe dédiée. Le nom de la boutique a une valeur de
  /// secours 'CommercHaiti' si la requête échoue (try/catch silencieux) —
  /// on préfère un reçu avec un nom générique plutôt que de bloquer tout
  /// le processus si cette requête secondaire échoue.
  Future<(OrderModel, String)> _chargerCommandeEtBoutique() async {
    final orderRow = await Supabase.instance.client
        .from('orders')
        .select()
        .eq('id', widget.orderId)
        .single();
    final itemRows = await Supabase.instance.client
        .from('order_items')
        .select()
        .eq('order_id', widget.orderId);
    final items = itemRows.map((r) => OrderItem.fromMap(r)).toList();
    final order = OrderModel.fromMap(orderRow, orderRow['id'], items: items);

    String shopNom = 'CommercHaiti';
    try {
      final shopRow = await Supabase.instance.client
          .from('shops')
          .select('nom')
          .eq('id', order.shopId)
          .single();
      shopNom = shopRow['nom'] as String? ?? shopNom;
    } catch (_) {}

    return (order, shopNom);
  }

  /// Wrapper générique pour les 3 boutons (PDF, Partager PDF, Partager
  /// image) : affiche le loader, charge la commande + la boutique, exécute
  /// l'action spécifique passée en paramètre `fn` (une fonction qui reçoit
  /// la commande et le nom de la boutique déjà chargés), affiche un
  /// SnackBar d'erreur en cas d'échec, puis retire le loader dans tous les
  /// cas via `finally`. Cette factorisation évite de dupliquer la logique
  /// de chargement/gestion d'erreur dans chacun des 3 boutons.
  Future<void> _action(
      Future<void> Function(OrderModel order, String shopNom) fn) async {
    setState(() => _isLoading = true);
    try {
      final (order, shopNom) = await _chargerCommandeEtBoutique();
      await fn(order, shopNom);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur reçu : ${e.toString()}'),
          backgroundColor: const Color(0xFFE63946),
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Rend ReceiptImageWidget hors-écran (via l'Overlay), le capture en
  /// PNG, puis le partage — sans jamais l'afficher à l'utilisateur.
  Future<void> _partagerImage(OrderModel order, String shopNom) async {
    // Récupère l'Overlay de l'application (couche de superposition
    // au-dessus de toutes les pages, gérée par le Navigator/MaterialApp).
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    // Construit l'entrée d'overlay : un Positioned avec left: -9999 place
    // le widget très loin à gauche de l'écran visible — il est bien
    // "monté" et dessiné par Flutter (donc capturable), mais totalement
    // invisible pour l'utilisateur car hors des limites de l'écran.
    entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -9999, top: 0,
        child: RepaintBoundary(
          key: _captureKey,
          child: ReceiptImageWidget(order: order, shopNom: shopNom),
        ),
      ),
    );
    // Insère effectivement l'entrée dans l'Overlay — déclenche sa
    // construction et son premier rendu.
    overlay.insert(entry);

    try {
      // Laisse un frame se dessiner avant la capture.
      // Sans ce délai, le RenderRepaintBoundary pourrait ne pas encore
      // avoir de contenu peint (l'insertion dans l'Overlay ne garantit pas
      // un rendu synchrone immédiat), ce qui produirait une image vide.
      await Future.delayed(const Duration(milliseconds: 50));
      // Retrouve l'objet de rendu (RenderRepaintBoundary) associé à la clé
      // — c'est lui qui expose la méthode toImage() pour capturer les
      // pixels réellement dessinés dans cette zone.
      final boundary = _captureKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      // Capture le contenu en image bitmap. pixelRatio: 2.5 = résolution
      // 2.5x plus élevée que la taille logique du widget (comme un écran
      // "Retina"), pour un rendu net et lisible même zoomé dans WhatsApp.
      final image = await boundary.toImage(pixelRatio: 2.5);
      // Encode l'image bitmap en octets au format PNG.
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      // Ouvre la feuille de partage native (share_plus) avec le fichier
      // PNG créé directement en mémoire (XFile.fromData, pas besoin
      // d'écrire sur disque), accompagné d'un texte descriptif.
      await Share.shareXFiles(
        [
          XFile.fromData(bytes,
              name: 'recu-commerchaiti-${order.id.substring(0, 6)}.png',
              mimeType: 'image/png'),
        ],
        text: 'Reçu CommercHaiti — Commande #${order.id.substring(0, 6).toUpperCase()}',
      );
    } finally {
      // Retire systématiquement le widget invisible de l'Overlay, que le
      // partage ait réussi ou échoué — sinon il resterait indéfiniment
      // "monté" en mémoire (fuite) même s'il n'est jamais visible.
      entry.remove();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Pendant le chargement, on remplace toute la rangée de boutons par un
    // simple indicateur de progression centré — évite les clics multiples
    // et donne un retour visuel clair à l'utilisateur.
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    // `Wrap` place les boutons en ligne et les fait automatiquement passer
    // à la ligne suivante si l'espace horizontal manque (plus robuste
    // qu'une Row sur petits écrans).
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        // Bouton 1 : télécharger/ouvrir l'aperçu natif du PDF.
        TextButton.icon(
          onPressed: () => _action((order, nom) =>
              _receiptService.telecharger(order, shopNom: nom)),
          icon: const Icon(Icons.download_outlined, size: 16),
          label: const Text('PDF'),
        ),
        // Bouton 2 : partager directement le fichier PDF (share sheet).
        TextButton.icon(
          onPressed: () => _action((order, nom) =>
              _receiptService.partager(order, shopNom: nom)),
          icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
          label: const Text('Partager PDF'),
        ),
        // Bouton 3 : partager le reçu sous forme d'image PNG (technique
        // Overlay + RepaintBoundary décrite plus haut) — plus adapté à un
        // aperçu WhatsApp qu'un fichier PDF.
        TextButton.icon(
          onPressed: () => _action(_partagerImage),
          icon: const Icon(Icons.image_outlined, size: 16),
          label: const Text('Partager en image'),
        ),
      ],
    );
  }
}
