import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/pet.dart';

class PetService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  CollectionReference get _petsRef =>
      _db.collection('users').doc(_uid).collection('pets');

  // CREATE — Add a new pet
  Future<void> addPet(Pet pet) async {
    await _petsRef.add(pet.toMap());
  }

  // READ — Stream all pets (live updates)
  Stream<List<Pet>> getPets() {
    return _petsRef
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Pet.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  // UPDATE — Edit an existing pet
  Future<void> updatePet(Pet pet) async {
    await _petsRef.doc(pet.id).update({
      'name': pet.name,
      'type': pet.type,
      'breed': pet.breed,
      'birthday': pet.birthday,
      'weight': pet.weight,
      'length': pet.length,
      'height': pet.height,
      'collarId': pet.collarId,
      'imageBase64': pet.imageBase64,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // DELETE — Remove a pet
  Future<void> deletePet(String petId) async {
    await _petsRef.doc(petId).delete();
  }
}
