import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';

// Reads and updates pet GPS locations in Firebase.
class PetLocationService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Returns the latest location for one pet from collar data only
  static Stream<LatLng?> getPetLocation(String petId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);

    return _db
        .collection('users')
        .doc(uid)
        .collection('collarData')
        .where('petId', isEqualTo: petId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      // Filter for entries with valid GPS coordinates
      final locationData = snapshot.docs
          .map((doc) => doc.data())
          .where((data) {
            final lat = (data['latitude'] as num?)?.toDouble();
            final lng = (data['longitude'] as num?)?.toDouble();
            return lat != null && lng != null && lat.isFinite && lng.isFinite;
          })
          .toList();
      
      if (locationData.isEmpty) return null;
      final data = locationData.first;
      final lat = (data['latitude'] as num).toDouble();
      final lng = (data['longitude'] as num).toDouble();
      return LatLng(lat, lng);
    });
  }

  // Returns when the pet location was last updated from collar data
  static Stream<DateTime?> getLocationTimestamp(String petId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);

    return _db
        .collection('users')
        .doc(uid)
        .collection('collarData')
        .where('petId', isEqualTo: petId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      // Filter for entries with valid GPS coordinates
      final locationData = snapshot.docs
          .map((doc) => doc.data())
          .where((data) {
            final lat = (data['latitude'] as num?)?.toDouble();
            final lng = (data['longitude'] as num?)?.toDouble();
            return lat != null && lng != null && lat.isFinite && lng.isFinite;
          })
          .toList();
      
      if (locationData.isEmpty) return null;
      final data = locationData.first;
      // The collar's ingest function stores an ISO-8601 string; older
      // documents may hold a Firestore Timestamp.
      final timestamp = data['timestamp'];
      if (timestamp is Timestamp) return timestamp.toDate();
      if (timestamp is String) return DateTime.tryParse(timestamp);
      return null;
    });
  }
}
