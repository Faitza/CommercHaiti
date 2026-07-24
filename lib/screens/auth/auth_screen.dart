import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

/// Auth Screen — Faitza COLAS
/// Path : lib/screens/auth/auth_screen.dart
// Écran unique regroupant Connexion et Inscription via deux onglets
// (TabBar/TabBarView). Le formulaire d'inscription change légèrement selon
// le rôle (Client ou Vendeur) reçu depuis l'écran précédent
// (role_selection_screen.dart).
class AuthScreen extends StatefulWidget {
  // Rôle choisi précédemment : 'customer' ou 'seller'. Reçu via `extra`
  // lors de la navigation depuis RoleSelectionScreen.
  final String role;
  const AuthScreen({super.key, required this.role});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  // Contrôleur des deux onglets (Connexion / Inscription).
  // SingleTickerProviderStateMixin fournit le `vsync` requis par
  // TabController pour synchroniser ses animations.
  late TabController _tabController;

  // Contrôleurs de texte pour tous les champs de formulaire (connexion +
  // inscription client/vendeur). Ils doivent tous être libérés (dispose)
  // pour éviter les fuites mémoire — voir la méthode dispose() plus bas.
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nomCtrl = TextEditingController();
  final _telephoneCtrl = TextEditingController();
  final _adresseCtrl = TextEditingController();
  final _nomBoutiqueCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  // Aperçu du code boutique généré en direct à partir du nom saisi
  // (utile pour montrer au vendeur ce que sera son code avant validation).
  String _shopCodePreview = '';
  // Bascule l'affichage en clair/masqué du mot de passe.
  bool _obscurePassword = true;

  // Raccourci pratique : vrai si le rôle courant est "vendeur".
  bool get isVendeur => widget.role == 'seller';

  @override
  void initState() {
    super.initState();
    // 2 onglets : Connexion (index 0) et Inscription (index 1).
    _tabController = TabController(length: 2, vsync: this);
    // Écoute les changements du champ "nom de la boutique" pour régénérer
    // en temps réel l'aperçu du code boutique (utile uniquement côté
    // vendeur, mais le listener est inoffensif côté client car ce champ
    // n'est alors jamais rempli).
    _nomBoutiqueCtrl.addListener(() {
      if (_nomBoutiqueCtrl.text.isNotEmpty) {
        setState(() => _shopCodePreview =
            context.read<AuthProvider>().generateShopCode(_nomBoutiqueCtrl.text));
      }
    });
  }

  // ── Fonctions de validation des champs (utilisées par les TextFormField
  // via leur paramètre `validator`) ──

  // Vérifie qu'un email est renseigné et respecte un format basique
  // (regex simple : texte@texte.domaine).
  String? _valEmail(String? v) {
    if (v == null || v.isEmpty) return 'Email requis';
    if (!RegExp(r'^[\w.-]+@[\w.-]+\.[a-z]{2,}$').hasMatch(v)) return 'Email invalide';
    return null;
  }
  // Vérifie que le mot de passe est renseigné et fait au moins 6 caractères.
  String? _valPassword(String? v) {
    if (v == null || v.isEmpty) return 'Mot de passe requis';
    if (v.length < 6) return 'Minimum 6 caractères';
    return null;
  }
  // Vérifie que le nom est renseigné et fait au moins 2 caractères.
  String? _valNom(String? v) {
    if (v == null || v.isEmpty) return 'Nom requis';
    if (v.length < 2) return 'Trop court';
    return null;
  }
  // Vérifie que le téléphone est renseigné et contient au moins 8 chiffres
  // (on retire tout caractère non numérique avant de compter).
  String? _valTel(String? v) {
    if (v == null || v.isEmpty) return 'Téléphone requis';
    if (v.replaceAll(RegExp(r'[^\d]'), '').length < 8) return 'Numéro trop court';
    return null;
  }

  // Tente une connexion via AuthProvider.signIn avec l'email/mot de passe
  // saisis. En cas de succès, redirige vers le tableau de bord vendeur ou
  // l'accueil client selon le rôle réel du compte (auth.isSeller vient du
  // backend, pas du widget.role affiché). En cas d'échec, affiche le
  // message d'erreur retourné par le provider dans un SnackBar.
  Future<void> _connexion() async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.signIn(_emailCtrl.text.trim(), _passwordCtrl.text);
    // Vérifie que le widget est toujours affiché avant d'utiliser le
    // BuildContext après un await (bonne pratique Flutter obligatoire).
    if (!mounted) return;
    if (ok) {
      context.go(auth.isSeller ? '/vendor/dashboard' : '/client/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(auth.errorMessage ?? 'Erreur connexion'),
        backgroundColor: const Color(0xFFE63946),
      ));
    }
  }

  // Tente une inscription. Selon `isVendeur`, appelle soit
  // AuthProvider.signUpVendeur (avec les champs boutique en plus) soit
  // AuthProvider.signUpClient. En cas de succès :
  //  - le vendeur est envoyé vers /create-shop pour finaliser sa boutique,
  //    avec le code boutique généré transmis en `extra` ;
  //  - le client est envoyé directement vers /client/home.
  Future<void> _inscription() async {
    final auth = context.read<AuthProvider>();
    bool ok = false;
    if (isVendeur) {
      ok = await auth.signUpVendeur(
        nom: _nomCtrl.text.trim(),
        telephone: _telephoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        nomBoutique: _nomBoutiqueCtrl.text.trim(),
        description: _descriptionCtrl.text.trim(),
      );
    } else {
      ok = await auth.signUpClient(
        nom: _nomCtrl.text.trim(),
        telephone: _telephoneCtrl.text.trim(),
        adresse: _adresseCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
    }
    if (!mounted) return;
    if (ok) {
      if (isVendeur) {
        context.go('/create-shop', extra: {'shopCode': _shopCodePreview});
      } else {
        context.go('/client/home');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(auth.errorMessage ?? 'Erreur inscription'),
        backgroundColor: const Color(0xFFE63946),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    // `watch` (et non `read`) car ce widget doit se reconstruire quand
    // `isLoading` ou `errorMessage` changent (pour afficher le spinner sur
    // les boutons pendant les appels réseau).
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      body: Column(
        children: [
          // Header
          // En-tête bleu marine avec bouton retour, titre dynamique
          // (Espace Vendeur / Espace Client) et la TabBar Connexion/Inscription.
          Container(
            color: const Color(0xFF0D2B5E),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              bottom: 0,
              left: 4,
              right: 16,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Bouton retour : ramène à l'écran de choix de rôle.
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 20),
                      onPressed: () => context.go('/role-selection'),
                    ),
                    const SizedBox(width: 4),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Titre qui change selon le rôle transmis.
                        Text(
                          isVendeur ? 'Espace Vendeur' : 'Espace Client',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                        const Text('CommercHaiti · Les Cayes',
                            style: TextStyle(
                                color: Colors.white54, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Onglets Connexion / Inscription liés au _tabController.
                TabBar(
                  controller: _tabController,
                  indicatorColor: const Color(0xFFE63946),
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                  tabs: const [Tab(text: 'Connexion'), Tab(text: 'Inscription')],
                ),
              ],
            ),
          ),

          // Contenu des onglets : bascule entre le formulaire de connexion
          // et celui d'inscription selon l'onglet actif.
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildConnexion(auth),
                _buildInscription(auth),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Construit le formulaire de connexion : email, mot de passe, bouton
  // "Se connecter", bouton Google, et (pour les clients uniquement) un
  // lien pour parcourir en mode visiteur sans s'inscrire.
  Widget _buildConnexion(AuthProvider auth) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _label('Email'),
          _field(_emailCtrl, 'exemple@email.com',
              validator: _valEmail,
              keyboardType: TextInputType.emailAddress,
              icon: Icons.email_outlined),
          const SizedBox(height: 14),
          _label('Mot de passe'),
          _passwordField(),
          const SizedBox(height: 24),
          // Bouton principal : affiche un spinner pendant le chargement
          // (auth.isLoading) et est désactivé le temps de l'appel réseau.
          _bouton('Se connecter', _connexion, auth.isLoading),
          const SizedBox(height: 12),
          _boutonGoogle(auth),
          // Le lien "mode visiteur" n'est proposé que côté client : un
          // vendeur doit obligatoirement se connecter/s'inscrire pour
          // accéder à son tableau de bord.
          if (!isVendeur) ...[
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => context.go('/guest'),
                child: const Text('Parcourir sans s\'inscrire',
                    style: TextStyle(
                        color: Color(0xFF666666), fontSize: 13)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Construit le formulaire d'inscription. Les champs affichés diffèrent
  // selon le rôle :
  //  - Client : nom, téléphone, adresse, email, mot de passe.
  //  - Vendeur : nom, téléphone, email, mot de passe, nom de boutique
  //    (avec aperçu du code généré), description de la boutique.
  Widget _buildInscription(AuthProvider auth) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _label('Nom complet'),
          _field(_nomCtrl, 'Marie Joseph', validator: _valNom,
              icon: Icons.person_outline),
          const SizedBox(height: 14),
          _label('Téléphone'),
          _field(_telephoneCtrl, '+509 XXXX XXXX',
              validator: _valTel,
              keyboardType: TextInputType.phone,
              icon: Icons.phone_outlined),
          // Adresse uniquement demandée au client (nécessaire pour la
          // livraison), pas au vendeur.
          if (!isVendeur) ...[
            const SizedBox(height: 14),
            _label('Adresse principale'),
            _field(_adresseCtrl, 'Rue Toussaint Louverture, Les Cayes',
                validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                icon: Icons.location_on_outlined),
          ],
          const SizedBox(height: 14),
          _label('Email'),
          _field(_emailCtrl, 'exemple@email.com',
              validator: _valEmail,
              keyboardType: TextInputType.emailAddress,
              icon: Icons.email_outlined),
          const SizedBox(height: 14),
          _label('Mot de passe'),
          _passwordField(),
          // Champs spécifiques au vendeur : nom + code + description de
          // la boutique.
          if (isVendeur) ...[
            const SizedBox(height: 14),
            _label('Nom de la boutique'),
            _field(_nomBoutiqueCtrl, 'Marché Frais Lakay',
                validator: (v) => v == null || v.length < 3 ? 'Min 3 caractères' : null,
                icon: Icons.store_outlined),
            // Aperçu du code boutique — n'apparaît qu'une fois le nom
            // saisi (voir le listener dans initState).
            if (_shopCodePreview.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF3FB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  const Icon(Icons.tag, size: 16, color: Color(0xFF0D2B5E)),
                  const SizedBox(width: 8),
                  Text('Code : $_shopCodePreview',
                      style: const TextStyle(
                          color: Color(0xFF0D2B5E),
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ]),
              ),
            ],
            const SizedBox(height: 14),
            _label('Description de la boutique'),
            TextFormField(
              controller: _descriptionCtrl,
              maxLines: 3,
              decoration: _deco('Décrivez votre boutique...',
                  Icons.description_outlined),
            ),
          ],
          const SizedBox(height: 24),
          _bouton('S\'inscrire', _inscription, auth.isLoading),
          const SizedBox(height: 12),
          _boutonGoogle(auth),
        ],
      ),
    );
  }

  // ── Petits widgets/utilitaires réutilisés dans les deux formulaires ──

  // Libellé au-dessus d'un champ de formulaire.
  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(t, style: const TextStyle(
        fontSize: 13, fontWeight: FontWeight.w600,
        color: Color(0xFF1A1F36))),
  );

  // Champ de texte générique avec icône, placeholder et validateur
  // optionnels — évite de dupliquer la configuration de TextFormField
  // pour chaque champ du formulaire.
  Widget _field(TextEditingController ctrl, String hint,
      {String? Function(String?)? validator,
       TextInputType? keyboardType,
       required IconData icon}) =>
      TextFormField(
        controller: ctrl,
        validator: validator,
        keyboardType: keyboardType,
        decoration: _deco(hint, icon),
      );

  // Décoration commune (bordures, couleurs, padding) appliquée à tous les
  // champs de saisie pour garder un style cohérent dans tout l'écran.
  InputDecoration _deco(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 13),
    prefixIcon: Icon(icon, size: 18, color: const Color(0xFF888888)),
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: Color(0xFF0D2B5E), width: 1.5)),
    errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: Color(0xFFE63946))),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
  );

  // Champ mot de passe : réutilise `_deco` puis ajoute une icône
  // "œil" (suffixIcon) permettant de basculer entre texte masqué/visible.
  Widget _passwordField() => TextFormField(
    controller: _passwordCtrl,
    obscureText: _obscurePassword,
    validator: _valPassword,
    decoration: _deco('Minimum 6 caractères', Icons.lock_outline).copyWith(
      suffixIcon: IconButton(
        icon: Icon(_obscurePassword ? Icons.visibility_off_outlined
            : Icons.visibility_outlined,
            size: 18, color: const Color(0xFF888888)),
        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
      ),
    ),
  );

  // Bouton d'action principal (pleine largeur). Affiche un indicateur de
  // chargement à la place du texte quand `loading` est vrai, et se
  // désactive automatiquement dans ce cas (onPressed: null) pour éviter
  // les doubles soumissions.
  Widget _bouton(String label, VoidCallback fn, bool loading) => SizedBox(
    width: double.infinity,
    height: 50,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0D2B5E),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      onPressed: loading ? null : fn,
      child: loading
          ? const SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2))
          : Text(label, style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.bold)),
    ),
  );

  // Bouton "Continuer avec Google" (connexion/inscription via OAuth
  // Google, déléguée à AuthProvider.signInWithGoogle). Désactivé pendant
  // un chargement en cours.
  Widget _boutonGoogle(AuthProvider auth) => SizedBox(
    width: double.infinity,
    height: 50,
    child: OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFFDDDDDD)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.white,
      ),
      icon: const Text('G', style: TextStyle(
          fontSize: 18, fontWeight: FontWeight.bold,
          color: Color(0xFF4285F4))),
      label: const Text('Continuer avec Google',
          style: TextStyle(color: Color(0xFF333333), fontSize: 14)),
      onPressed: auth.isLoading ? null : () => auth.signInWithGoogle(),
    ),
  );

  @override
  void dispose() {
    // Libération de tous les contrôleurs pour éviter les fuites mémoire
    // une fois l'écran retiré de l'arbre de widgets.
    _tabController.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nomCtrl.dispose();
    _telephoneCtrl.dispose();
    _adresseCtrl.dispose();
    _nomBoutiqueCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }
}
