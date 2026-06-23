import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/pet.dart';

class PetService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String get _uid => _auth.currentUser!.uid;

  static CollectionReference get _petsRef =>
      _db.collection('users').doc(_uid).collection('pets');

  // Add a new pet (Create)
  static Future<void> addPet(Pet pet) async {
    try {
      await _petsRef.add({
        ...pet.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('Pet added');
    } catch (e) {
      print('Error adding pet: $e');
    }
  }

  // Read all pets (Stream for real-time updates)
  static Stream<QuerySnapshot> getPetsStream() {
    return _petsRef.orderBy('createdAt', descending: false).snapshots();
  }

  // Edit an existing pet (Update)
  static Future<void> updatePet(String petId, Map<String, dynamic> data) async {
    try {
      await _petsRef.doc(petId).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('Pet updated: $petId');
    } catch (e) {
      print('Error updating pet: $e');
    }
  }

  // Remove a pet (Delete)
  static Future<void> deletePet(String petId) async {
    try {
      await _petsRef.doc(petId).delete();
      print('Pet deleted: $petId');
    } catch (e) {
      print('Error deleting pet: $e');
    }
  }
}
