import 'package:flutter/widgets.dart';

/// Breakpoint sederhana:
/// - Mobile   : lebar < 600
/// - Tablet   : 600 - 1023
/// - Desktop  : >= 1024
///
/// Login screen cuma butuh 2 mode tampilan (mobile vs "lebar"),
/// jadi tablet & desktop dianggap satu kelompok layout yang sama
/// (split screen kiri-kanan), sedangkan mobile pakai layout kartu polos.
class Responsive {
  static const double mobileMaxWidth = 599;
  static const double tabletMaxWidth = 1023;

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width <= mobileMaxWidth;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width > mobileMaxWidth && width <= tabletMaxWidth;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width > tabletMaxWidth;

  /// Dipakai buat nentuin mode layout login: true = split layout (tablet/web)
  static bool isWideLayout(BuildContext context) =>
      MediaQuery.of(context).size.width > mobileMaxWidth;
}
