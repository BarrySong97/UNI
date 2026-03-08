import 'package:flureadium_platform_interface/flureadium_platform_interface.dart';
import 'toc_matcher.dart';

/// Result of navigation decision for chapter skip operations.
class NavigationDecision {
  const NavigationDecision.navigate(this.targetLink, this.targetTocIndex)
    : canNavigate = true,
      reason = null;

  const NavigationDecision.abort(this.reason)
    : canNavigate = false,
      targetLink = null,
      targetTocIndex = null;

  /// Whether navigation should proceed.
  final bool canNavigate;

  /// The target link to navigate to (null if aborted).
  final Link? targetLink;

  /// The target TOC index (null if navigating to non-TOC page or aborted).
  final int? targetTocIndex;

  /// Reason for aborting navigation (null if navigation should proceed).
  final String? reason;
}

/// Decides where to navigate when skipToNext is called.
///
/// This function encapsulates the navigation logic for moving to the next chapter,
/// including handling edge cases for non-TOC pages.
///
/// Returns a [NavigationDecision] indicating whether to navigate and where.
NavigationDecision decideSkipToNext({
  required Locator currentLocator,
  required List<Link> toc,
  required List<Link> readingOrder,
  required int currentTocIndex,
  required Publication publication,
}) {
  // Handle case where current page is not in TOC
  if (currentTocIndex == -1) {
    // For PDFs, check if current page is before first TOC page
    if (isPdfToc(toc)) {
      final currentPage = currentLocator.locations?.position;
      final firstTocPage = _extractPageFromTocLink(toc.first);
      R2Log.d(
        'decideSkipToNext: PDF - currentPage=$currentPage, firstTocPage=$firstTocPage',
      );
      if (currentPage != null &&
          firstTocPage != null &&
          currentPage < firstTocPage) {
        // Current page is before first chapter - jump to first chapter
        return NavigationDecision.navigate(toc.first, 0);
      }
      // For PDF, if we're not before first chapter, we should still go to first
      // chapter if we have valid pages (covers case where findTocIndexByPage returned -1
      // due to being before first chapter's page)
      if (firstTocPage != null) {
        return NavigationDecision.navigate(toc.first, 0);
      }
    }

    // Check if current page is before first TOC entry in readingOrder
    final currentPos = _findInReadingOrder(currentLocator, readingOrder);
    if (currentPos == -1) {
      return const NavigationDecision.abort(
        'Current page not found in readingOrder',
      );
    }

    // Get first TOC entry's position in readingOrder
    final firstTocLink = toc[0];
    final firstTocLocator = publication.locatorFromLink(firstTocLink);
    if (firstTocLocator == null) {
      return const NavigationDecision.abort(
        'Cannot create locator from first TOC entry',
      );
    }
    final firstTocPos = _findInReadingOrder(firstTocLocator, readingOrder);

    if (firstTocPos != -1 && currentPos < firstTocPos) {
      // Current page is before first TOC entry - jump to first chapter
      return NavigationDecision.navigate(firstTocLink, 0);
    }

    // Page not in TOC and not before it - can't advance
    return const NavigationDecision.abort(
      'Page not in TOC and not before first chapter',
    );
  }

  // Check if already at last chapter
  if (currentTocIndex >= toc.length - 1) {
    // At last chapter - check if there are pages after it
    final lastTocIndex = toc.length - 1;
    final lastTocLink = toc[lastTocIndex];
    final lastTocLocator = publication.locatorFromLink(lastTocLink);
    if (lastTocLocator != null) {
      final lastTocPos = _findInReadingOrder(lastTocLocator, readingOrder);
      if (lastTocPos != -1 && lastTocPos < readingOrder.length - 1) {
        // There are pages after last TOC entry - go to next page
        final nextPagePos = lastTocPos + 1;
        final nextPage = readingOrder[nextPagePos];
        return NavigationDecision.navigate(nextPage, null);
      }
    }
    return const NavigationDecision.abort('Already at last page');
  }

  // Normal case: navigate to next chapter
  final newIndex = currentTocIndex + 1;
  return NavigationDecision.navigate(toc[newIndex], newIndex);
}

/// Decides where to navigate when skipToPrevious is called.
///
/// This function encapsulates the navigation logic for moving to the previous chapter,
/// including handling edge cases for non-TOC pages.
///
/// Returns a [NavigationDecision] indicating whether to navigate and where.
NavigationDecision decideSkipToPrevious({
  required Locator currentLocator,
  required List<Link> toc,
  required List<Link> readingOrder,
  required int currentTocIndex,
  required Publication publication,
}) {
  // Handle case where current page is not in TOC
  if (currentTocIndex == -1) {
    // For PDFs, check if current page is before first TOC page
    if (isPdfToc(toc)) {
      final currentPage = currentLocator.locations?.position;
      final firstTocPage = _extractPageFromTocLink(toc.first);
      R2Log.d(
        'decideSkipToPrevious: PDF - currentPage=$currentPage, firstTocPage=$firstTocPage',
      );
      if (currentPage != null &&
          firstTocPage != null &&
          currentPage < firstTocPage) {
        // Current page is before first chapter - can't go back
        return const NavigationDecision.abort('Already at first page');
      }
      // Check if after last chapter
      final lastTocPage = _extractPageFromTocLink(toc.last);
      if (currentPage != null &&
          lastTocPage != null &&
          currentPage > lastTocPage) {
        // Current page is after last chapter - jump to last chapter
        return NavigationDecision.navigate(toc.last, toc.length - 1);
      }
    }

    // Check if current page is after last TOC entry in readingOrder
    final currentPos = _findInReadingOrder(currentLocator, readingOrder);
    if (currentPos == -1) {
      return const NavigationDecision.abort(
        'Current page not found in readingOrder',
      );
    }

    // Get last TOC entry's position in readingOrder
    final lastTocIndex = toc.length - 1;
    final lastTocLink = toc[lastTocIndex];
    final lastTocLocator = publication.locatorFromLink(lastTocLink);
    if (lastTocLocator == null) {
      return const NavigationDecision.abort(
        'Cannot create locator from last TOC entry',
      );
    }
    final lastTocPos = _findInReadingOrder(lastTocLocator, readingOrder);

    if (lastTocPos != -1 && currentPos > lastTocPos) {
      // Current page is after last TOC entry - jump to last chapter
      return NavigationDecision.navigate(lastTocLink, lastTocIndex);
    }

    // Page not in TOC and not after it - can't go back
    return const NavigationDecision.abort(
      'Page not in TOC and not after last chapter',
    );
  }

  // Check if already at first chapter
  if (currentTocIndex == 0) {
    // For PDFs, check if there are pages before first chapter
    if (isPdfToc(toc)) {
      final firstTocPage = _extractPageFromTocLink(toc.first);
      R2Log.d(
        'decideSkipToPrevious: PDF at first chapter, firstTocPage=$firstTocPage',
      );
      if (firstTocPage != null && firstTocPage > 1) {
        // There are pages before first chapter - create link to page 1
        return NavigationDecision.navigate(
          _createPdfPageLink(toc.first, 1),
          null,
        );
      }
      return const NavigationDecision.abort('Already at first page');
    }

    // At first chapter - check if there are pages before it
    final firstTocLink = toc[0];
    final firstTocLocator = publication.locatorFromLink(firstTocLink);
    if (firstTocLocator != null) {
      final firstTocPos = _findInReadingOrder(firstTocLocator, readingOrder);
      if (firstTocPos > 0) {
        // There are pages before first TOC entry - go to first page
        final firstPage = readingOrder[0];
        return NavigationDecision.navigate(firstPage, null);
      }
    }
    return const NavigationDecision.abort('Already at first page');
  }

  // Normal case: navigate to previous chapter
  final newIndex = currentTocIndex - 1;
  return NavigationDecision.navigate(toc[newIndex], newIndex);
}

/// Helper to find a locator's position in the reading order.
/// Returns -1 if not found.
int _findInReadingOrder(Locator locator, List<Link> readingOrder) {
  final locatorPath = normalizePath(locator.hrefPath);
  return readingOrder.indexWhere(
    (link) => normalizePath(link.hrefPart) == locatorPath,
  );
}

/// Extracts page number from a TOC link's href (e.g., "doc.pdf#page=5" -> 5).
int? _extractPageFromTocLink(Link link) {
  final href = link.href;
  final fragmentIndex = href.indexOf('#page=');
  if (fragmentIndex == -1) return null;
  final pageStr = href.substring(fragmentIndex + 6);
  return int.tryParse(pageStr);
}

/// Creates a PDF link with a specific page number.
/// Uses the base path from the template link.
Link _createPdfPageLink(Link templateLink, int page) {
  final basePath = templateLink.href.split('#').first;
  return Link(href: '$basePath#page=$page');
}
