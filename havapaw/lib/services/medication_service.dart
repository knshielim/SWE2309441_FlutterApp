import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/medication.dart';

class MedicationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  CollectionReference get _medicationsRef =>
      _db.collection('users').doc(_uid).collection('medications');

  // Add a new medication (Create)
  Future<void> addMedication(Medication medication) async {
    await _medicationsRef.add({
      ...medication.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Read all medications (Stream for real-time updates)
  Stream<QuerySnapshot> getMedicationsStream() {
    return _medicationsRef.orderBy('startDate', descending: true).snapshots();
  }

  // Read medications for a specific pet (Stream for real-time updates)
  Stream<QuerySnapshot> getMedicationsForPetStream(String petId) {
    return _medicationsRef
        .where('petId', isEqualTo: petId)
        .orderBy('startDate', descending: true)
        .snapshots();
  }

  // Edit an existing medication (Update)
  Future<void> updateMedication(String medicationId, Map<String, dynamic> data) async {
    await _medicationsRef.doc(medicationId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Remove a medication (Delete)
  Future<void> deleteMedication(String medicationId) async {
    await _medicationsRef.doc(medicationId).delete();
  }

  // Toggle medication active status
  Future<void> toggleMedicationStatus(String medicationId, bool isActive) async {
    await _medicationsRef.doc(medicationId).update({'isActive': isActive});
  }
}
