import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/collar_data.dart';

// Service for managing pet collar health and location data
class CollarDataService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Returns the most recent collar reading for a specific pet
  static Stream<CollarData?> getLatestCollarDataForPet(String petId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);

    debugPrint('getLatestCollarDataForPet: Querying for petId=$petId, uid=$uid');

    return _db
        .collection('users')
        .doc(uid)
        .collection('collarData')
        .where('petId', isEqualTo: petId)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
      debugPrint('getLatestCollarDataForPet: Snapshot has ${snapshot.docs.length} docs, fromCache=${snapshot.metadata.isFromCache}');
      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      final data = CollarData.fromMap(doc.data(), doc.id);
      debugPrint('getLatestCollarDataForPet: Returning data with petId=${data.petId}, fromCache=${snapshot.metadata.isFromCache}');
      // Only return data if it's from server or if it matches the expected petId
      if (!snapshot.metadata.isFromCache || data.petId == petId) {
        return data;
      }
      return null;
    });
  }

  // Returns the most recent collar reading for the logged-in user
  static Stream<CollarData?> getLatestCollarData() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);

    return _db
        .collection('users')
        .doc(uid)
        .collection('collarData')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      return CollarData.fromMap(doc.data(), doc.id);
    });
  }

  // Saves manually entered collar data to Firebase
  static Future<void> saveCollarData(CollarData collarData) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final dataToSave = {
      ...collarData.toMap(),
      'syncedAt': FieldValue.serverTimestamp(),
    };
    debugPrint('Saving to Firestore: $dataToSave');

    await _db.collection('users').doc(uid).collection('collarData').add(dataToSave);
  }

  // Returns collar data for a specific pet
  static Stream<List<CollarData>> getCollarDataForPet(String petId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    return _db
        .collection('users')
        .doc(uid)
        .collection('collarData')
        .where('petId', isEqualTo: petId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => CollarData.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // Returns collar data within a time range
  static Stream<List<CollarData>> getCollarDataInRange(DateTime start, DateTime end) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    return _db
        .collection('users')
        .doc(uid)
        .collection('collarData')
        .where('timestamp', isGreaterThanOrEqualTo: start.toIso8601String())
        .where('timestamp', isLessThanOrEqualTo: end.toIso8601String())
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => CollarData.fromMap(doc.data(), doc.id))
          .toList();
    });
  }
}
