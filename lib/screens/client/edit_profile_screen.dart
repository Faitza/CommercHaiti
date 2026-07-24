import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';

/// Modifier profil client — Informations personnelles + Adresse
/// Path : lib/screens/client/edit_profile_screen.dart
///
/// Ekran sa a pèmèt kliyan konekte a modifye enfòmasyon pwofil li :
/// non, telefòn ak adrès prensipal. Chan yo pre-ranpli avèk done ki
/// deja nan AuthProvider, epi anrejistreman an fèt atravè
/// DatabaseService ki ekri nan baz done a (Supabase/Postgres).
///
/// Cet écran permet au client connecté de modifier les informations de
/// son profil : nom, téléphone et adresse principale. Les champs sont
/// pré-remplis avec les données déjà présentes dans AuthProvider, et
/// l'enregistrement se fait via DatabaseService qui écrit dans la base
/// de données (Supabase/Postgres).
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // Clé du formulaire, utilisée pour déclencher la validation de tous
  // les TextFormField d'un coup (via _formKey.currentState.validate()).
  final _formKey = GlobalKey<FormState>();
  // Service centralisant les appels de lecture/écriture vers la base de
  // données (encapsule les appels Supabase).
  final _db = DatabaseService();
  // Contrôleurs de texte : chacun garde en mémoire le texte tapé dans
  // le champ correspondant et permet de le pré-remplir/le lire.
  final _nomCtrl = TextEditingController();
  final _telephoneCtrl = TextEditingController();
  final _adresseCtrl = TextEditingController();
  // Indique si un enregistrement est en cours, pour désactiver le
  // bouton et afficher un petit spinner pendant l'appel réseau.
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Récupère l'utilisateur actuellement connecté (déjà chargé en
    // mémoire dans AuthProvider, pas de nouvel appel réseau ici) et
    // pré-remplit les champs du formulaire avec ses valeurs actuelles.
    // L'opérateur ?? '' évite un texte "null" si un champ n'a jamais
    // été renseigné.
    final user = context.read<AuthProvider>().currentUser;
    _nomCtrl.text = user?.nom ?? '';
    _telephoneCtrl.text = user?.telephone ?? '';
    _adresseCtrl.text = user?.adresse ?? '';
  }

  /// Valide le formulaire puis enregistre les nouvelles informations de
  /// profil en base de données, avant de rafraîchir l'utilisateur en
  /// mémoire et de fermer l'écran.
  Future<void> _enregistrer() async {
    // Déclenche les validateurs de chaque TextFormField ; si un champ
    // requis est vide, on arrête ici sans rien enregistrer.
    if (!_formKey.currentState!.validate()) return;
    final uid = context.read<AuthProvider>().currentUser?.id;
    // Sécurité : si jamais aucun utilisateur n'est connecté (uid null),
    // on annule l'enregistrement plutôt que de planter.
    if (uid == null) return;
    setState(() => _isSaving = true);
    try {
      // Met à jour la ligne "users" correspondant à cet uid avec les
      // nouvelles valeurs (trim() enlève les espaces avant/après).
      await _db.updateUser(uid, {
        'nom': _nomCtrl.text.trim(),
        'telephone': _telephoneCtrl.text.trim(),
        'adresse': _adresseCtrl.text.trim(),
      });
      // "mounted" vérifie que le widget est toujours affiché avant
      // d'utiliser son BuildContext après un await — évite une erreur
      // si l'utilisateur a quitté l'écran pendant l'appel réseau.
      if (mounted) {
        // Recharge l'utilisateur courant dans AuthProvider pour que le
        // reste de l'app (ex. écran profil) affiche immédiatement les
        // nouvelles informations, sans attendre un redémarrage de
        // l'app.
        await context.read<AuthProvider>().refreshCurrentUser();
      }
      // Ferme cet écran et revient à l'écran précédent (le profil).
      if (mounted) Navigator.pop(context);
    } catch (e) {
      // En cas d'échec (réseau, permissions Supabase, etc.), affiche un
      // message d'erreur temporaire (SnackBar) plutôt que de fermer
      // l'écran silencieusement.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : ${e.toString()}'),
          backgroundColor: const Color(0xFFE63946),
        ));
      }
    } finally {
      // Quoi qu'il arrive (succès ou erreur), on réactive le bouton en
      // repassant _isSaving à false, sauf si l'écran a déjà été fermé.
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B5E),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          // pop() : simple retour à l'écran précédent, sans modifier le
          // profil (annulation implicite si aucune sauvegarde n'a eu
          // lieu).
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Mon profil'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Champ Nom complet (obligatoire, validateur simple :
              // non vide).
              const Text('Nom complet *',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nomCtrl,
                validator: (v) => v == null || v.isEmpty ? 'Nom requis' : null,
              ),
              const SizedBox(height: 16),
              // Champ Téléphone (obligatoire, clavier numérique adapté
              // via keyboardType: TextInputType.phone).
              const Text('Téléphone *',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _telephoneCtrl,
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Téléphone requis' : null,
              ),
              const SizedBox(height: 16),
              // Champ Adresse (obligatoire, sur 2 lignes maximum pour
              // laisser un peu de place à une adresse plus longue).
              const Text('Adresse principale *',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _adresseCtrl,
                maxLines: 2,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Adresse requise' : null,
              ),
              const SizedBox(height: 32),
              // Bouton Enregistrer : désactivé (onPressed: null) pendant
              // la sauvegarde pour éviter les doubles soumissions, et
              // remplace son texte par un petit indicateur de
              // chargement le temps de l'appel réseau.
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D2B5E),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isSaving ? null : _enregistrer,
                  child: _isSaving
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Enregistrer',
                          style: TextStyle(color: Colors.white,
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Libère les contrôleurs de texte quand l'écran est détruit, pour
    // éviter les fuites mémoire (bonne pratique Flutter systématique
    // avec TextEditingController).
    _nomCtrl.dispose();
    _telephoneCtrl.dispose();
    _adresseCtrl.dispose();
    super.dispose();
  }
}
