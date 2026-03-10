import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flureadium/flureadium.dart';
import 'package:path/path.dart' as p;

import '../../app/providers/app-providers.dart';
import '../../services/reader/publication-cache-service.dart';
import '../../services/reader/reader-performance-tracker.dart';
import '../../stores/library/library-store.dart';
import '../../stores/reader/reader-store.dart';
import 'reader-channel-mixin.dart';

class ReaderPage extends StatefulWidget {
  const ReaderPage({required this.bookId, super.key});

  final String bookId;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> with ReaderChannelMixin {
  @override
  final Flureadium flureadium = Flureadium();

  final PublicationCacheService _pubCache = PublicationCacheService();

  bool _initialized = false;
  bool _loggedFirstFrameAfterPublication = false;
  DateTime? _spinnerShownAt;
  String? _spinnerInitialReason;
  String? _spinnerReason;
  bool _spinnerVisible = false;
  bool _pendingFirstPaintAfterSpinner = false;
  Publication? _publication;
  LibraryStore? _libraryStore;

  @override
  ReaderStore? readerStore;

  @override
  Publication? get activePublication => _publication;

  @override
  String? get activeSessionId => widget.bookId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _initReader();
    }
  }

  Future<void> _initReader() async {
    final watch = ReaderPerf.start('page.init_reader', bookId: widget.bookId);
    final fallbackToInitMs = ReaderPerf.consumeRouteFallbackElapsedMs(
      widget.bookId,
    );
    if (fallbackToInitMs != null) {
      ReaderPerf.mark(
        'entry.route_fallback_to_page_init',
        bookId: widget.bookId,
        elapsedMs: fallbackToInitMs,
      );
    }
    final providers = AppProvidersScope.of(context);
    readerStore = providers.readerStore;
    _libraryStore = providers.libraryStore;

    final openBookWatch = ReaderPerf.start(
      'page.init_reader.open_store',
      bookId: widget.bookId,
    );
    await readerStore!.openBook(widget.bookId);
    ReaderPerf.end(
      'page.init_reader.open_store',
      openBookWatch,
      bookId: widget.bookId,
    );
    if (!mounted) return;

    final epubPath = readerStore!.state.book?.epubFilePath;
    if (epubPath == null) {
      ReaderPerf.mark('page.init_reader.no_epub', bookId: widget.bookId);
      ReaderPerf.end('page.init_reader', watch, bookId: widget.bookId);
      return;
    }

    final resolvedPath = _resolveEpubPath(epubPath);
    try {
      final publicationWatch = ReaderPerf.start(
        'page.init_reader.get_publication',
        bookId: widget.bookId,
      );
      final pub = await _pubCache.getOrOpen(
        resolvedPath,
        sessionId: widget.bookId,
      );
      ReaderPerf.end(
        'page.init_reader.get_publication',
        publicationWatch,
        bookId: widget.bookId,
      );
      if (!mounted) return;
      setState(() => _publication = pub);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _loggedFirstFrameAfterPublication) {
          return;
        }
        _loggedFirstFrameAfterPublication = true;
        ReaderPerf.mark(
          'page.first_frame_after_publication',
          bookId: widget.bookId,
        );
      });
      ReaderPerf.end('page.init_reader', watch, bookId: widget.bookId);
    } catch (e) {
      debugPrint('Failed to open publication: $e');
      ReaderPerf.mark(
        'page.init_reader.error',
        bookId: widget.bookId,
        extras: <String, Object?>{'error': e.toString()},
      );
    }
  }

  String _resolveEpubPath(String storedPath) {
    if (p.isAbsolute(storedPath)) return storedPath;
    final docsPath = AppProvidersScope.of(context).documentsDirectoryPath;
    return p.join(docsPath, storedPath);
  }

  @override
  void dispose() {
    cancelChannels();
    unawaited(
      (readerStore?.flushProgress() ?? Future<void>.value()).then((_) {
        return _libraryStore?.refreshProgress() ?? Future<void>.value();
      }),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppProvidersScope.of(context).readerStore;

    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final state = store.state;
        const readingBackgroundColor = Color(0xFFFFFFFF);

        if (state.isLoading) {
          _markSpinnerVisible(reason: 'store_loading');
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (state.book == null) {
          _markSpinnerHidden();
          return const Scaffold(body: Center(child: Text('Book not found')));
        }

        final pub = _publication;
        if (pub == null) {
          _markSpinnerVisible(reason: 'waiting_publication');
        } else {
          _markSpinnerHidden();
          _markFirstPaintAfterSpinner();
        }

        return Scaffold(
          backgroundColor: readingBackgroundColor,
          body: pub != null
              ? ColoredBox(
                  color: readingBackgroundColor,
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: MediaQuery.viewPaddingOf(context).top,
                      bottom: MediaQuery.viewPaddingOf(context).bottom,
                    ),
                    child: ReadiumReaderWidget(
                      publication: pub,
                      sessionId: widget.bookId,
                      onReady: () {
                        ReaderPerf.mark(
                          'page.reader_widget_ready',
                          bookId: widget.bookId,
                        );
                        unawaited(subscribeToChannels());
                      },
                    ),
                  ),
                )
              : const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }

  void _markSpinnerVisible({required String reason}) {
    if (_spinnerVisible && _spinnerReason == reason) {
      return;
    }
    if (!_spinnerVisible) {
      _spinnerVisible = true;
      _spinnerShownAt = DateTime.now();
      _spinnerInitialReason = reason;
      _spinnerReason = reason;
      ReaderPerf.mark(
        'page.spinner.show',
        bookId: widget.bookId,
        extras: <String, Object?>{'reason': reason},
      );
      return;
    }
    _spinnerReason = reason;
    ReaderPerf.mark(
      'page.spinner.stage_change',
      bookId: widget.bookId,
      extras: <String, Object?>{'reason': reason},
    );
  }

  void _markSpinnerHidden() {
    if (!_spinnerVisible) {
      return;
    }
    final shownAt = _spinnerShownAt;
    _spinnerVisible = false;
    _spinnerShownAt = null;
    final elapsed = shownAt == null
        ? null
        : DateTime.now().difference(shownAt).inMilliseconds;
    ReaderPerf.mark(
      'page.spinner.hide',
      bookId: widget.bookId,
      elapsedMs: elapsed,
      extras: <String, Object?>{
        'initial_reason': _spinnerInitialReason,
        'final_reason': _spinnerReason,
      },
    );
    ReaderPerf.mark(
      'page.spinner.total_visible',
      bookId: widget.bookId,
      elapsedMs: elapsed,
    );
    _spinnerInitialReason = null;
    _spinnerReason = null;
    _pendingFirstPaintAfterSpinner = true;
  }

  void _markFirstPaintAfterSpinner() {
    if (!_pendingFirstPaintAfterSpinner) {
      return;
    }
    _pendingFirstPaintAfterSpinner = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ReaderPerf.mark(
        'page.first_paint_after_spinner_hide',
        bookId: widget.bookId,
      );
    });
  }
}
