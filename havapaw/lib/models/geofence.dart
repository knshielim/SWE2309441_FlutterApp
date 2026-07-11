class Geofence {
  final String? id;
  final String petId;
  final String name;
  final double latitude;
  final double longitude;
  final double radius; // in meters
  final bool isActive;
  final DateTime createdAt;

  Geofence({
    this.id,
    required this.petId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radius,
    this.isActive = true,
    required this.createdAt,
  });

  // Converts this geofence to a map for Firebase storage.
  Map<String, dynamic> toMap() {
    return {
      'petId': petId,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Creates a Geofence from Firebase document data.
  factory Geofence.fromMap(Map<String, dynamic> map, String docId) {
    return Geofence(
      id: docId,
      petId: map['petId'] ?? '',
      name: map['name'] ?? 'Safe Zone',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      radius: (map['radius'] ?? 100.0).toDouble(),
      isActive: map['isActive'] ?? true,
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}
