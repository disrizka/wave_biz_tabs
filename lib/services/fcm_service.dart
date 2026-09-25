import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Handler notifikasi yang diterima saat aplikasi berada di background
/// atau sudah ditutup (terminated). Harus berupa top-level function
/// (bukan method di dalam class) karena dijalankan di isolate terpisah.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Pastikan Firebase sudah di-init di isolate background ini juga.
  await Firebase.initializeApp();
  debugPrint('[FCM][background] ${message.messageId} - ${message.data}');
}

/// Service tunggal (singleton) untuk semua urusan Firebase Cloud Messaging:
/// - inisialisasi Firebase
/// - minta izin notifikasi (Android 13+/iOS)
/// - ambil fcm_token buat dikirim ke endpoint login
/// - dengerin event onTokenRefresh
/// - nampilin local notification pas app di foreground
class FcmService {
  FcmService._internal();
  static final FcmService instance = FcmService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _cachedToken;
  bool _initialized = false;

  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundMessageSub;

  /// Callback opsional dipanggil tiap kali token FCM berubah
  /// (misal habis reinstall app, clear data, dsb). Provider/AuthNotifier
  /// bisa dengerin ini buat kirim ulang token terbaru ke backend.
  void Function(String newToken)? onTokenRefreshed;

  /// Panggil sekali di awal (biasanya di main.dart sebelum runApp),
  /// idempotent -> aman dipanggil berkali-kali.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('[FcmService] Firebase.initializeApp gagal: $e');
      // Tetap lanjut, siapa tahu sudah pernah di-init sebelumnya
      // (misal hot-restart di dev).
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _requestPermission();
    await _setupLocalNotifications();

    // Wajib buat iOS: pastikan APNs token sudah tersedia sebelum
    // FirebaseMessaging bisa ngasih FCM token.
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      String? apnsToken = await _messaging.getAPNSToken();
      var attempts = 0;
      while (apnsToken == null && attempts < 5) {
        await Future.delayed(const Duration(seconds: 1));
        apnsToken = await _messaging.getAPNSToken();
        attempts++;
      }
    }

    _foregroundMessageSub = FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
    );

    _tokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) {
      debugPrint('[FcmService] Token refreshed: $newToken');
      _cachedToken = newToken;
      onTokenRefreshed?.call(newToken);
    });
  }

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint(
      '[FcmService] Permission status: ${settings.authorizationStatus}',
    );
  }

  Future<void> _setupLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    await _localNotifications.initialize(initSettings);

    const channel = AndroidNotificationChannel(
      'wave_biz_default_channel',
      'General Notifications',
      description: 'Notifikasi umum dari WAVEUP',
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM][foreground] ${message.messageId} - ${message.data}');
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'wave_biz_default_channel',
          'General Notifications',
          channelDescription: 'Notifikasi umum dari WAVEUP',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// Ambil fcm_token buat dikirim ke body login. Dipanggil tepat sebelum
  /// hit endpoint /user/login. Fallback ke null kalau gagal (misal
  /// emulator tanpa Google Play Services, permission ditolak, dll) --
  /// ApiService akan otomatis pakai token dummy kalau null/kosong.
  Future<String?> getToken() async {
    if (!_initialized) {
      await initialize();
    }
    try {
      _cachedToken ??= await _messaging.getToken();
      return _cachedToken;
    } catch (e) {
      debugPrint('[FcmService] Gagal ambil FCM token: $e');
      return null;
    }
  }

  /// Hapus token dari Firebase (dipanggil pas logout) supaya device ini
  /// nggak lagi nerima push notification untuk akun yang baru logout.
  Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
      _cachedToken = null;
    } catch (e) {
      debugPrint('[FcmService] Gagal hapus FCM token: $e');
    }
  }

  void dispose() {
    _tokenRefreshSub?.cancel();
    _foregroundMessageSub?.cancel();
  }
}
