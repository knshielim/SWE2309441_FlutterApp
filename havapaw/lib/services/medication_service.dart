import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/medication.dart';

class MedicationService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String get _uid => _auth.currentUser!.uid;

  static CollectionReference get _medicationsRef =>
      _db.collection('users').doc(_uid).collection('medications');

  // Add a new medication (Create)
  static Future<void> addMedication(Medication medication) async {
    try {
      await _medicationsRef.add({
        ...medication.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('Medication added');
    } catch (e) {
      print('Error adding medication: $e');
    }
  }

  // Read all medications (Retrieve)
  static Stream<QuerySnapshot> getMedicationsStream() {
    return _medicationsRef.orderBy('startDate', descending: true).snapshots();
  }

  // Read medications for a specific pet (Retrieve)
  static Stream<QuerySnapshot> getMedicationsForPetStream(String petId) {
    return _medicationsRef.where('petId', isEqualTo: petId).snapshots();
  }

  // Edit an existing medication (Update)
  static Future<void> updateMedication(
    String medicationId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _medicationsRef.doc(medicationId).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('Medication updated: $medicationId');
    } catch (e) {
      print('Error updating medication: $e');
    }
  }

  // Remove a medication (Delete)
  static Future<void> deleteMedication(String medicationId) async {
    try {
      await _medicationsRef.doc(medicationId).delete();
      print('Medication deleted: $medicationId');
    } catch (e) {
      print('Error deleting medication: $e');
    }
  }

  // Toggle medication active status
  static Future<void> toggleMedicationStatus(
    String medicationId,
    bool isActive,
  ) async {
    try {
      await _medicationsRef.doc(medicationId).update({'isActive': isActive});
      print('Medication status updated: $medicationId');
    } catch (e) {
      print('Error updating medication status: $e');
    }
  }
}
