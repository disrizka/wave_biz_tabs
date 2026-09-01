import 'package:flutter/material.dart';
import 'package:wave_biz_tabs/core/responsive.dart';
import 'package:wave_biz_tabs/screens/login/widgets/mobile_login_layout.dart';
import 'package:wave_biz_tabs/screens/login/widgets/tablet_login_layout.dart';

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
