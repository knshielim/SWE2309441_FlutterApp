import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/watch_data.dart';

class WatchDataService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get all watch data for current user
  Stream<List<WatchData>> getWatchData() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);
    
    return _db
        .collection('users')
        .doc(uid)
        .collection('watchData')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WatchData.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Get latest watch data
  Stream<WatchData?> getLatestWatchData() {
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
      return WatchData.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id);
    });
  }

  // Get watch data for a specific pet
  Stream<List<WatchData>> getWatchDataForPet(String petId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);
    
    return _db
        .collection('users')
        .doc(uid)
        .collection('watchData')
        .where('petId', isEqualTo: petId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WatchData.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Get watch data for a time range (for charts)
  Stream<List<WatchData>> getWatchDataForTimeRange(DateTime start, DateTime end) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);
    
    return _db
        .collection('users')
        .doc(uid)
        .collection('watchData')
        .where('timestamp', isGreaterThanOrEqualTo: start.toIso8601String())
        .where('timestamp', isLessThanOrEqualTo: end.toIso8601String())
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WatchData.fromMap(doc.data(), doc.id))
            .toList());
  }
}
