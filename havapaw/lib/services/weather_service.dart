// Local weather from Open-Meteo (free, no API key) for the heat warning
import 'dart:convert';
import 'dart:io';
import 'package:geolocator/geolocator.dart';

class WeatherNow {
  final double airTempC;
  final double feelsLikeC;
  final int humidity;
  final DateTime fetchedAt;

  const WeatherNow({required this.airTempC, required this.feelsLikeC, required this.humidity, required this.fetchedAt});

  static WeatherNow? fromOpenMeteo(Map<String, dynamic> json, DateTime now) {
    final c = json['current'];
    if (c is! Map) return null;
    final t = (c['temperature_2m'] as num?)?.toDouble();
    final f = (c['apparent_temperature'] as num?)?.toDouble();
    final h = (c['relative_humidity_2m'] as num?)?.round();
    if (t == null || f == null || h == null) return null;
    return WeatherNow(airTempC: t, feelsLikeC: f, humidity: h, fetchedAt: now);
  }
}

class WeatherService {
  static const _cacheFor = Duration(minutes: 30);
  static WeatherNow? _cached;
  static String? _cachedPlace;

  // Uses the pet's last GPS fix, or else the phone's location
  static Future<WeatherNow?> current({double? latitude, double? longitude}) async {
    var lat = latitude, lng = longitude;
    if (lat == null || lng == null) {
      final pos = await _phonePosition();
      if (pos == null) return null;
      lat = pos.latitude;
      lng = pos.longitude;
    }
    final place = '${lat.toStringAsFixed(2)},${lng.toStringAsFixed(2)}';
    final now = DateTime.now();
    if (_cached != null && _cachedPlace == place && now.difference(_cached!.fetchedAt) < _cacheFor) {
      return _cached;
    }

    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': lat.toStringAsFixed(4),
      'longitude': lng.toStringAsFixed(4),
      'current': 'temperature_2m,relative_humidity_2m,apparent_temperature',
    });
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(uri);
      final response = await request.close().timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final body = await response.transform(utf8.decoder).join();
      final weather = WeatherNow.fromOpenMeteo(jsonDecode(body) as Map<String, dynamic>, now);
      if (weather != null) {
        _cached = weather;
        _cachedPlace = place;
      }
      return weather;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  static Future<Position?> _phonePosition() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return null;
      return await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low, timeLimit: const Duration(seconds: 10));
    } catch (_) {
      return null;
    }
  }
}
