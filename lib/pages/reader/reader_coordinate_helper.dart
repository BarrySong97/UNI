import 'package:flutter/painting.dart';

import '../../services/reader/models/page_layout.dart';

/// Abstracts coordinate transforms between screen space and content space.
///
/// Two implementations handle single-page (phone) and dual-page (tablet) modes,
/// so the reader page logic doesn't need to branch on display mode.
abstract class ReaderCoordinateHelper {
  /// Whether the touch falls on the right page (always false in single mode).
  bool isTouchOnRightPage(Offset global);

  /// Determine which page a touch falls on.
  /// Returns (page, isRightPage).
  (PageLayout?, bool) hitPageForTouch(
    Offset global,
    PageLayout? currentPage,
    PageLayout? secondPage,
  );

  /// Convert a global screen position to content-area coordinates.
  /// In dual mode, [isRightPage] shifts the origin to the right half.
  Offset toContentOffset(Offset global, {bool isRightPage = false});

  /// Convert content-area coordinates to screen coordinates.
  /// In dual mode, [isRightPage] adds the right-half offset.
  Offset toScreenOffset(Offset content, {bool isRightPage = false});
}

// =============================================================================
// Single-page mode (phone)
// =============================================================================

/// All touches map to the single visible page.
class SinglePageCoordinateHelper implements ReaderCoordinateHelper {
  const SinglePageCoordinateHelper({
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.safeAreaTop,
  });

  final double horizontalPadding;
  final double verticalPadding;
  final double safeAreaTop;

  @override
  bool isTouchOnRightPage(Offset global) => false;

  @override
  (PageLayout?, bool) hitPageForTouch(
    Offset global,
    PageLayout? currentPage,
    PageLayout? secondPage,
  ) {
    return (currentPage, false);
  }

  @override
  Offset toContentOffset(Offset global, {bool isRightPage = false}) {
    return Offset(
      global.dx - horizontalPadding,
      global.dy - verticalPadding - safeAreaTop,
    );
  }

  @override
  Offset toScreenOffset(Offset content, {bool isRightPage = false}) {
    return Offset(
      content.dx + horizontalPadding,
      content.dy + verticalPadding + safeAreaTop,
    );
  }
}

// =============================================================================
// Dual-page mode (tablet)
// =============================================================================

/// Touches on the left half map to the current (left) page; touches on the
/// right half map to the second (right) page. Coordinate transforms account
/// for the half-screen offset when [isRightPage] is true.
class DualPageCoordinateHelper implements ReaderCoordinateHelper {
  const DualPageCoordinateHelper({
    required this.screenWidth,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.safeAreaTop,
  });

  final double screenWidth;
  final double horizontalPadding;
  final double verticalPadding;
  final double safeAreaTop;

  @override
  bool isTouchOnRightPage(Offset global) {
    return global.dx >= screenWidth / 2;
  }

  @override
  (PageLayout?, bool) hitPageForTouch(
    Offset global,
    PageLayout? currentPage,
    PageLayout? secondPage,
  ) {
    if (isTouchOnRightPage(global)) {
      return (secondPage, true);
    }
    return (currentPage, false);
  }

  @override
  Offset toContentOffset(Offset global, {bool isRightPage = false}) {
    final dx = isRightPage
        ? global.dx - screenWidth / 2 - horizontalPadding
        : global.dx - horizontalPadding;
    return Offset(
      dx,
      global.dy - verticalPadding - safeAreaTop,
    );
  }

  @override
  Offset toScreenOffset(Offset content, {bool isRightPage = false}) {
    final dx = isRightPage
        ? content.dx + screenWidth / 2 + horizontalPadding
        : content.dx + horizontalPadding;
    return Offset(
      dx,
      content.dy + verticalPadding + safeAreaTop,
    );
  }
}
