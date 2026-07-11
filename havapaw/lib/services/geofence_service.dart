import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math';
import '../models/geofence.dart';

class GeofenceService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get all geofences for current user
  static Stream<List<Geofence>> getGeofences() {
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

  // Add a new geofence (Create)
  static Future<void> addGeofence(Geofence geofence) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('geofences')
          .add(geofence.toMap());
      print('Geofence added');
    } catch (e) {
      print('Error adding geofence: $e');
    }
  }

  // Update an existing geofence (Update)
  static Future<void> updateGeofence(Geofence geofence) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || geofence.id == null) return;

    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('geofences')
          .doc(geofence.id)
          .update(geofence.toMap());
      print('Geofence updated: ${geofence.id}');
    } catch (e) {
      print('Error updating geofence: $e');
    }
  }

  // Delete a geofence (Delete)
  static Future<void> deleteGeofence(String geofenceId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('geofences')
          .doc(geofenceId)
          .delete();
      print('Geofence deleted: $geofenceId');
    } catch (e) {
      print('Error deleting geofence: $e');
    }
  }

  // Toggle geofence active status
  static Future<void> toggleGeofenceStatus(String geofenceId, bool isActive) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('geofences')
          .doc(geofenceId)
          .update({'isActive': isActive});
      print('Geofence status updated: $geofenceId');
    } catch (e) {
      print('Error updating geofence status: $e');
    }
  }

  // Calculate distance between two points in meters using Haversine formula
  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // Earth's radius in meters
    final double dLat = (lat2 - lat1) * pi / 180;
    final double dLon = (lon2 - lon1) * pi / 180;
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
        sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  // Check if pet is within geofence radius
  static bool isPetWithinGeofence(LatLng petLocation, Geofence geofence) {
    final distance = calculateDistance(
      petLocation.latitude,
      petLocation.longitude,
      geofence.latitude,
      geofence.longitude,
    );
    return distance <= geofence.radius;
  }
}
