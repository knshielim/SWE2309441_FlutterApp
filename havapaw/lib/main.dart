import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';
import 'services/selected_pet_service.dart';
import 'services/sound_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await EasyLocalization.ensureInitialized();

  await NotificationService.initialize();
  await SelectedPetService.loadSelectedPetId();
  await SoundService.init();
  
  final prefs = await SharedPreferences.getInstance();
  final savedLangCode = prefs.getString('language_code') ?? 'en';
  Locale initialLocale = const Locale('en', 'US');
  
  switch (savedLangCode) {
    case 'id':
      initialLocale = const Locale('id', 'ID');
      break;
    case 'ms':
      initialLocale = const Locale('ms', 'MY');
      break;
    case 'zh':
      initialLocale = const Locale('zh', 'CN');
      break;
    default:
      initialLocale = const Locale('en', 'US');
  }
  
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en', 'US'), Locale('id', 'ID'), Locale('ms', 'MY'), Locale('zh', 'CN')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en', 'US'),
      startLocale: initialLocale,
      child: const HavaPawApp(),
    ),
  );
}

class HavaPawApp extends StatelessWidget {
  const HavaPawApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HavaPaw',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFF0F9B8E)),
              ),
            );
          }
          if (snapshot.hasData) {
            return const HomeScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
