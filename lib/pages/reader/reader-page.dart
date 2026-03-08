import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flureadium/flureadium.dart';
import 'package:path/path.dart' as p;
import '../../services/reader/publication-cache-service.dart';

import '../../app/i18n/app-localizations.dart';
import '../../app/providers/app-providers.dart';
import '../../app/routes/route-names.dart';
import '../../entities/book-entity.dart';
import '../../shared/utils/cover-image-cache.dart';
import '../../entities/highlight-entity.dart';
import '../../entities/reader-preferences-entity.dart';
import '../../services/reader/reader-theme-service.dart';
import '../../stores/highlight/highlight-store.dart';
import '../../stores/reader/reader-store.dart';
import '../../shared/ui/loading-view.dart';

class ReaderPage extends StatefulWidget {
  const ReaderPage({required this.bookId, super.key});

  final String bookId;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  final Flureadium _flureadium = Flureadium();
  final ReaderThemeService _readerThemeService = ReaderThemeService();
  final PublicationCacheService _pubCache = PublicationCacheService();

  bool _isChromeVisible = false;
  bool _initialized = false;
  Publication? _publication;
  Locator? _currentLocator;

  ReaderStore? _readerStore;
  HighlightStore? _highlightStore;

  StreamSubscription<Locator>? _locatorSub;
  StreamSubscription<ReadiumReaderStatus>? _statusSub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _initReader();
    }
  }

  Future<void> _initReader() async {
    final providers = AppProvidersScope.of(context);
    _readerStore = providers.readerStore;
    _highlightStore = providers.highlightStore;

    await _readerStore!.openBook(widget.bookId);
    unawaited(_highlightStore!.loadHighlights(widget.bookId));
    if (!mounted) return;

    final epubPath = _readerStore!.state.book?.epubFilePath;
    if (epubPath == null) return;

    final resolvedPath = _resolveEpubPath(epubPath);
    try {
      final pub = await _pubCache.getOrOpen(resolvedPath);
      if (!mounted) return;
      setState(() => _publication = pub);
    } catch (e) {
      debugPrint('Failed to open publication: $e');
    }
  }

  String _resolveEpubPath(String storedPath) {
    if (p.isAbsolute(storedPath)) return storedPath;
    final docsPath = AppProvidersScope.of(context).documentsDirectoryPath;
    return p.join(docsPath, storedPath);
  }

  void _subscribeToChannels() {
    _statusSub?.cancel();
    _locatorSub?.cancel();
    _statusSub = _flureadium.onReaderStatusChanged.listen(
      (s) => debugPrint('ReaderStatus: $s'),
    );
    _locatorSub = _flureadium.onTextLocatorChanged.listen((locator) {
      _currentLocator = locator;
      final json = _locatorToJson(locator);
      _readerStore?.updateLocator(json);
    });
    _readerStore?.onReaderReady();

    _restoreSavedPosition();
    _applyCurrentPreferences();
    _applyHighlightDecorations();
  }

  Future<void> _restoreSavedPosition() async {
    final locatorJson = _readerStore?.savedLocatorJson;
    if (locatorJson == null || locatorJson.isEmpty) return;
    try {
      final map = jsonDecode(locatorJson) as Map<String, dynamic>;
      final locator = Locator.fromJson(map);
      if (locator == null) return;
      await _flureadium.goToLocator(locator);
    } catch (_) {}
  }

  Future<void> _applyCurrentPreferences() async {
    final prefs = _readerStore?.state.preferences;
    if (prefs == null) return;
    await _applyPreferencesToReadium(prefs);
  }

  Future<void> _applyPreferencesToReadium(ReaderPreferencesEntity prefs) async {
    final fontFamily = _readerThemeService.fontFamily(prefs.fontFamily);
    await _flureadium.setEPUBPreferences(
      EPUBPreferences(
        fontFamily: fontFamily ?? 'sans-serif',
        fontSize: (prefs.fontSize * 100 / 19).round(),
        fontWeight: null,
        verticalScroll: prefs.pageTurnMode == 'vertical',
        backgroundColor: prefs.backgroundColor,
        textColor: prefs.textColor,
      ),
    );
  }

  Future<void> _applyHighlightDecorations() async {
    final items = _highlightStore?.state.items ?? const <HighlightEntity>[];
    final decorations = <ReaderDecoration>[];
    for (final item in items) {
      try {
        final map = jsonDecode(item.locatorJson) as Map<String, dynamic>;
        final locator = Locator.fromJson(map);
        if (locator == null) continue;
        decorations.add(
          ReaderDecoration(
            id: item.id,
            locator: locator,
            style: ReaderDecorationStyle(
              style: DecorationStyle.highlight,
              tint: _parseHighlightColor(item.color),
            ),
          ),
        );
      } catch (_) {}
    }
    if (decorations.isNotEmpty) {
      await _flureadium.applyDecorations('highlights', decorations);
    }
  }

  Color _parseHighlightColor(String hex) {
    try {
      final cleaned = hex.replaceFirst('#', '');
      if (cleaned.length == 6) {
        return Color(int.parse('FF$cleaned', radix: 16));
      }
      if (cleaned.length == 8) {
        return Color(int.parse(cleaned, radix: 16));
      }
    } catch (_) {}
    return const Color(0xFFFFE082);
  }

  String _locatorToJson(Locator locator) {
    try {
      return jsonEncode(locator.toJson());
    } catch (_) {
      return '{}';
    }
  }

  @override
  void dispose() {
    _locatorSub?.cancel();
    _statusSub?.cancel();
    // Publication is NOT closed here — PublicationCacheService keeps it alive
    // so reopening the same book skips the expensive native EPUB parsing.
    unawaited(_readerStore?.flushProgress(emitStateChanges: false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final providers = AppProvidersScope.of(context);
    final readerStore = providers.readerStore;
    final highlightStore = providers.highlightStore;

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[readerStore, highlightStore]),
      builder: (context, _) {
        final state = readerStore.state;
        final localizations = AppLocalizations.of(context);

        if (state.isLoading) {
          return const Scaffold(body: LoadingView());
        }
        if (state.book == null) {
          return Scaffold(
            body: Center(child: Text(localizations.tr('bookNotFound'))),
          );
        }

        final preferences =
            state.preferences ??
            ReaderPreferencesEntity.defaultsForBook(widget.bookId);
        final pub = _publication;

        return Scaffold(
          backgroundColor: preferences.backgroundColor,
          body: Stack(
            children: <Widget>[
              if (pub != null)
                Positioned.fill(
                  child: ReadiumReaderWidget(
                    publication: pub,
                    onTap: _handleReaderTap,
                    onReady: _subscribeToChannels,
                  ),
                )
              else
                const Center(child: CircularProgressIndicator()),
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: true,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    color: Colors.black.withValues(
                      alpha: (preferences.brightness.clamp(0, 1) * 0.62),
                    ),
                  ),
                ),
              ),
              _TopReaderChrome(
                isVisible: _isChromeVisible,
                onBack: () {
                  Navigator.of(context).maybePop();
                },
                onOpenMore: () {
                  _openMoreSheet(state.book!, localizations);
                },
              ),
              _BottomReaderChrome(
                isVisible: _isChromeVisible,
                activeIndex: null,
                onTapChapter: () => _openChapterList(pub),
                onTapHighlights: _openHighlightsSheet,
                onTapProgress: _openProgressSheet,
                onTapBrightness: _openBrightnessSheet,
                onTapFont: _openFontSheet,
              ),
              Positioned(
                right: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
                child: IgnorePointer(
                  ignoring: _isChromeVisible,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 140),
                    opacity: _isChromeVisible ? 0 : 1,
                    child: Text(
                      '${(state.bookPercent * 100).round()}%',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleReaderTap() {
    setState(() {
      _isChromeVisible = !_isChromeVisible;
    });
  }

  Future<void> _openChapterList(Publication? pub) async {
    if (pub == null) return;
    final toc = pub.tableOfContents;
    if (toc.isEmpty) {
      _showComingSoon();
      return;
    }

    final selected = await showModalBottomSheet<Link>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.82,
            child: ListView.separated(
              itemCount: toc.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final link = toc[index];
                return ListTile(
                  title: Text(link.title ?? 'Chapter ${index + 1}'),
                  onTap: () => Navigator.of(context).pop(link),
                );
              },
            ),
          ),
        );
      },
    );

    if (selected != null) {
      await _flureadium.goByLink(selected, pub);
    }
  }

  Future<void> _addHighlightFromLocator() async {
    final loc = _currentLocator;
    if (loc == null) return;

    final locJson = _locatorToJson(loc);
    final selectedText = loc.text?.highlight ?? '';
    if (selectedText.isEmpty) return;

    try {
      final highlight = await _highlightStore?.createHighlight(
        bookId: widget.bookId,
        locatorJson: locJson,
        selectedText: selectedText,
      );
      if (highlight != null) {
        await _applyHighlightDecorations();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Highlight failed: $e')),
      );
    }
  }

  Future<void> _openHighlightsSheet() async {
    final highlights =
        _highlightStore?.state.items ?? const <HighlightEntity>[];
    final book = _readerStore?.state.book;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.82,
            child: Column(
              children: <Widget>[
                if (book != null)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                book.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '共 ${highlights.length} 条笔记',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF5F6673),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.menu_book_rounded),
                      ],
                    ),
                  ),
                Expanded(
                  child: highlights.isEmpty
                      ? const Center(child: Text('No highlights'))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: highlights.length,
                          itemBuilder: (context, index) {
                            final item = highlights[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                item.selectedText,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 17,
                                  height: 1.45,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openProgressSheet() async {
    final store = _readerStore;
    if (store == null) return;
    final state = store.state;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: 340,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _MetricBlock(
                          value: '${(state.bookPercent * 100).round()}%',
                          label: '阅读进度',
                        ),
                      ),
                      Expanded(
                        child: _MetricBlock(
                          value:
                              '${_highlightStore?.state.items.length ?? 0} 条',
                          label: '笔记',
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: const <Widget>[
                      Expanded(child: _PillAction(label: '阅读明细')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openBrightnessSheet() async {
    final store = _readerStore;
    if (store == null) return;
    final prefs =
        store.state.preferences ??
        ReaderPreferencesEntity.defaultsForBook(widget.bookId);

    final textColors = <Color>[
      const Color(0xFF0E0E0E),
      const Color(0xFFDAD4C2),
      const Color(0xFF9ED1A5),
      const Color(0xFF3B4252),
    ];
    final bgColors = <Color>[
      const Color(0xFFF2F2F2),
      const Color(0xFFF1EEE7),
      const Color(0xFFEAEFF6),
      const Color(0xFFE6F0FD),
    ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: 360,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Slider(
                    value: prefs.brightness,
                    onChanged: (value) {
                      unawaited(
                        store.updatePreferences(
                          (current) => current.copyWith(brightness: value),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '颜色',
                    style: TextStyle(fontSize: 20, color: Color(0xFF9BA1AC)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    children: textColors
                        .map((color) {
                          final selected =
                              color.toARGB32() == prefs.textColor.toARGB32();
                          return _ColorChip(
                            color: color,
                            selected: selected,
                            onTap: () {
                              unawaited(
                                store.updatePreferences((current) {
                                  final updated =
                                      current.copyWith(textColor: color);
                                  _applyPreferencesToReadium(updated);
                                  return updated;
                                }),
                              );
                            },
                          );
                        })
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '背景',
                    style: TextStyle(fontSize: 20, color: Color(0xFF9BA1AC)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    children: bgColors
                        .map((color) {
                          final selected =
                              color.toARGB32() ==
                              prefs.backgroundColor.toARGB32();
                          return _ColorChip(
                            color: color,
                            selected: selected,
                            onTap: () {
                              unawaited(
                                store.updatePreferences((current) {
                                  final updated =
                                      current.copyWith(backgroundColor: color);
                                  _applyPreferencesToReadium(updated);
                                  return updated;
                                }),
                              );
                            },
                          );
                        })
                        .toList(growable: false),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openFontSheet() async {
    final store = _readerStore;
    if (store == null) return;
    final prefs =
        store.state.preferences ??
        ReaderPreferencesEntity.defaultsForBook(widget.bookId);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: 410,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
              child: Column(
                children: <Widget>[
                  _FontSizeSlider(
                    value: prefs.fontSize,
                    onChanged: (value) {
                      unawaited(
                        store.updatePreferences((current) {
                          final updated = current.copyWith(fontSize: value);
                          _applyPreferencesToReadium(updated);
                          return updated;
                        }),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _TriSegment(
                          left: '小',
                          center: '边距',
                          right: '大',
                          selected: prefs.pagePaddingLevel,
                          onChanged: (value) {
                            unawaited(
                              store.updatePreferences(
                                (current) =>
                                    current.copyWith(pagePaddingLevel: value),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TriSegment(
                          left: '紧',
                          center: '行距',
                          right: '松',
                          selected: prefs.lineHeightLevel,
                          onChanged: (value) {
                            final spacing = switch (value) {
                              0 => -0.1,
                              2 => 0.35,
                              _ => 0.0,
                            };
                            unawaited(
                              store.updatePreferences((current) {
                                final updated = current.copyWith(
                                  lineHeightLevel: value,
                                  letterSpacing: spacing,
                                );
                                _applyPreferencesToReadium(updated);
                                return updated;
                              }),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _PillAction(
                          label: prefs.fontFamily == 'sans'
                              ? 'System'
                              : 'Athelas',
                          onTap: () {
                            unawaited(
                              store.updatePreferences((current) {
                                final updated = current.copyWith(
                                  fontFamily: current.fontFamily == 'sans'
                                      ? 'serif'
                                      : 'sans',
                                );
                                _applyPreferencesToReadium(updated);
                                return updated;
                              }),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(child: _PillAction(label: '左右滑动')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openMoreSheet(
    BookEntity book,
    AppLocalizations localizations,
  ) async {
    final coverBytes = CoverImageCache.decode(book.coverUrl);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height * 0.45,
              ),
              child: Column(
                children: <Widget>[
                  InkWell(
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pushNamed(
                        RouteNames.bookDetail,
                        arguments: widget.bookId,
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE8E8EC)),
                      ),
                      child: Row(
                        children: <Widget>[
                          _BookCoverPreview(coverBytes: coverBytes),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  book.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  book.author,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFF7A808C),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 24,
                    runSpacing: 22,
                    children: <Widget>[
                      _RoundMenuAction(
                        icon: Icons.highlight,
                        label: localizations.tr('highlightAction'),
                        onTap: () {
                          Navigator.of(context).pop();
                          _addHighlightFromLocator();
                        },
                      ),
                      _RoundMenuAction(
                        icon: Icons.bookmark_add_outlined,
                        label: localizations.tr('readerAddBookmark'),
                        onTap: _showComingSoon,
                      ),
                      _RoundMenuAction(
                        icon: Icons.search,
                        label: localizations.tr('readerGlobalSearch'),
                        onTap: _showComingSoon,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).tr('menuComingSoon')),
      ),
    );
  }
}

class _TopReaderChrome extends StatelessWidget {
  const _TopReaderChrome({
    required this.isVisible,
    required this.onBack,
    required this.onOpenMore,
  });

  final bool isVisible;
  final VoidCallback onBack;
  final VoidCallback onOpenMore;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !isVisible,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: isVisible ? 1 : 0,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 52,
              child: Row(
                children: <Widget>[
                  IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_ios_new),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onOpenMore,
                    icon: const Icon(Icons.more_vert),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomReaderChrome extends StatelessWidget {
  const _BottomReaderChrome({
    required this.isVisible,
    required this.activeIndex,
    required this.onTapChapter,
    required this.onTapHighlights,
    required this.onTapProgress,
    required this.onTapBrightness,
    required this.onTapFont,
  });

  final bool isVisible;
  final int? activeIndex;
  final VoidCallback onTapChapter;
  final VoidCallback onTapHighlights;
  final VoidCallback onTapProgress;
  final VoidCallback onTapBrightness;
  final VoidCallback onTapFont;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !isVisible,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: isVisible ? 1 : 0,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.96),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 10,
                  offset: Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 62,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    _BottomIconButton(
                      icon: Icons.menu,
                      active: activeIndex == 0,
                      onTap: onTapChapter,
                    ),
                    _BottomIconButton(
                      icon: Icons.edit_note_outlined,
                      active: activeIndex == 1,
                      onTap: onTapHighlights,
                    ),
                    _BottomIconButton(
                      icon: Icons.adjust,
                      active: activeIndex == 2,
                      onTap: onTapProgress,
                    ),
                    _BottomIconButton(
                      icon: Icons.wb_sunny_outlined,
                      active: activeIndex == 3,
                      onTap: onTapBrightness,
                    ),
                    _BottomIconButton(
                      icon: Icons.text_fields,
                      active: activeIndex == 4,
                      onTap: onTapFont,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomIconButton extends StatelessWidget {
  const _BottomIconButton({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(
        icon,
        color: active ? const Color(0xFF1685FF) : const Color(0xFF666D79),
      ),
    );
  }
}

class _RoundMenuAction extends StatelessWidget {
  const _RoundMenuAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: SizedBox(
        width: 98,
        child: Column(
          children: <Widget>[
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFD7E9FF) : Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 38,
                color: selected
                    ? const Color(0xFF1685FF)
                    : const Color(0xFF5A6270),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF596171),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookCoverPreview extends StatelessWidget {
  const _BookCoverPreview({required this.coverBytes});

  final Uint8List? coverBytes;

  @override
  Widget build(BuildContext context) {
    final image = coverBytes != null
        ? ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              coverBytes!,
              width: 78,
              height: 106,
              fit: BoxFit.cover,
            ),
          )
        : Container(
            width: 78,
            height: 106,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: const Color(0xFFF0F0F2),
            ),
            child: const Icon(Icons.menu_book_outlined),
          );
    return image;
  }
}

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF8B919D), fontSize: 14),
        ),
      ],
    );
  }
}

class _PillAction extends StatelessWidget {
  const _PillAction({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: const Color(0xFFF0F0F2),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _ColorChip extends StatelessWidget {
  const _ColorChip({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 74,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFF1685FF) : Colors.transparent,
            width: 2,
          ),
        ),
      ),
    );
  }
}

class _FontSizeSlider extends StatelessWidget {
  const _FontSizeSlider({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F2),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: <Widget>[
          const Text(
            'A',
            style: TextStyle(fontSize: 24, color: Color(0xFF6A7180)),
          ),
          Expanded(
            child: Slider(min: 14, max: 30, value: value, onChanged: onChanged),
          ),
          Text(
            value.round().toString(),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          const Text(
            'A',
            style: TextStyle(fontSize: 32, color: Color(0xFF6A7180)),
          ),
        ],
      ),
    );
  }
}

class _TriSegment extends StatelessWidget {
  const _TriSegment({
    required this.left,
    required this.center,
    required this.right,
    required this.selected,
    required this.onChanged,
  });

  final String left;
  final String center;
  final String right;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final labels = <String>[left, center, right];
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F2),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: List<Widget>.generate(3, (index) {
          final active = index == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(index),
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: active ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
                ),
                alignment: Alignment.center,
                child: Text(
                  labels[index],
                  style: TextStyle(
                    fontSize: 16,
                    color: const Color(0xFF5D6572),
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
