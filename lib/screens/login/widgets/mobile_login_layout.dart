import 'package:flutter/material.dart';
import 'package:wave_biz_tabs/core/constants.dart';
import 'package:wave_biz_tabs/screens/login/widgets/login_form_card.dart';

class MobileLoginLayout extends StatelessWidget {
  const MobileLoginLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE0F2F1), Colors.white, Color(0xFFB2DFDB)],
          stops: [0.0, 0.45, 1.0],
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const LoginFormCard(),
                      const SizedBox(height: 80),
                      Image.asset(
                        AssetPaths.logo,
                        height: 28,
                        color: Colors.white,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
