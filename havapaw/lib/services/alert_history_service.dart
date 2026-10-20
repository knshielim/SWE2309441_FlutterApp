import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// One push alert saved by the server (users/{uid}/alerts, see sendPush in
// functions/index.js), with the owner's feedback on whether it was useful.
class AlertRecord {
  final String id;
  final String petId;
  final String type;
  final String title;
  final String body;
  final double severity;
  final DateTime? createdAt;
  final String? feedback; // 'useful' | 'not_useful' | null

  const AlertRecord({
    required this.id,
    required this.petId,
    required this.type,
    required this.title,
    required this.body,
    required this.severity,
    this.createdAt,
    this.feedback,
  });

  factory AlertRecord.fromMap(Map<String, dynamic> map, String id) {
    final created = map['createdAt'];
    return AlertRecord(
      id: id,
      petId: (map['petId'] ?? '').toString(),
      type: (map['type'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      body: (map['body'] ?? '').toString(),
      severity: (map['severity'] as num?)?.toDouble() ?? 0.5,
      createdAt: created is Timestamp ? created.toDate() : null,
      feedback: map['feedback'] as String?,
    );
  }
}

class AlertHistoryService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static CollectionReference<Map<String, dynamic>>? _alerts() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('alerts');
  }

  // The most recent alerts for the signed-in user, newest first.
  static Stream<List<AlertRecord>> streamAlerts({int limit = 100}) {
    final col = _alerts();
    if (col == null) return Stream.value([]);
    return col
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => AlertRecord.fromMap(d.data(), d.id)).toList());
  }

  // Records whether the owner found an alert useful (null clears it). Used to
  // measure alert relevance in the evaluation.
  static Future<void> setFeedback(String alertId, String? feedback) async {
    final col = _alerts();
    if (col == null) return;
    await col.doc(alertId).set({
      'feedback': feedback,
      'feedbackAt': feedback == null ? null : FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
