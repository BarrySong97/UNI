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
  Publication? get activePublication;
  String? get activeSessionId;
  void onFirstReaderSignal() {}

  StreamSubscription<ReaderLocatorEvent>? _locatorSub;
  StreamSubscription<ReaderStatusEvent>? _statusSub;
  DateTime? _subscribedAt;
  bool _firstStatusLogged = false;
  bool _firstLocatorLogged = false;
  int _subscriptionEpoch = 0;
  int _locatorEventSeq = 0;

  _PercentResolution _resolvePercentFromEvent(
    ReaderLocatorEvent event, {
    Publication? publication,
  }) {
    final byPublication = _percentFromPublication(
      publication,
      locator: event.locator,
      pageIndex: event.pageIndex,
      totalPages: event.totalPages,
    );
    if (byPublication != null) {
      return _PercentResolution(
        percent: byPublication.percent,
        source: 'publication',
        reason: byPublication.reason,
        chapterIndex: byPublication.chapterIndex,
        chapterCount: byPublication.chapterCount,
        inChapterProgress: byPublication.inChapterProgress,
      );
    }

    final byPage = _percentFromPageNumbers(event.pageIndex, event.totalPages);
    if (byPage != null) {
      return _PercentResolution(percent: byPage, source: 'event_page_numbers');
    }

    final byLocator = extractPercentFromLocator(event.locator);
    if (byLocator != null) {
      return _PercentResolution(
        percent: byLocator,
        source: 'locator_fragments',
      );
    }

    return _PercentResolution(
      percent: null,
      source: 'none',
      reason: byPublication?.reason ?? 'missing_page_and_locator_progress',
    );
  }

  Future<void> subscribeToChannels() async {
    final epoch = ++_subscriptionEpoch;
    _locatorEventSeq = 0;
    ReaderPerf.mark('channel.subscribe', bookId: readerStore?.state.book?.id);
    _statusSub?.cancel();
    _locatorSub?.cancel();
    _subscribedAt = DateTime.now();
    _firstStatusLogged = false;
    _firstLocatorLogged = false;
    _statusSub = subscribeStatusEvents((event) {
      // 多实例场景下必须按 session 过滤事件，否则会出现 A 书收到 B 书回调。
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
    readerStore?.onReaderReady();
    await restoreSavedPosition();
    if (epoch != _subscriptionEpoch) {
      return;
    }

    _locatorSub = subscribeLocatorEvents((event) {
      // 仅消费当前 active session 的 locator，避免进度串写。
      if (!_matchesActiveSession(event.sessionId)) {
        return;
      }
      _locatorEventSeq += 1;
      final locator = event.locator;
      final summary = summarizeLocator(locator);
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
      final resolved = _resolvePercentFromEvent(
        event,
        publication: activePublication,
      );
      final percent = resolved.percent;
      ReaderPerf.mark(
        'channel.locator_event',
        bookId: readerStore?.state.book?.id,
        extras: <String, Object?>{
          ...summary,
          'event_session': event.sessionId,
          'active_session': activeSessionId,
          'page_index': event.pageIndex,
          'total_pages': event.totalPages,
          'parsed_percent': percent,
          'event_seq': _locatorEventSeq,
          'percent_source': resolved.source,
          'percent_reason': resolved.reason,
          'chapter_index': resolved.chapterIndex,
          'chapter_count': resolved.chapterCount,
          'in_chapter_progress': resolved.inChapterProgress,
        },
      );
      readerStore?.updateLocator(json, percent: percent);
    });
  }

  Future<void> restoreSavedPosition() async {
    final store = readerStore;
    if (store == null) {
      ReaderPerf.mark('channel.restore.skip_store_not_ready');
      return;
    }
    final bookId = store.state.book?.id;
    ReaderPerf.mark(
      'channel.restore.trigger',
      bookId: bookId,
      extras: <String, Object?>{
        'has_book': bookId != null,
        'active_session': activeSessionId,
      },
    );
    if (bookId == null || bookId.isEmpty) {
      ReaderPerf.mark('channel.restore.skip_store_not_ready', bookId: bookId);
      return;
    }
    final locatorJson = store.savedLocatorJson;
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
      final restoredPercent = extractPercentFromEvent(
        ReaderLocatorEvent(locator: locator),
        publication: activePublication,
      );
      if (restoredPercent != null) {
        store.updateLocator(locatorJson, percent: restoredPercent);
        ReaderPerf.mark(
          'channel.restore.percent_applied',
          bookId: bookId,
          extras: <String, Object?>{'percent': restoredPercent},
        );
      } else {
        ReaderPerf.mark('channel.restore.percent_missing', bookId: bookId);
      }
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

  double? extractPercentFromEvent(
    ReaderLocatorEvent event, {
    Publication? publication,
  }) {
    final byPublication = _percentFromPublication(
      publication,
      locator: event.locator,
      pageIndex: event.pageIndex,
      totalPages: event.totalPages,
    );
    if (byPublication?.percent != null) {
      return byPublication!.percent;
    }
    final byPage = _percentFromPageNumbers(event.pageIndex, event.totalPages);
    if (byPage != null) {
      return byPage;
    }
    return extractPercentFromLocator(event.locator);
  }

  double? extractPercentFromLocator(Locator locator) {
    try {
      final json = locator.toJson();
      final locationsRaw = json['locations'];
      if (locationsRaw is! Map) {
        return null;
      }
      final locations = Map<String, dynamic>.from(locationsRaw);
      final value = _percentFromPageFragments(locations);
      if (value == null) {
        return null;
      }
      return value.clamp(0.0, 1.0).toDouble();
    } catch (_) {
      return null;
    }
  }

  Map<String, Object?> summarizeLocator(Locator locator) {
    try {
      final json = locator.toJson();
      final href = json['href'];
      final locationsRaw = json['locations'];
      if (locationsRaw is! Map) {
        return <String, Object?>{'href': href, 'has_locations': false};
      }
      final locations = Map<String, dynamic>.from(locationsRaw);
      return <String, Object?>{
        'href': href,
        'has_locations': true,
        'progression': _toDouble(locations['progression']),
        'position': locations['position'],
        'page': _fragmentInt(locations['fragments'], key: 'page'),
        'total_pages': _fragmentInt(locations['fragments'], key: 'totalPages'),
      };
    } catch (_) {
      return const <String, Object?>{'locator_parse_error': true};
    }
  }

  void cancelChannels() {
    ReaderPerf.mark(
      'channel.cancel',
      bookId: readerStore?.state.book?.id,
      extras: <String, Object?>{
        'active_session': activeSessionId,
        'last_event_seq': _locatorEventSeq,
      },
    );
    _subscriptionEpoch += 1;
    _locatorSub?.cancel();
    _locatorSub = null;
    _statusSub?.cancel();
    _statusSub = null;
    _subscribedAt = null;
    _firstStatusLogged = false;
    _firstLocatorLogged = false;
    _locatorEventSeq = 0;
  }

  bool _matchesActiveSession(String? eventSessionId) {
    final active = activeSessionId;
    if (active == null || active.isEmpty) {
      return eventSessionId == null || eventSessionId.isEmpty;
    }
    return eventSessionId == active;
  }

  double? _toDouble(Object? raw) {
    if (raw is num) {
      return raw.toDouble();
    }
    if (raw is String) {
      return double.tryParse(raw);
    }
    return null;
  }

  double? _percentFromPageFragments(Map<String, dynamic> locations) {
    return _percentFromPageNumbers(
      _fragmentInt(locations['fragments'], key: 'page'),
      _fragmentInt(locations['fragments'], key: 'totalPages'),
    );
  }

  double? _percentFromPageNumbers(int? pageIndex, int? totalPages) {
    if (pageIndex == null || totalPages == null || totalPages <= 1) {
      return null;
    }
    final clampedPage = pageIndex.clamp(1, totalPages);
    return (clampedPage - 1) / (totalPages - 1);
  }

  int? _fragmentInt(Object? fragmentsRaw, {required String key}) {
    if (fragmentsRaw is! List) {
      return null;
    }
    final prefix = '$key=';
    for (final item in fragmentsRaw) {
      if (item is! String || !item.startsWith(prefix)) {
        continue;
      }
      return int.tryParse(item.substring(prefix.length));
    }
    return null;
  }

  _PublicationPercent? _percentFromPublication(
    Publication? publication, {
    required Locator locator,
    int? pageIndex,
    int? totalPages,
  }) {
    if (publication == null) {
      return const _PublicationPercent(reason: 'publication_null');
    }
    final readingOrder = publication.readingOrder;
    if (readingOrder.isEmpty) {
      return const _PublicationPercent(reason: 'reading_order_empty');
    }

    final currentHref = _normalizeHref(locator.href);
    final chapterIndex = readingOrder.indexWhere(
      (link) => _hrefMatches(_normalizeHref(link.href), currentHref),
    );
    if (chapterIndex < 0) {
      return _PublicationPercent(
        reason: 'href_not_found_in_reading_order',
        chapterCount: readingOrder.length,
      );
    }

    final json = locator.toJson();
    final locationsRaw = json['locations'];
    final locations = locationsRaw is Map
        ? Map<String, dynamic>.from(locationsRaw)
        : const <String, dynamic>{};
    final inChapter =
        _toDouble(locations['progression']) ??
        _percentFromPageNumbers(pageIndex, totalPages) ??
        _percentFromPageFragments(locations) ??
        0.0;

    final clamped = inChapter.clamp(0.0, 1.0);
    final percent = (chapterIndex + clamped) / readingOrder.length;
    return _PublicationPercent(
      percent: percent.clamp(0.0, 1.0).toDouble(),
      reason: 'ok',
      chapterIndex: chapterIndex,
      chapterCount: readingOrder.length,
      inChapterProgress: clamped,
    );
  }

  String _normalizeHref(String href) {
    final noFragment = href.split('#').first;
    return noFragment.startsWith('/') ? noFragment.substring(1) : noFragment;
  }

  bool _hrefMatches(String a, String b) {
    if (a == b) {
      return true;
    }
    return a.endsWith('/$b') || b.endsWith('/$a');
  }

  StreamSubscription<ReaderStatusEvent> subscribeStatusEvents(
    void Function(ReaderStatusEvent event) onData,
  ) {
    return flureadium.onReaderStatusEvents.listen(onData);
  }

  StreamSubscription<ReaderLocatorEvent> subscribeLocatorEvents(
    void Function(ReaderLocatorEvent event) onData,
  ) {
    return flureadium.onTextLocatorEvents.listen(onData);
  }
}

class _PercentResolution {
  const _PercentResolution({
    required this.percent,
    required this.source,
    this.reason,
    this.chapterIndex,
    this.chapterCount,
    this.inChapterProgress,
  });

  final double? percent;
  final String source;
  final String? reason;
  final int? chapterIndex;
  final int? chapterCount;
  final double? inChapterProgress;
}

class _PublicationPercent {
  const _PublicationPercent({
    this.percent,
    this.reason,
    this.chapterIndex,
    this.chapterCount,
    this.inChapterProgress,
  });

  final double? percent;
  final String? reason;
  final int? chapterIndex;
  final int? chapterCount;
  final double? inChapterProgress;
}
