import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/watch_data.dart';

// Loads and saves pet health data from Firebase.
class WatchDataService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Returns the most recent watch reading for the logged-in user.
  static Stream<WatchData?> getLatestWatchData() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);

    return _db
        .collection('users')
        .doc(uid)
        .collection('watchData')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      return WatchData.fromMap(doc.data(), doc.id);
    });
  }

  // Saves manually entered watch data to Firebase.
  static Future<void> saveWatchData(WatchData watchData) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _db.collection('users').doc(uid).collection('watchData').add({
      ...watchData.toMap(),
      'syncedAt': FieldValue.serverTimestamp(),
    });

    if (watchData.petId != null && watchData.steps != null) {
      await _db
          .collection('users')
          .doc(uid)
          .collection('pets')
          .doc(watchData.petId)
          .update({
        'lastSyncedAt': FieldValue.serverTimestamp(),
        'steps': watchData.steps,
      });
    }
  }
}
