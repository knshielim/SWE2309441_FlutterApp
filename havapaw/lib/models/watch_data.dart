class WatchData {
  final String? id;
  final String deviceId;
  final String deviceName;
  final int? steps;
  final int? heartRate;
  final double? distance; // in km
  final int? calories;
  final double? temperature;
  final int? batteryLevel; // 0-100
  final DateTime timestamp;
  final String? petId;
  final double? latitude;
  final double? longitude;

  WatchData({
    this.id,
    required this.deviceId,
    required this.deviceName,
    this.steps,
    this.heartRate,
    this.distance,
    this.calories,
    this.temperature,
    this.batteryLevel,
    required this.timestamp,
    this.petId,
    this.latitude,
    this.longitude,
  });

  // Converts this reading to a map for Firebase storage.
  Map<String, dynamic> toMap() {
    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'steps': steps,
      'heartRate': heartRate,
      'distance': distance,
      'calories': calories,
      'temperature': temperature,
      'batteryLevel': batteryLevel,
      'timestamp': timestamp.toIso8601String(),
      'petId': petId,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  // Creates a WatchData object from Firebase document data.
  factory WatchData.fromMap(Map<String, dynamic> map, String docId) {
    return WatchData(
      id: docId,
      deviceId: map['deviceId'] ?? '',
      deviceName: map['deviceName'] ?? 'Unknown Device',
      steps: map['steps'],
      heartRate: map['heartRate'],
      distance: map['distance']?.toDouble(),
      calories: map['calories'],
      temperature: map['temperature']?.toDouble(),
      batteryLevel: map['batteryLevel'],
      timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
      petId: map['petId'],
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
    );
  }
}
