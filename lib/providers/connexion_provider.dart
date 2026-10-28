import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// État de la connexion Internet du téléphone.
/// Path : lib/providers/connexion_provider.dart
///
/// Écoute les changements de réseau (Wi-Fi, données mobiles, aucun) pour
/// que l'app affiche un bandeau « Pas de connexion Internet » dès que le
/// téléphone perd le réseau, au lieu d'écrans vides ou qui tournent sans
/// fin (voir BandeauHorsLigne).
///
/// Limite : connectivity_plus sait si le téléphone est relié à un
/// réseau, pas si ce réseau a vraiment accès à Internet. Le cas « Wi-Fi
/// sans Internet » reste couvert par les messages d'erreur des écrans
/// (voir reseau_service.dart).
class ConnexionProvider extends ChangeNotifier {
  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _abonnement;
  bool _enLigne = true;

  bool get enLigne => _enLigne;

  ConnexionProvider({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity() {
    _connectivity.checkConnectivity().then(_maj).catchError((_) {});
    _abonnement = _connectivity.onConnectivityChanged.listen(_maj);
  }

  void _maj(List<ConnectivityResult> resultats) {
    final enLigne = resultats.any((r) => r != ConnectivityResult.none);
    if (enLigne != _enLigne) {
      _enLigne = enLigne;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _abonnement?.cancel();
    super.dispose();
  }
}
