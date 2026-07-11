import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';

class PetLocationService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get pet location for a specific pet
  static Stream<LatLng?> getPetLocation(String petId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);

    return _db
        .collection('users')
        .doc(uid)
        .collection('pets')
        .doc(petId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      final data = snapshot.data();
      if (data == null) return null;
      final lat = data['latitude'] as double?;
      final lng = data['longitude'] as double?;
      if (lat == null || lng == null) return null;
      return LatLng(lat, lng);
    });
  }

  // Update pet location
  static Future<void> updatePetLocation(String petId, LatLng location) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('pets')
          .doc(petId)
          .update({
            'latitude': location.latitude,
            'longitude': location.longitude,
            'locationUpdatedAt': FieldValue.serverTimestamp(),
          });
      print('Pet location updated: $petId');
    } catch (e) {
      print('Error updating pet location: $e');
    }
  }

  // Get last known location timestamp
  static Stream<DateTime?> getLocationTimestamp(String petId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);

    return _db
        .collection('users')
        .doc(uid)
        .collection('pets')
        .doc(petId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      final data = snapshot.data();
      if (data == null) return null;
      final timestamp = data['locationUpdatedAt'] as Timestamp?;
      if (timestamp == null) return null;
      return timestamp.toDate();
    });
  }
}
