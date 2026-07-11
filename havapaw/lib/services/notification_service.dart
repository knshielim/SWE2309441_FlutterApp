import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../firebase_options.dart';

const AndroidNotificationChannel _androidChannel = AndroidNotificationChannel(
  'havapaw_channel',
  'HavaPaw Notifications',
  description: 'Notifications from HavaPaw app',
  importance: Importance.max,
);

// Handles push notifications received while the app is in the background.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

// Sets up Firebase and local notifications.
class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static String? fcmToken;

  // Initializes notification permissions and listeners.
  static Future<void> initialize() async {
    await _requestPermissions();
    await _initializeLocalNotifications();
    await _getFCMToken();

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
    FirebaseMessaging.instance.getInitialMessage().then(_handleInitialMessage);
  }

  // Asks the user for notification permission.
  static Future<void> _requestPermissions() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  // Sets up local notification settings for Android and iOS.
  static Future<void> _initializeLocalNotifications() async {
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (_) {},
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_androidChannel);
  }

  // Gets the Firebase Cloud Messaging token for this device.
  static Future<void> _getFCMToken() async {
    try {
      fcmToken = await _messaging.getToken();
      _messaging.onTokenRefresh.listen((newToken) {
        fcmToken = newToken;
      });
    } catch (_) {
      // Token may not be available on all platforms during development.
    }
  }

  // Shows a local notification when a push message arrives in the foreground.
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    await _showLocalNotification(
      title: message.notification?.title ?? 'New Notification',
      body: message.notification?.body ?? '',
      payload: message.data.toString(),
    );
  }

  // Runs when the user opens the app from a notification.
  static void _handleMessageOpenedApp(RemoteMessage message) {}

  // Runs when the app was opened from a terminated state via notification.
  static void _handleInitialMessage(RemoteMessage? message) {}

  // Displays a notification on the device.
  static Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'havapaw_channel',
        'HavaPaw Notifications',
        channelDescription: 'Notifications from HavaPaw app',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }
}
