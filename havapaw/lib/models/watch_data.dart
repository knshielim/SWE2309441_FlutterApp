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
  final String? petId; // Optional: associate with specific pet
  final double? latitude; // Pet's GPS latitude
  final double? longitude; // Pet's GPS longitude

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

  // Parse raw Bluetooth data from smartwatch
  // This is a generic parser - you'll need to customize based on your specific watch protocol
  static WatchData? parseBluetoothData(
    List<int> data,
    String deviceId,
    String deviceName,
    {String? petId}
  ) {
    try {
      // Example parsing logic - customize based on your watch's data protocol
      // This is a placeholder implementation
      
      if (data.isEmpty) return null;
      
      // Generic parsing example (adjust based on actual protocol)
      final timestamp = DateTime.now();
      
      // Parse based on expected data format
      // This is highly dependent on the specific smartwatch protocol
      int? steps;
      int? heartRate;
      double? distance;
      int? calories;
      double? temperature;
      
      // Example: If data is in specific byte positions
      if (data.length >= 8) {
        // This is just example logic - replace with actual protocol
        steps = (data[0] << 8) | data[1];
        heartRate = data[2];
        distance = ((data[3] << 8) | data[4]) / 100.0;
        calories = (data[5] << 8) | data[6];
        temperature = data[7] / 10.0;
      }
      
      return WatchData(
        deviceId: deviceId,
        deviceName: deviceName,
        steps: steps,
        heartRate: heartRate,
        distance: distance,
        calories: calories,
        temperature: temperature,
        timestamp: timestamp,
        petId: petId,
      );
    } catch (e) {
      return null;
    }
  }
}
