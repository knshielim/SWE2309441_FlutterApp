import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/pet.dart';

// Handles adding, reading, updating, and deleting pets.
class PetService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String get _uid => _auth.currentUser!.uid;

  static CollectionReference get _petsRef =>
      _db.collection('users').doc(_uid).collection('pets');

  // Adds a new pet to Firebase.
  static Future<void> addPet(Pet pet) async {
    await _petsRef.add({
      ...pet.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Returns a live stream of all pets for the current user.
  static Stream<QuerySnapshot> getPetsStream() {
    return _petsRef.orderBy('createdAt', descending: false).snapshots();
  }

  // Updates an existing pet's details.
  static Future<void> updatePet(String petId, Map<String, dynamic> data) async {
    await _petsRef.doc(petId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Deletes a pet from Firebase.
  static Future<void> deletePet(String petId) async {
    await _petsRef.doc(petId).delete();
  }
}
