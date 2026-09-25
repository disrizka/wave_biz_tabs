import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/login/login_screen.dart';
import 'screens/home/home_screen.dart';
// import 'services/fcm_service.dart'; // uncomment bareng blok init di bawah

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  HttpOverrides.global = MyHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Firebase + minta izin notifikasi & siapkan fcm_token
  // sebelum app dijalankan.
  // NONAKTIF DULU: butuh android/app/google-services.json (Android) dan
  // ios/Runner/GoogleService-Info.plist (iOS) yang belum di-setup.
  // Uncomment blok di bawah kalau Firebase sudah dikonfigurasi -- lihat
  // FCM_SETUP.md. Selama ini dikomen, ApiService otomatis fallback ke
  // fcm_token dummy saat login.
  // try {
  //   await FcmService.instance.initialize();
  // } catch (e) {
  //   debugPrint('[main] Gagal init FcmService: $e');
  // }

  runApp(const ProviderScope(child: WaveUpApp()));
}

class WaveUpApp extends StatelessWidget {
  const WaveUpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WAVEUP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF008080),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF008080)),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      initialRoute: '/splash',
      routes: {
        '/splash': (_) => const SplashScreen(),
        '/login': (_) => const LoginScreen(),
        '/home': (_) => const HomeScreen(),
      },
    );
  }
}
