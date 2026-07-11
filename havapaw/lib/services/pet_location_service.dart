import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';

// Reads and updates pet GPS locations in Firebase.
class PetLocationService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Returns the latest location for one pet.
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

  // Saves a new location for one pet.
  static Future<void> updatePetLocation(String petId, LatLng location) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

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
  }

  // Returns when the pet location was last updated.
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
