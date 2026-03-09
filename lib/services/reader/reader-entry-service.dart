import 'package:flutter/material.dart';

import '../../app/providers/app-providers.dart';
import '../../app/routes/route-names.dart';
import 'reader-performance-tracker.dart';
import 'reader-session-pool-service.dart';

/// Unified reader entry:
/// - Overlay fast path when the target book is preloaded.
/// - Route fallback when not preloaded.
class ReaderEntryService {
  bool _isNavigating = false;
  final ReaderSessionPoolService _sessionPool = ReaderSessionPoolService();

  Future<void> openBook(BuildContext context, String bookId) async {
    if (_isNavigating || !context.mounted) {
      return;
    }
    _isNavigating = true;
    _sessionPool.markUsed(bookId);
    _sessionPool.incrementOpenCountIfExists(bookId);
    final totalWatch = ReaderPerf.start('entry.open', bookId: bookId);
    try {
      final providers = AppProvidersScope.of(context);
      final overlayController = providers.readerOverlayController;
      if (overlayController.canShowInstantly(bookId)) {
        ReaderPerf.mark('entry.overlay_hit', bookId: bookId);
        overlayController.show(bookId);
        ReaderPerf.end('entry.open', totalWatch, bookId: bookId);
        return;
      }
      ReaderPerf.mark('entry.route_fallback', bookId: bookId);
      ReaderPerf.markRouteFallback(bookId);
      final routeWatch = ReaderPerf.start('entry.route_push', bookId: bookId);
      await Navigator.of(
        context,
      ).pushNamed(RouteNames.reader, arguments: bookId);
      ReaderPerf.end('entry.route_push', routeWatch, bookId: bookId);
      ReaderPerf.end('entry.open', totalWatch, bookId: bookId);
    } finally {
      _isNavigating = false;
    }
  }
}
