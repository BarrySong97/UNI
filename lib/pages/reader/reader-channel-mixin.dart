import 'dart:async';
import 'dart:convert';

import 'package:flureadium/flureadium.dart';

import '../../services/reader/reader-performance-tracker.dart';
import '../../stores/reader/reader-store.dart';

/// Shared logic for subscribing to Readium channels and restoring position.
///
/// Used by both [ReaderPage] (normal flow) and [ReaderOverlayLayer] (preload
/// flow) to avoid duplicating channel wiring code.
mixin ReaderChannelMixin {
  Flureadium get flureadium;
  ReaderStore? get readerStore;
  String? get activeSessionId;
  void onFirstReaderSignal() {}

  StreamSubscription<ReaderLocatorEvent>? _locatorSub;
  StreamSubscription<ReaderStatusEvent>? _statusSub;
  DateTime? _subscribedAt;
  bool _firstStatusLogged = false;
  bool _firstLocatorLogged = false;

  void subscribeToChannels() {
    ReaderPerf.mark('channel.subscribe', bookId: readerStore?.state.book?.id);
    _statusSub?.cancel();
    _locatorSub?.cancel();
    _subscribedAt = DateTime.now();
    _firstStatusLogged = false;
    _firstLocatorLogged = false;
    _statusSub = flureadium.onReaderStatusEvents.listen((event) {
      if (!_matchesActiveSession(event.sessionId)) {
        return;
      }
      if (_firstStatusLogged) {
        return;
      }
      _firstStatusLogged = true;
      onFirstReaderSignal();
      final bookId = readerStore?.state.book?.id;
      final at = _subscribedAt;
      ReaderPerf.mark(
        'channel.first_status_event',
        bookId: bookId,
        elapsedMs: at == null
            ? null
            : DateTime.now().difference(at).inMilliseconds,
      );
    });
    _locatorSub = flureadium.onTextLocatorEvents.listen((event) {
      if (!_matchesActiveSession(event.sessionId)) {
        return;
      }
      final locator = event.locator;
      if (!_firstLocatorLogged) {
        _firstLocatorLogged = true;
        onFirstReaderSignal();
        final bookId = readerStore?.state.book?.id;
        final at = _subscribedAt;
        ReaderPerf.mark(
          'channel.first_locator_event',
          bookId: bookId,
          elapsedMs: at == null
              ? null
              : DateTime.now().difference(at).inMilliseconds,
        );
      }
      final json = locatorToJson(locator);
      readerStore?.updateLocator(json);
    });
    readerStore?.onReaderReady();
    restoreSavedPosition();
  }

  Future<void> restoreSavedPosition() async {
    final bookId = readerStore?.state.book?.id;
    final locatorJson = readerStore?.savedLocatorJson;
    if (locatorJson == null || locatorJson.isEmpty) {
      ReaderPerf.mark('channel.restore.skip_empty', bookId: bookId);
      return;
    }
    final watch = ReaderPerf.start('channel.restore', bookId: bookId);
    try {
      final map = jsonDecode(locatorJson) as Map<String, dynamic>;
      final locator = Locator.fromJson(map);
      if (locator == null) {
        ReaderPerf.mark('channel.restore.invalid_locator', bookId: bookId);
        ReaderPerf.end('channel.restore', watch, bookId: bookId);
        return;
      }
      await flureadium.goToLocator(locator, sessionId: activeSessionId);
      ReaderPerf.end('channel.restore', watch, bookId: bookId);
    } catch (e) {
      ReaderPerf.mark(
        'channel.restore.error',
        bookId: bookId,
        extras: <String, Object?>{'error': e.toString()},
      );
    }
  }

  String locatorToJson(Locator locator) {
    try {
      return jsonEncode(locator.toJson());
    } catch (_) {
      return '{}';
    }
  }

  void cancelChannels() {
    _locatorSub?.cancel();
    _locatorSub = null;
    _statusSub?.cancel();
    _statusSub = null;
    _subscribedAt = null;
    _firstStatusLogged = false;
    _firstLocatorLogged = false;
  }

  bool _matchesActiveSession(String? eventSessionId) {
    final active = activeSessionId;
    if (active == null || active.isEmpty) {
      return eventSessionId == null || eventSessionId.isEmpty;
    }
    return eventSessionId == active;
  }
}
