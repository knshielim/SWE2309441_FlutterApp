import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/daily_summary.dart';

class DailySummaryService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // The last [days] daily summaries for a pet, oldest first.
  static Stream<List<DailySummary>> streamForPet(String petId, {int days = 60}) {
    final uid = _auth.currentUser?.uid;
    if (uid == null || petId.isEmpty) return Stream.value([]);

    return _db
        .collection('users')
        .doc(uid)
        .collection('pets')
        .doc(petId)
        .collection('dailyStats')
        .orderBy(FieldPath.documentId, descending: true)
        .limit(days)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DailySummary.fromMap(doc.data(), doc.id))
            .toList()
            .reversed
            .toList());
  }
}
