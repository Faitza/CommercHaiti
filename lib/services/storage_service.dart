// ignore_for_file: avoid_print
// TODO Falexson : décommenter quand Firebase sera configuré
// import 'package:firebase_storage/firebase_storage.dart';
// import 'package:flutter_image_compress/flutter_image_compress.dart';
// import 'dart:io';

/// Service Storage — Falexson MERCIVAL
/// Branch : feature/firebase-core
/// Path : lib/services/storage_service.dart
/// Upload et compression photos avant envoi Firebase Storage
/// Max 600x600px — obligatoire pour performances sur réseau 3G
class StorageService {
  // final FirebaseStorage _storage = FirebaseStorage.instance;

  // ════════════════════════════════════
  // PHOTOS PRODUITS
  // ════════════════════════════════════

  /// Upload photo produit compressée 600x600px
  /// Retourne URL de téléchargement ou null si erreur
  Future<String?> uploadProductPhoto({
    required String filePath,
    required String shopId,
    required String productId,
  }) async {
    try {
      // TODO :
      // // 1. Comprimer image
      // final dir = await getTemporaryDirectory();
      // final targetPath = '${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      // final compressed = await FlutterImageCompress.compressAndGetFile(
      //   filePath,
      //   targetPath,
      //   minWidth: 600,
      //   minHeight: 600,
      //   quality: 85,
      // );
      // if (compressed == null) throw Exception('Compression échouée');
      //
      // // 2. Upload vers Firebase Storage
      // final ref = _storage
      //   .ref()
      //   .child('shops')
      //   .child(shopId)
      //   .child('products')
      //   .child(productId)
      //   .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
      //
      // final task = await ref.putFile(File(compressed.path));
      // return await task.ref.getDownloadURL();

      // ── DONNÉES TEST ──
      print('[TEST] Photo produit uploadée : $filePath');
      return 'https://via.placeholder.com/600x600?text=Produit';
    } catch (e) {
      print('Erreur uploadProductPhoto: $e');
      return null;
    }
  }

  // ════════════════════════════════════
  // LOGO BOUTIQUE
  // ════════════════════════════════════

  Future<String?> uploadShopLogo({
    required String filePath,
    required String shopId,
  }) async {
    try {
      // TODO :
      // final ref = _storage
      //   .ref()
      //   .child('shops')
      //   .child(shopId)
      //   .child('logo.jpg');
      //
      // final compressed = await FlutterImageCompress.compressAndGetFile(
      //   filePath,
      //   filePath.replaceAll('.jpg', '_logo.jpg'),
      //   minWidth: 300,
      //   minHeight: 300,
      //   quality: 90,
      // );
      //
      // final task = await ref.putFile(File(compressed!.path));
      // return await task.ref.getDownloadURL();

      print('[TEST] Logo boutique uploadé : $filePath');
      return 'https://via.placeholder.com/300x300?text=Logo';
    } catch (e) {
      print('Erreur uploadShopLogo: $e');
      return null;
    }
  }

  // ════════════════════════════════════
  // SUPPRIMER
  // ════════════════════════════════════

  Future<void> deleteFile(String downloadUrl) async {
    try {
      // TODO :
      // final ref = _storage.refFromURL(downloadUrl);
      // await ref.delete();
      print('[TEST] Fichier supprimé : $downloadUrl');
    } catch (e) {
      print('Erreur deleteFile: $e');
    }
  }
}