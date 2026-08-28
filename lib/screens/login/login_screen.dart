import 'package:flutter/material.dart';

import '../../core/responsive.dart';
import 'widgets/mobile_login_layout.dart';
import 'widgets/tablet_login_layout.dart';

/// Entry point untuk halaman login.
/// Yang nentuin mobile vs tablet/web bukan platform-nya,
/// tapi LEBAR LAYAR (pakai LayoutBuilder), jadi kalau window
/// di desktop di-resize kecil pun otomatis balik ke layout mobile.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > Responsive.mobileMaxWidth;
          return isWide ? const TabletLoginLayout() : const MobileLoginLayout();
        },
      ),
    );
  }
}
