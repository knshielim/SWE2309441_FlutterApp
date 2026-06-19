import 'dart:math' as math;

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

  // Check if a point is within the geofence
  bool containsPoint(double lat, double lng) {
    final distance = _calculateDistance(latitude, longitude, lat, lng);
    return distance <= radius;
  }

  // Calculate distance between two points in meters using Haversine formula
  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371000; // Earth's radius in meters
    
    final double dLat = _toRadians(lat2 - lat1);
    final double dLng = _toRadians(lng2 - lng1);
    
    final double a = 
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLng / 2) * math.sin(dLng / 2);
    
    final double c = 2 * math.asin(math.sqrt(a));
    
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * math.pi / 180;
  }
}
