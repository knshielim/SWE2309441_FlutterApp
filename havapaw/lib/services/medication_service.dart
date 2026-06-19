import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/medication.dart';

class MedicationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get all medications for current user
  Stream<List<Medication>> getMedications() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);
    
    return _db
        .collection('users')
        .doc(uid)
        .collection('medications')
        .orderBy('startDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Medication.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Get medications for a specific pet
  Stream<List<Medication>> getMedicationsForPet(String petId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);
    
    return _db
        .collection('users')
        .doc(uid)
        .collection('medications')
        .where('petId', isEqualTo: petId)
        .orderBy('startDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Medication.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Add a new medication
  Future<void> addMedication(Medication medication) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    await _db
        .collection('users')
        .doc(uid)
        .collection('medications')
        .add(medication.toMap())
        .timeout(const Duration(seconds: 10));
  }

  // Update an existing medication
  Future<void> updateMedication(Medication medication) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || medication.id == null) return;
    
    await _db
        .collection('users')
        .doc(uid)
        .collection('medications')
        .doc(medication.id)
        .update(medication.toMap())
        .timeout(const Duration(seconds: 10));
  }

  // Delete a medication
  Future<void> deleteMedication(String medicationId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    await _db
        .collection('users')
        .doc(uid)
        .collection('medications')
        .doc(medicationId)
        .delete()
        .timeout(const Duration(seconds: 10));
  }

  // Toggle medication active status
  Future<void> toggleMedicationStatus(String medicationId, bool isActive) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    await _db
        .collection('users')
        .doc(uid)
        .collection('medications')
        .doc(medicationId)
        .update({'isActive': isActive})
        .timeout(const Duration(seconds: 10));
  }
}
