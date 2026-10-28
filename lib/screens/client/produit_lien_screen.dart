import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../constants/app_colors.dart';
import '../../models/product_model.dart';
import '../../providers/auth_provider.dart';

/// Ouverture d'un produit depuis un lien partagé — Faitza COLAS
/// Path : lib/screens/client/produit_lien_screen.dart
///
/// Route `/p/:id`, atteinte quand on clique sur le lien produit d'un
/// message WhatsApp (https://…/p/<id>, ou commerchaiti://app/p/<id> depuis
/// le bouton "Ouvrir dans l'app" de la page web) alors que l'app est
/// installée.
///
/// L'écran charge le produit, puis remplace la pile par l'accueil (pour
/// que le bouton retour du détail produit ramène dans l'app au lieu de la
/// fermer) et ouvre le détail produit par-dessus.
class ProduitLienScreen extends StatefulWidget {
  final String productId;

  const ProduitLienScreen({super.key, required this.productId});

  @override
  State<ProduitLienScreen> createState() => _ProduitLienScreenState();
}

class _ProduitLienScreenState extends State<ProduitLienScreen> {
  bool _introuvable = false;

  @override
  void initState() {
    super.initState();
    _ouvrir();
  }

  Future<void> _ouvrir() async {
    ProductModel? produit;
    try {
      final row = await Supabase.instance.client
          .from('products')
          .select()
          .eq('id', widget.productId)
          .maybeSingle();
      if (row != null) produit = ProductModel.fromMap(row, row['id']);
    } catch (_) {
      // Lien invalide ou pas de réseau : message "introuvable" ci-dessous.
    }
    await _attendreProfil();
    if (!mounted) return;
    if (produit == null) {
      setState(() => _introuvable = true);
      return;
    }
    final auth = context.read<AuthProvider>();
    if (auth.isLoggedIn && auth.isSeller) {
      // Le détail produit est un écran client (interdit aux vendeurs, voir
      // `redirect` dans app_router.dart) : le vendeur arrive sur son
      // tableau de bord.
      context.go('/vendor/dashboard');
      return;
    }
    context.go(auth.isLoggedIn ? '/client/home' : '/guest');
    context.push('/client/product', extra: produit);
  }

  /// App ouverte "à froid" par le lien : la session Supabase est déjà là
  /// mais le profil (rôle client/vendeur) se charge encore. On attend
  /// qu'il soit prêt (5 s maximum) pour choisir le bon accueil.
  Future<void> _attendreProfil() async {
    final auth = context.read<AuthProvider>();
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null || auth.isLoggedIn) return;
    final pret = Completer<void>();
    void ecouter() {
      if (auth.isLoggedIn && !pret.isCompleted) pret.complete();
    }

    auth.addListener(ecouter);
    await pret.future
        .timeout(const Duration(seconds: 5), onTimeout: () {});
    auth.removeListener(ecouter);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _introuvable
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Ce produit est introuvable.\n'
                      'Il a peut-être été retiré par la boutique.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => context.go('/splash'),
                      child: const Text('Aller à l\'accueil'),
                    ),
                  ],
                ),
              )
            : const CircularProgressIndicator(color: AppColors.navy),
      ),
    );
  }
}
