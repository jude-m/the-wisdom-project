import 'package:flutter/widgets.dart';

import '../constants/constants.dart';

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

  /// Check if device is in portrait orientation
  static bool isPortrait(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.portrait;
  }

  /// Check if device is in landscape orientation
  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  /// Check if we should show single-column (Pali only) by default
  /// Returns true for mobile devices in portrait mode
  static bool shouldDefaultToSingleColumn(BuildContext context) {
    return isMobile(context) && isPortrait(context);
  }

  /// Padding for the single-script reader panes (Pali-only, Sinhala-only,
  /// stacked) — NOT side-by-side.
  ///
  /// On a wide reader pane, the text is capped to a comfortable reading column
  /// ([PaneWidthConstants.readingColumnMaxWidth]) and the leftover space
  /// becomes equal left/right margins, giving a calmer, book-like measure.
  /// On medium and small panes it falls back to the standard uniform 24px, so
  /// phones and tablets read exactly as they do today.
  ///
  /// Driven by the pane's own [availableWidth] (typically from a
  /// [LayoutBuilder]) rather than the full screen width — the reader pane
  /// already excludes the navigator sidebar, so this is the accurate basis for
  /// "is this column too wide to read comfortably".
  static EdgeInsets readingColumnPadding(double availableWidth) {
    const base = PaneWidthConstants.readerContentPadding;
    const maxColumn = PaneWidthConstants.readingColumnMaxWidth;
    // Below this the pane isn't wide enough to benefit; the threshold is set so
    // the horizontal padding grows continuously from `base` (no visible jump).
    if (availableWidth <= maxColumn + base * 2) {
      return const EdgeInsets.all(base);
    }
    final horizontal = (availableWidth - maxColumn) / 2;
    return EdgeInsets.symmetric(horizontal: horizontal, vertical: base);
  }
}
