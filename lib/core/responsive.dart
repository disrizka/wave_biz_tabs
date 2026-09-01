import 'package:flutter/widgets.dart';

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

  static bool isWideLayout(BuildContext context) =>
      MediaQuery.of(context).size.width > mobileMaxWidth;
}
