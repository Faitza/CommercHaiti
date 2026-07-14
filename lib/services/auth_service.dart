// ignore_for_file: avoid_print
// TODO Falexson : décommenter quand Firebase sera configuré
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:google_sign_in/google_sign_in.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';

/// Service authentification Firebase — Falexson MERCIVAL
/// Branch : feature/firebase-core
/// Path : lib/services/auth_service.dart
/// SEUL fichier qui parle à Firebase Auth
/// Ne jamais appeler depuis un Widget — toujours via AuthProvider
class AuthService {
  // ── Instance Firebase (décommenter après configuration) ──
  // final FirebaseAuth _auth = FirebaseAuth.instance;
  // final FirebaseFirestore _db = FirebaseFirestore.instance;
  // final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ════════════════════════════════════
  // CONNEXION EMAIL / MOT DE PASSE
  // ════════════════════════════════════
  Future<UserModel?> signIn(String email, String password) async {
    try {
      // TODO : décommenter quand Firebase sera configuré
      // final credential = await _auth.signInWithEmailAndPassword(
      //   email: email,
      //   password: password,
      // );
      // return await getUserFromFirestore(credential.user!.uid);

      // ── DONNÉES TEST (retirer quand Firebase sera prêt) ──
      await Future.delayed(const Duration(milliseconds: 800));
      return UserModel(
        uid: 'test_uid_${DateTime.now().millisecondsSinceEpoch}',
        nom: 'Test Utilisateur',
        telephone: '+50937000000',
        email: email,
        role: 'customer',
        createdAt: DateTime.now(),
      );
    } catch (e) {
      print('Erreur signIn: $e');
      rethrow;
    }
  }

  // ════════════════════════════════════
  // INSCRIPTION
  // ════════════════════════════════════
  Future<UserModel?> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> userData,
  }) async {
    try {
      // TODO :
      // final credential = await _auth.createUserWithEmailAndPassword(
      //   email: email,
      //   password: password,
      // );
      // final uid = credential.user!.uid;
      // await _db.collection('users').doc(uid).set({
      //   ...userData,
      //   'uid': uid,
      //   'createdAt': FieldValue.serverTimestamp(),
      // });
      // return await getUserFromFirestore(uid);

      // ── DONNÉES TEST ──
      await Future.delayed(const Duration(milliseconds: 800));
      return UserModel(
        uid: 'test_uid_${DateTime.now().millisecondsSinceEpoch}',
        nom: userData['nom'] ?? '',
        telephone: userData['telephone'] ?? '',
        email: email,
        role: userData['role'] ?? 'customer',
        adresse: userData['adresse'],
        shopCode: userData['shopCode'],
        createdAt: DateTime.now(),
      );
    } catch (e) {
      print('Erreur signUp: $e');
      rethrow;
    }
  }

  // ════════════════════════════════════
  // CONNEXION GOOGLE
  // ════════════════════════════════════
  Future<UserModel?> signInWithGoogle() async {
    try {
      // TODO :
      // final googleUser = await _googleSignIn.signIn();
      // if (googleUser == null) return null;
      // final googleAuth = await googleUser.authentication;
      // final credential = GoogleAuthProvider.credential(
      //   accessToken: googleAuth.accessToken,
      //   idToken: googleAuth.idToken,
      // );
      // final userCredential = await _auth.signInWithCredential(credential);
      // return await getUserFromFirestore(userCredential.user!.uid);

      // ── DONNÉES TEST ──
      await Future.delayed(const Duration(milliseconds: 800));
      return UserModel(
        uid: 'google_test_uid',
        nom: 'Utilisateur Google',
        telephone: '',
        email: 'google@test.com',
        role: 'customer',
        createdAt: DateTime.now(),
      );
    } catch (e) {
      print('Erreur signInWithGoogle: $e');
      rethrow;
    }
  }

  // ════════════════════════════════════
  // DÉCONNEXION
  // ════════════════════════════════════
  Future<void> signOut() async {
    // TODO :
    // await _googleSignIn.signOut();
    // await _auth.signOut();
    await Future.delayed(const Duration(milliseconds: 300));
  }

  // ════════════════════════════════════
  // RÉCUPÉRER UTILISATEUR FIRESTORE
  // ════════════════════════════════════
  Future<UserModel?> getUserFromFirestore(String uid) async {
    try {
      // TODO :
      // final doc = await _db.collection('users').doc(uid).get();
      // if (doc.exists) return UserModel.fromMap(doc.data()!);
      return null;
    } catch (e) {
      print('Erreur getUserFromFirestore: $e');
      return null;
    }
  }

  // ════════════════════════════════════
  // STREAM AUTH (écoute connexion/déconnexion)
  // ════════════════════════════════════
  // Stream<User?> get authStateChanges => _auth.authStateChanges();
}