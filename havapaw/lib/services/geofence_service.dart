import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/geofence.dart';

// Manages safe zones (geofences) for pets.
class GeofenceService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Returns active geofences for one pet.
  static Stream<List<Geofence>> getGeofencesForPet(String petId) {
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

  // Saves a new geofence to Firebase.
  static Future<void> addGeofence(Geofence geofence) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _db
        .collection('users')
        .doc(uid)
        .collection('geofences')
        .add(geofence.toMap());
  }

  // Updates an existing geofence in Firebase.
  static Future<void> updateGeofence(Geofence geofence) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || geofence.id == null) return;

    await _db
        .collection('users')
        .doc(uid)
        .collection('geofences')
        .doc(geofence.id)
        .update(geofence.toMap());
  }

  // Deletes a geofence from Firebase.
  static Future<void> deleteGeofence(String geofenceId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _db
        .collection('users')
        .doc(uid)
        .collection('geofences')
        .doc(geofenceId)
        .delete();
  }

  // Turns a geofence on or off.
  static Future<void> toggleGeofenceStatus(String geofenceId, bool isActive) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _db
        .collection('users')
        .doc(uid)
        .collection('geofences')
        .doc(geofenceId)
        .update({'isActive': isActive});
  }

  // Checks if the pet is inside the geofence radius.
  static bool isPetWithinGeofence(LatLng petLocation, Geofence geofence) {
    final distance = Geolocator.distanceBetween(
      petLocation.latitude,
      petLocation.longitude,
      geofence.latitude,
      geofence.longitude,
    );
    return distance <= geofence.radius;
  }
}
