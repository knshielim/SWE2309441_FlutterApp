import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/pet.dart';

class PetService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  CollectionReference get _petsRef =>
      _db.collection('users').doc(_uid).collection('pets');

  // Add a new pet (Create)
  Future<void> addPet(Pet pet) async {
    await _petsRef.add({
      ...pet.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Read all pets (Stream for real-time updates)
  Stream<QuerySnapshot> getPetsStream() {
    return _petsRef.orderBy('createdAt', descending: false).snapshots();
  }

  // Edit an existing pet (Update)
  Future<void> updatePet(String petId, Map<String, dynamic> data) async {
    await _petsRef.doc(petId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Remove a pet (Delete)
  Future<void> deletePet(String petId) async {
    await _petsRef.doc(petId).delete();
  }
}
