import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/medication.dart';

// Handles adding, reading, updating, and deleting medications.
class MedicationService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String get _uid => _auth.currentUser!.uid;

  static CollectionReference get _medicationsRef =>
      _db.collection('users').doc(_uid).collection('medications');

  // Adds a new medication to Firebase.
  static Future<void> addMedication(Medication medication) async {
    await _medicationsRef.add({
      ...medication.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Returns medications for one pet.
  static Stream<QuerySnapshot> getMedicationsForPetStream(String petId) {
    return _medicationsRef.where('petId', isEqualTo: petId).snapshots();
  }

  // Updates an existing medication.
  static Future<void> updateMedication(
    String medicationId,
    Map<String, dynamic> data,
  ) async {
    await _medicationsRef.doc(medicationId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Deletes a medication from Firebase.
  static Future<void> deleteMedication(String medicationId) async {
    await _medicationsRef.doc(medicationId).delete();
  }

  // Turns a medication reminder on or off.
  static Future<void> toggleMedicationStatus(
    String medicationId,
    bool isActive,
  ) async {
    await _medicationsRef.doc(medicationId).update({'isActive': isActive});
  }
}
