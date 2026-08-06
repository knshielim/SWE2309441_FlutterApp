import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/collar_data.dart';
import '../models/pet.dart';
import 'health_intelligence_service.dart';

// Emergency status levels
enum EmergencyLevel {
  none,
  warning,
  critical,
}

class EmergencyModeService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static bool _isEmergencyModeActive = false;
  static EmergencyLevel _currentEmergencyLevel = EmergencyLevel.none;

  static bool get isEmergencyModeActive => _isEmergencyModeActive;
  static EmergencyLevel get currentEmergencyLevel => _currentEmergencyLevel;

  // Initialize emergency mode service
  static Future<void> initialize() async {
    // Request notification permissions
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (kDebugMode) {
      print('Notification permission status: ${settings.authorizationStatus}');
    }

    // Subscribe to emergency topic
    await _messaging.subscribeToTopic('pet_emergency');
  }

  // Activate emergency mode
  static Future<void> activateEmergencyMode({
    required String petId,
    required EmergencyLevel level,
    required CollarData? currentData,
  }) async {
    _isEmergencyModeActive = true;
    _currentEmergencyLevel = level;

    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      // Update emergency status in Firestore
      await _db.collection('users').doc(uid).collection('pets').doc(petId).update({
        'emergencyMode': true,
        'emergencyLevel': level.name,
        'emergencyActivatedAt': FieldValue.serverTimestamp(),
        'lastKnownLocation': currentData != null
            ? {
                'latitude': currentData.latitude,
                'longitude': currentData.longitude,
                'timestamp': currentData.timestamp.toIso8601String(),
              }
            : null,
      });

      // Send emergency notification
      await _sendEmergencyNotification(petId, level, currentData);

      // Notify emergency contacts
      await _notifyEmergencyContacts(petId, level, currentData);
    } catch (e) {
      if (kDebugMode) print('Error activating emergency mode: $e');
    }
  }

  // Deactivate emergency mode
  static Future<void> deactivateEmergencyMode(String petId) async {
    _isEmergencyModeActive = false;
    _currentEmergencyLevel = EmergencyLevel.none;

    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _db.collection('users').doc(uid).collection('pets').doc(petId).update({
        'emergencyMode': false,
        'emergencyLevel': null,
        'emergencyDeactivatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) print('Error deactivating emergency mode: $e');
    }
  }

  // Check if emergency mode should be activated based on health alerts
  static Future<void> checkAndActivateEmergencyIfNeeded(
    String petId,
    Pet pet,
    CollarData currentData,
    List<CollarData> historicalData,
  ) async {
    final alerts = HealthIntelligenceService.generateHealthAlerts(
      currentData,
      pet,
      historicalData,
    );

    // Check for critical conditions
    final hasCriticalAlert = alerts.any((alert) => alert.severity >= 0.8);

    if (hasCriticalAlert && !_isEmergencyModeActive) {
      await activateEmergencyMode(
        petId: petId,
        level: EmergencyLevel.critical,
        currentData: currentData,
      );
    } else if (!hasCriticalAlert && _isEmergencyModeActive) {
      await deactivateEmergencyMode(petId);
    }
  }

  // Send emergency notification via FCM
  static Future<void> _sendEmergencyNotification(
    String petId,
    EmergencyLevel level,
    CollarData? currentData,
  ) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      // Get pet info
      final petDoc = await _db.collection('users').doc(uid).collection('pets').doc(petId).get();
      final petName = petDoc.data()?['name'] ?? 'Pet';

      // Create notification payload
      final message = {
        'notification': {
          'title': level == EmergencyLevel.critical ? '🚨 CRITICAL ALERT' : '⚠️ Warning',
          'body': 'Emergency mode activated for $petName. Please check immediately.',
        },
        'data': {
          'type': 'emergency',
          'petId': petId,
          'level': level.name,
          'timestamp': DateTime.now().toIso8601String(),
          if (currentData?.latitude != null) 'latitude': currentData!.latitude.toString(),
          if (currentData?.longitude != null) 'longitude': currentData!.longitude.toString(),
        },
        'topic': 'pet_emergency',
      };

      // Send to FCM (in production, this would go through your backend)
      if (kDebugMode) {
        print('Emergency notification payload: $message');
      }
    } catch (e) {
      if (kDebugMode) print('Error sending emergency notification: $e');
    }
  }

  // Notify emergency contacts
  static Future<void> _notifyEmergencyContacts(
    String petId,
    EmergencyLevel level,
    CollarData? currentData,
  ) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      // Get emergency contacts from user profile
      final userDoc = await _db.collection('users').doc(uid).get();
      final emergencyContacts = userDoc.data()?['emergencyContacts'] as List<dynamic>?;

      if (emergencyContacts == null || emergencyContacts.isEmpty) {
        if (kDebugMode) print('No emergency contacts configured');
        return;
      }

      // Get pet info
      final petDoc = await _db.collection('users').doc(uid).collection('pets').doc(petId).get();
      final petName = petDoc.data()?['name'] ?? 'Pet';

      // Create emergency alert document for each contact
      for (final contact in emergencyContacts) {
        await _db.collection('emergencyAlerts').add({
          'contactPhone': contact['phone'],
          'contactName': contact['name'],
          'petId': petId,
          'petName': petName,
          'ownerId': uid,
          'level': level.name,
          'location': currentData != null
              ? {
                  'latitude': currentData.latitude,
                  'longitude': currentData.longitude,
                }
              : null,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'sent',
        });

        if (kDebugMode) {
          print('Emergency alert sent to ${contact['name']} at ${contact['phone']}');
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error notifying emergency contacts: $e');
    }
  }

  // Share live GPS location
  static Future<void> shareLiveLocation(String petId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      // Get latest collar data with location
      final collarDataSnapshot = await _db
          .collection('users')
          .doc(uid)
          .collection('collarData')
          .where('petId', isEqualTo: petId)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (collarDataSnapshot.docs.isEmpty) return;

      final data = collarDataSnapshot.docs.first.data();
      final latitude = data['latitude'];
      final longitude = data['longitude'];

      if (latitude == null || longitude == null) return;

      // Update live location sharing status
      await _db.collection('users').doc(uid).collection('pets').doc(petId).update({
        'sharingLiveLocation': true,
        'liveLocationUpdatedAt': FieldValue.serverTimestamp(),
        'currentLocation': {
          'latitude': latitude,
          'longitude': longitude,
        },
      });

      if (kDebugMode) {
        print('Live location shared: $latitude, $longitude');
      }
    } catch (e) {
      if (kDebugMode) print('Error sharing live location: $e');
    }
  }

  // Stop sharing live location
  static Future<void> stopSharingLiveLocation(String petId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _db.collection('users').doc(uid).collection('pets').doc(petId).update({
        'sharingLiveLocation': false,
        'liveLocationStoppedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) print('Error stopping live location sharing: $e');
    }
  }

  // Get emergency status for a pet
  static Stream<Map<String, dynamic>> getEmergencyStatus(String petId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value({});

    return _db
        .collection('users')
        .doc(uid)
        .collection('pets')
        .doc(petId)
        .snapshots()
        .map((snapshot) {
      final data = snapshot.data();
      return {
        'emergencyMode': data?['emergencyMode'] ?? false,
        'emergencyLevel': data?['emergencyLevel'],
        'sharingLiveLocation': data?['sharingLiveLocation'] ?? false,
        'lastKnownLocation': data?['lastKnownLocation'],
      };
    });
  }
}
