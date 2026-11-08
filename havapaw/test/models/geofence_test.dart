import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:havapaw/models/geofence.dart';

void main() {
  final base = {'petId': 'p1', 'name': 'Home', 'latitude': 2.83, 'longitude': 101.7, 'radius': 50, 'isActive': true};

  test('reads a zone saved with a Firestore server timestamp', () {
    final g = Geofence.fromMap({...base, 'createdAt': Timestamp.fromDate(DateTime(2026, 11, 8, 10))}, 'z1');
    expect(g.createdAt, DateTime(2026, 11, 8, 10));
    expect(g.radius, 50.0);
  });

  test('reads an older zone saved with an ISO string', () {
    final g = Geofence.fromMap({...base, 'createdAt': '2026-10-01T09:00:00.000'}, 'z2');
    expect(g.createdAt, DateTime(2026, 10, 1, 9));
  });

  test('a zone still waiting for its server timestamp does not crash', () {
    expect(Geofence.fromMap({...base, 'createdAt': null}, 'z3').name, 'Home');
  });
}
