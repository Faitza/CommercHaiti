import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/notification_model.dart';

/// Boîte de notifications de l'utilisateur connecté (cloche + écran
/// Notifications). Écoute la table `notifications` en temps réel : le
/// badge se met à jour dès qu'un trigger serveur insère une ligne.
class NotificationProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  List<NotificationModel> _notifications = [];
  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  String? _userId;

  List<NotificationModel> get notifications => _notifications;
  int get nonLues => _notifications.where((n) => !n.lu).length;

  /// Démarre l'écoute pour cet utilisateur. Sans effet si on écoute déjà
  /// le même utilisateur (appelable depuis initState sans risque).
  void listen(String userId) {
    if (_userId == userId && _sub != null) return;
    _sub?.cancel();
    _userId = userId;
    _sub = _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(100)
        .listen((rows) {
      _notifications = rows.map(NotificationModel.fromMap).toList();
      notifyListeners();
    }, onError: (e) => debugPrint('NotificationProvider: $e'));
  }

  Future<void> marquerLue(String id) async {
    final i = _notifications.indexWhere((n) => n.id == id);
    if (i == -1 || _notifications[i].lu) return;
    await _supabase.from('notifications').update({'lu': true}).eq('id', id);
  }

  Future<void> toutMarquerLu() async {
    if (_userId == null || nonLues == 0) return;
    await _supabase
        .from('notifications')
        .update({'lu': true})
        .eq('user_id', _userId!)
        .eq('lu', false);
  }

  /// Arrête l'écoute (déconnexion).
  void clear() {
    if (_sub == null && _notifications.isEmpty) return;
    _sub?.cancel();
    _sub = null;
    _userId = null;
    _notifications = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
