import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/geofence.dart';

// Handles adding, reading, updating, and deleting geofences.
class GeofenceService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String get _uid => _auth.currentUser!.uid;

  static CollectionReference get _geofencesRef =>
      _db.collection('users').doc(_uid).collection('geofences');

  // Adds a new geofence to Firebase.
  static Future<void> addGeofence(Geofence geofence) async {
    await _geofencesRef.add({
      ...geofence.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Returns geofences for one pet.
  static Stream<QuerySnapshot> getGeofencesForPetStream(String petId) {
    return _geofencesRef
        .where('petId', isEqualTo: petId)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Returns a list of geofences for one pet (convenience method).
  static Stream<List<Geofence>> getGeofencesForPet(String petId) {
    return getGeofencesForPetStream(petId).map((snapshot) => snapshot.docs
        .map((doc) => Geofence.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList());
  }

  // Updates an existing geofence.
  static Future<void> updateGeofence(
    String geofenceId,
    Map<String, dynamic> data,
  ) async {
    await _geofencesRef.doc(geofenceId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Deletes a geofence from Firebase.
  static Future<void> deleteGeofence(String geofenceId) async {
    await _geofencesRef.doc(geofenceId).delete();
  }

  // Turns a geofence on or off.
  static Future<void> toggleGeofenceStatus(String geofenceId, bool isActive) async {
    await _geofencesRef.doc(geofenceId).update({'isActive': isActive});
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
