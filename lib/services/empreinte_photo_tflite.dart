import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Calcul de l'empreinte d'une photo (recherche par photo)
/// Path : lib/services/empreinte_photo_tflite.dart
///
/// Modèle MobileNet V3 small (Google MediaPipe Image Embedder, ~4 Mo,
/// licence Apache 2.0) : entrée 224×224 pixels RGB en valeurs 0..1,
/// sortie 1024 nombres. Utilisé par recherche_photo_service.dart.

const _modele = 'assets/models/recherche_photo.tflite';
const _taille = 224;
const _dimensions = 1024;

Interpreter? _interpreter;

/// Empreinte normalisée (longueur 1) de l'image, ou null si l'image ne
/// peut pas être lue.
Future<List<double>?> calculerEmpreinte(Uint8List octets) async {
  // Décodage + redimensionnement dans un isolate : sur une photo de
  // caméra (plusieurs Mo) cela prend du temps et figerait l'écran.
  final entree = await compute(_preparerImage, octets);
  if (entree == null) return null;

  final interpreter = _interpreter ??= await Interpreter.fromAsset(_modele);
  final sortie = List.generate(1, (_) => List.filled(_dimensions, 0.0));
  // Octets bruts du Float32List : copiés tels quels dans le tenseur
  // d'entrée [1, 224, 224, 3] (bien plus rapide qu'une liste imbriquée).
  interpreter.run(entree.buffer.asUint8List(), sortie);

  final v = sortie.first;
  final norme = math.sqrt(v.fold<double>(0, (s, x) => s + x * x));
  if (norme == 0) return null;
  return v.map((x) => x / norme).toList();
}

/// Décode l'image, la redresse selon l'orientation EXIF (photos caméra),
/// la ramène à 224×224 et convertit chaque pixel en valeurs 0..1 (format
/// attendu par le modèle). Exécuté dans un isolate via compute().
Float32List? _preparerImage(Uint8List octets) {
  final decodee = img.decodeImage(octets);
  if (decodee == null) return null;
  final redressee = img.bakeOrientation(decodee);
  final petite = img.copyResize(
    redressee,
    width: _taille,
    height: _taille,
    // « average » fait la moyenne des pixels regroupés : réduction
    // propre, même depuis une grande photo de caméra.
    interpolation: img.Interpolation.average,
  );
  const t = _taille;
  final entree = Float32List(t * t * 3);
  var i = 0;
  for (var y = 0; y < t; y++) {
    for (var x = 0; x < t; x++) {
      final p = petite.getPixel(x, y);
      entree[i++] = p.rNormalized.toDouble();
      entree[i++] = p.gNormalized.toDouble();
      entree[i++] = p.bNormalized.toDouble();
    }
  }
  return entree;
}
