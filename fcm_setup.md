# Integrasi FCM Token ke Login — Setup Guide

Repo ini sudah aku ubah supaya `fcm_token` di request login (`POST /user/login`)
otomatis diisi dari Firebase Cloud Messaging, bukan lagi token dummy.

## Apa yang berubah di kode

| File | Perubahan |
|---|---|
| `pubspec.yaml` | Tambah `firebase_core`, `firebase_messaging`, `flutter_local_notifications` |
| `lib/services/fcm_service.dart` | **Baru.** Init Firebase, minta izin notifikasi, ambil & refresh `fcm_token`, tampilkan local notification saat foreground |
| `lib/providers/auth_provider.dart` | `login()` sekarang ambil `FcmService.instance.getToken()` dulu sebelum hit API; `logout()` hapus token FCM dari device |
| `lib/main.dart` | Panggil `FcmService.instance.initialize()` sebelum `runApp()` |
| `android/settings.gradle.kts`, `android/app/build.gradle.kts` | Apply plugin `com.google.gms.google-services`, `minSdk` dinaikkan ke 23 |
| `android/app/src/main/AndroidManifest.xml` | Meta-data default notification channel & icon |
| `ios/Runner/Info.plist` | `UIBackgroundModes` (`fetch`, `remote-notification`) + `FirebaseAppDelegateProxyEnabled` |
| `.gitignore` | File config Firebase (`google-services.json`, dst) di-ignore |

`lib/services/api_service.dart` **tidak diubah** — parameter `fcmToken` di
method `login()` sudah ada dari sananya, cuma sekarang beneran diisi token
asli, bukan `'dummy-fcm-token-belum-setup-firebase'`.

## Yang HARUS kamu lakukan sendiri (nggak bisa di-generate otomatis)

File konfigurasi Firebase itu unik per-project dan berisi API key akun
Firebase kamu, jadi aku nggak bisa generate-in asal-asalan. Langkahnya:

### 1. Buat project Firebase
1. Buka [Firebase Console](https://console.firebase.google.com) → **Add project**.
2. Boleh pakai nama apa aja, mis. `wave-biz-tabs`.

### 2. Daftarin app Android
1. Di project itu, klik **Add app → Android**.
2. **Android package name**: `com.wave.up.pos` (harus persis sama, lihat `android/app/build.gradle.kts`).
3. Download `google-services.json`, taruh di:
   ```
   android/app/google-services.json
   ```
4. Selesai, nggak perlu tempel snippet Gradle manual — sudah aku siapin di `settings.gradle.kts` & `android/app/build.gradle.kts`.

### 3. Daftarin app iOS
1. Di project yang sama, klik **Add app → iOS**.
2. **iOS bundle ID**: `com.wave.up.pos` (lihat `PRODUCT_BUNDLE_IDENTIFIER` di Xcode project).
3. Download `GoogleService-Info.plist`, taruh di:
   ```
   ios/Runner/GoogleService-Info.plist
   ```
4. Buka `ios/Runner.xcworkspace` di Xcode, drag file itu ke folder **Runner** (centang "Copy items if needed" & target **Runner**) supaya ke-bundle ke app.
5. Di Xcode → target **Runner** → tab **Signing & Capabilities** → **+ Capability** → tambahin **Push Notifications** dan **Background Modes** (centang **Remote notifications**).
6. Upload **APNs Authentication Key** (`.p8`) dari [Apple Developer](https://developer.apple.com/account) ke Firebase Console → Project settings → Cloud Messaging → Apple app configuration. Tanpa ini, push FCM ke iOS **tidak akan jalan** sama sekali (walau token tetap bisa didapat).

### 4. Install dependency
```bash
flutter pub get
```

### 5. (Opsional, direkomendasikan) Pakai FlutterFire CLI
Cara manual di atas udah cukup buat Android & iOS native init (karena kode
kita manggil `Firebase.initializeApp()` tanpa `options`, yang otomatis baca
`google-services.json` / `GoogleService-Info.plist`). Tapi kalau nanti mau
nambah Web/macOS/Windows atau mau `firebase_options.dart` yang type-safe:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Ini akan generate `lib/firebase_options.dart` — kalau itu ada, ganti
`Firebase.initializeApp()` di `fcm_service.dart` jadi:
```dart
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
```

### 6. Test
Jalankan app, lakukan login. Cek log:
```
[ApiService] LOGIN BODY: {...,"fcm_token":"<token asli, panjang>"}
```
Kalau masih muncul `dummy-fcm-token-belum-setup-firebase`, berarti
`google-services.json`/`GoogleService-Info.plist` belum kepasang dengan
benar, atau device/emulator kamu nggak punya Google Play Services
(emulator Android tanpa Play Store nggak bisa dapet FCM token — pakai
emulator image yang ada Play Store, atau device fisik).

## Catatan lain
- **Refresh token**: kalau FCM token berubah (reinstall, clear data, dll)
  setelah user login, `FcmService.onTokenRefreshed` callback akan kepanggil
  (lihat `auth_provider.dart`, sudah ada `// TODO`). Backend biasanya
  sediain endpoint terpisah kayak `PATCH /user/update-fcm-token` buat ini —
  tinggal diisi kalau endpoint-nya sudah ada.
- **Logout**: `AuthNotifier.logout()` udah manggil `FcmService.instance.deleteToken()`
  supaya device yang logout nggak lagi kebagian push notification punya user itu.
- Kalau cuma mau develop UI tanpa notifikasi dulu, app ini tetap bisa jalan
  tanpa `google-services.json` — `FcmService.initialize()` dibungkus try/catch,
  dan `ApiService` otomatis fallback ke token dummy.