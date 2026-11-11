import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/journal_entry.dart';

class JournalService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static DocumentReference<Map<String, dynamic>>? _user() {
    final uid = _auth.currentUser?.uid;
    return uid == null ? null : _db.collection('users').doc(uid);
  }

  static CollectionReference<Map<String, dynamic>>? _journal(String petId) =>
      petId.isEmpty ? null : _user()?.collection('pets').doc(petId).collection('journal');

  // Newest first
  static Stream<List<JournalEntry>> streamForPet(String petId, {int limit = 200}) {
    final col = _journal(petId);
    if (col == null) return Stream.value([]);
    return col
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => JournalEntry.fromMap(d.data(), d.id)).toList());
  }

  // The check-in already given for this reading, if any
  static Stream<JournalEntry?> checkInForReading(String petId, String readingId) {
    final col = _journal(petId);
    if (col == null) return Stream.value(null);
    return col.where('readingId', isEqualTo: readingId).limit(1).snapshots().map(
        (s) => s.docs.isEmpty ? null : JournalEntry.fromMap(s.docs.first.data(), s.docs.first.id));
  }

  static Future<void> add(JournalEntry entry) async {
    final col = _journal(entry.petId);
    if (col == null) return;
    await col.add(entry.toMap());
  }

  // Saves the owner's answer and tags the reading so it can be used as a labelled example
  static Future<void> addCheckIn(JournalEntry entry) async {
    final user = _user();
    final col = _journal(entry.petId);
    if (user == null || col == null) return;
    final batch = _db.batch();
    batch.set(col.doc(), entry.toMap());
    if (entry.readingId != null) {
      batch.set(user.collection('collarData').doc(entry.readingId), {'ownerContext': entry.tag},
          SetOptions(merge: true));
    }
    await batch.commit();
  }

  // Logs a weight and keeps the pet profile up to date
  static Future<void> addWeight(String petId, double kg) async {
    final user = _user();
    final col = _journal(petId);
    if (user == null || col == null) return;
    final batch = _db.batch();
    batch.set(col.doc(), JournalEntry(
      petId: petId,
      kind: JournalEntry.kindWeight,
      weightKg: kg,
      createdAt: DateTime.now(),
    ).toMap());
    batch.update(user.collection('pets').doc(petId), {'weight': kg});
    await batch.commit();
  }

  static Future<void> delete(String petId, String entryId) async {
    await _journal(petId)?.doc(entryId).delete();
  }
}
