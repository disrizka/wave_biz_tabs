import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import 'login_form_card.dart';

/// Layout login untuk HP: background gradasi biru muda -> putih,
/// kartu form di tengah, logo WAVEUP mengambang di bagian bawah.
///
/// PENTING: sebelumnya pakai `Spacer()` di dalam `SingleChildScrollView`,
/// itu penyebab layar putih blank di HP — `Spacer`/`Expanded` butuh
/// tinggi yang terbatas (bounded), sedangkan di dalam scroll view
/// tingginya unbounded, jadi Flutter gagal nge-render frame sama sekali.
/// Sekarang diganti spacing tetap, jadi aman.
class MobileLoginLayout extends StatelessWidget {
  const MobileLoginLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE4E9FB), Colors.white, Color(0xFFBFD8FA)],
          stops: [0.0, 0.45, 1.0],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 60),
              const LoginFormCard(),
              const SizedBox(height: 80),
              Image.asset(
                AssetPaths.logo,
                height: 28,
                color: Colors.white,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
