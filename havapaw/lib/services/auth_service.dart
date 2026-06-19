import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Register with email & password
  Future<UserCredential?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    // Save user profile to Firestore
    await _db.collection('users').doc(cred.user!.uid).set({
      'name': name,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await cred.user!.updateDisplayName(name);
    return cred;
  }

  // Login
  Future<UserCredential?> login({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Get user display name from Firestore
  Future<String> getUserName() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return '';
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data()?['name'] ?? '';
  }

  // Update user profile
  Future<void> updateProfile({required String name}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).update({'name': name});
    await _auth.currentUser!.updateDisplayName(name);
  }
}
