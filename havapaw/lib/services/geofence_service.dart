import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/geofence.dart';

class GeofenceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get all geofences for current user
  Stream<List<Geofence>> getGeofences() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);
    
    return _db
        .collection('users')
        .doc(uid)
        .collection('geofences')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Geofence.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Get geofences for a specific pet
  Stream<List<Geofence>> getGeofencesForPet(String petId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);
    
    return _db
        .collection('users')
        .doc(uid)
        .collection('geofences')
        .where('petId', isEqualTo: petId)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Geofence.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Add a new geofence
  Future<void> addGeofence(Geofence geofence) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    await _db
        .collection('users')
        .doc(uid)
        .collection('geofences')
        .add(geofence.toMap());
  }

  // Update an existing geofence
  Future<void> updateGeofence(Geofence geofence) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || geofence.id == null) return;
    
    await _db
        .collection('users')
        .doc(uid)
        .collection('geofences')
        .doc(geofence.id)
        .update(geofence.toMap());
  }

  // Delete a geofence
  Future<void> deleteGeofence(String geofenceId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    await _db
        .collection('users')
        .doc(uid)
        .collection('geofences')
        .doc(geofenceId)
        .delete();
  }

  // Toggle geofence active status
  Future<void> toggleGeofenceStatus(String geofenceId, bool isActive) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    await _db
        .collection('users')
        .doc(uid)
        .collection('geofences')
        .doc(geofenceId)
        .update({'isActive': isActive});
  }
}
