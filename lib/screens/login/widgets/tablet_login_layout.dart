import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import 'login_form_card.dart';

/// Layout login untuk tablet & web: split 2 kolom.
/// Kiri: logo + ilustrasi + caption promosi.
/// Kanan: form login di atas background lavender, mengambang di tengah.
/// Sesuai referensi desain tablet/web kamu.
class TabletLoginLayout extends StatelessWidget {
  const TabletLoginLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Panel kiri
        Expanded(
          flex: 6,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(
                  AssetPaths.logo,
                  height: 28,
                  errorBuilder: (_, __, ___) => const Text(
                    'WAVEUP',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 380),
                      child: Image.asset(
                        AssetPaths.illustration,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
                _DotsIndicator(activeIndex: 1),
                const SizedBox(height: 20),
                const Text(
                  'More efficient process',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Supercharge your ordering with WAVEUP: Faster, smarter, better.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),

        // Panel kanan
        Expanded(
          flex: 5,
          child: Container(
            color: const Color(0xFFE4E9FB),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: const LoginFormCard(),
            ),
          ),
        ),
      ],
    );
  }
}

class _DotsIndicator extends StatelessWidget {
  const _DotsIndicator({required this.activeIndex, this.count = 3});

  final int activeIndex;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == activeIndex;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF3E5FCE) : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
