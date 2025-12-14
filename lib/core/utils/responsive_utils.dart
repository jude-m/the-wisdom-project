import 'package:flutter/widgets.dart';

/// Responsive breakpoints and utility methods for the app.
///
/// Breakpoints:
/// - Mobile: < 768px (phones)
/// - Tablet: 768px - 1023px
/// - Desktop: >= 1024px (includes web at large sizes)
class ResponsiveUtils {
  /// Mobile breakpoint (below this is considered mobile)
  static const double mobileBreakpoint = 768.0;

  /// Desktop breakpoint (at or above this is considered desktop)
  static const double desktopBreakpoint = 1024.0;

  /// Check if screen is mobile-sized (< 768px)
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  /// Check if screen is tablet-sized (768px - 1023px)
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < desktopBreakpoint;
  }

  /// Check if screen is desktop-sized (>= 1024px)
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktopBreakpoint;
  }

  /// Check if screen is tablet or desktop (>= 768px)
  /// Useful for showing side panels instead of full-screen overlays
  static bool isTabletOrDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= mobileBreakpoint;
  }

  /// Get the current screen width
  static double screenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  /// Get the current screen height
  static double screenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }
}
