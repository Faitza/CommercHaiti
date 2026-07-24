import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw; // Alias "pw" pour distinguer les widgets PDF des widgets Flutter (Material)
import 'package:printing/printing.dart';
import '../models/order_model.dart';

/// Reçu PDF automatique — BF-030
/// Path : lib/services/receipt_service.dart
/// Généré quand orders.statut passe à 'livree'. Contenu : boutique, numéro
/// commande, date, infos client, articles, total, mode paiement.
///
/// Ce service utilise le package `pdf` (et non Flutter) pour construire le
/// document : les widgets `pw.*` ressemblent aux widgets Flutter (Column,
/// Row, Text...) mais génèrent des instructions de dessin PDF au lieu de
/// pixels à l'écran. Le package `printing` sert ensuite à afficher
/// l'aperçu natif ou à partager le fichier généré.
class ReceiptService {
  /// Construit le PDF du reçu en mémoire (sans l'enregistrer sur disque) et
  /// retourne ses octets bruts (Uint8List). C'est cette méthode que
  /// [telecharger] et [partager] appellent avant d'agir sur le résultat.
  Future<Uint8List> genererRecu(OrderModel order, {required String shopNom}) async {
    // Document PDF vide auquel on va ajouter une page.
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        // Format standard A4 (comme une feuille de papier classique).
        pageFormat: PdfPageFormat.a4,
        // `build` est appelé par le moteur PDF pour dessiner le contenu de
        // la page — équivalent du `build(BuildContext)` en Flutter normal.
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── En-tête : nom de la boutique + sous-titre CommercHaiti ──
            pw.Text(shopNom,
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.Text('CommercHaiti — Reçu de commande',
                style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
            pw.SizedBox(height: 16),
            pw.Divider(),
            pw.SizedBox(height: 8),
            // ── Informations générales de la commande (numéro, date, client…) ──
            // On ne garde que les 6 premiers caractères de l'UUID de la
            // commande (en majuscules) pour un numéro plus court et lisible
            // par le client, plutôt que d'afficher l'UUID complet.
            _ligne('N° commande', '#${order.id.substring(0, 6).toUpperCase()}'),
            _ligne('Date', _formatDate(order.createdAt)),
            _ligne('Client', order.telephoneClient),
            _ligne('Adresse', order.adresseLivraison),
            _ligne('Zone', order.zone),
            pw.SizedBox(height: 16),
            // ── Tableau des articles commandés ──
            pw.Text('Articles',
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              // Largeurs relatives des 3 colonnes : Produit prend 3 parts,
              // Qté 1 part, Sous-total 1.5 part.
              columnWidths: const {
                0: pw.FlexColumnWidth(3),
                1: pw.FlexColumnWidth(1),
                2: pw.FlexColumnWidth(1.5),
              },
              children: [
                // Ligne d'en-tête du tableau (titres de colonnes en gras).
                pw.TableRow(children: [
                  _cell('Produit', bold: true),
                  _cell('Qté', bold: true),
                  _cell('Sous-total', bold: true),
                ]),
                // Une ligne par article de la commande, générée
                // dynamiquement à partir de order.items.
                ...order.items.map((item) => pw.TableRow(children: [
                      _cell(item.nom),
                      _cell('${item.quantite}'),
                      _cell('${item.sousTotal.toStringAsFixed(0)} HTG'),
                    ])),
              ],
            ),
            pw.SizedBox(height: 16),
            // ── Total de la commande, aligné à droite ──
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Total : ${order.total.toStringAsFixed(0)} HTG',
                  style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 8),
            // Mode de paiement fixe : l'app ne gère que le paiement à la
            // livraison (cash), donc pas besoin de champ dynamique ici.
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Mode de paiement : Paiement à la livraison',
                  style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
            ),
            pw.SizedBox(height: 24),
            pw.Divider(),
            // ── Pied de page : message de remerciement ──
            pw.Text('Merci d\'avoir commandé sur CommercHaiti !',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          ],
        ),
      ),
    );

    // Sérialise le document en octets PDF prêts à être enregistrés,
    // imprimés ou partagés.
    return doc.save();
  }

  /// Ouvre l'aperçu natif — permet de télécharger / imprimer le PDF.
  /// `Printing.layoutPdf` ouvre la boîte de dialogue système d'impression /
  /// export PDF ; `onLayout` est un callback appelé par le plugin pour
  /// récupérer les octets à afficher — ici on retourne simplement les
  /// bytes déjà générés (le paramètre `_` du format de page est ignoré).
  Future<void> telecharger(OrderModel order, {required String shopNom}) async {
    final bytes = await genererRecu(order, shopNom: shopNom);
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'recu-commerchaiti-${order.id.substring(0, 6)}.pdf',
    );
  }

  /// Partage le PDF (ex. via WhatsApp) avec la feuille de partage native.
  /// `Printing.sharePdf` ouvre le "share sheet" du système (Android/iOS/Web)
  /// pour envoyer le fichier PDF vers une autre application.
  Future<void> partager(OrderModel order, {required String shopNom}) async {
    final bytes = await genererRecu(order, shopNom: shopNom);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'recu-commerchaiti-${order.id.substring(0, 6)}.pdf',
    );
  }

  /// Petit helper : affiche une ligne "label / valeur" alignée sur les
  /// bords opposés (ex. "Client" à gauche, le numéro de téléphone à
  /// droite). Utilisé pour toutes les infos générales de la commande.
  pw.Widget _ligne(String label, String valeur) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: const pw.TextStyle(color: PdfColors.grey700)),
            pw.Text(valeur, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ],
        ),
      );

  /// Petit helper : construit une cellule de tableau avec un padding
  /// uniforme ; `bold` permet de mettre en gras les cellules d'en-tête.
  pw.Widget _cell(String t, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(t,
            style: pw.TextStyle(
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                fontSize: 10)),
      );

  /// Formate une date au format jour/mois/année avec zéros de tête
  /// (ex. 03/07/2026), plus lisible pour un client qu'un format ISO.
  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
