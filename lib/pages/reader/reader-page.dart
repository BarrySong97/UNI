import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../app/i18n/app-localizations.dart';
import '../../app/providers/app-providers.dart';
import '../../app/routes/route-names.dart';
import '../../components/reader/selectable-paragraph.dart';
import '../../entities/book-entity.dart';
import '../../entities/chapter-entity.dart';
import '../../entities/highlight-entity.dart';
import '../../entities/reader-preferences-entity.dart';
import '../../services/reader/reader-page-slice.dart';
import '../../services/reader/reader-theme-service.dart';
import '../../stores/highlight/highlight-store.dart';
import '../../stores/reader/reader-state.dart';
import '../../stores/reader/reader-store.dart';
import '../../shared/ui/loading-view.dart';

class ReaderPage extends StatefulWidget {
  const ReaderPage({required this.bookId, super.key});

  final String bookId;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  final FocusNode _selectionFocusNode = FocusNode(
    debugLabel: 'reader-selection-focus',
  );
  final PageController _pageController = PageController();

  bool _isChromeVisible = false;
  bool _hasActiveSelection = false;
  int _selectionEpoch = 0;
  String _layoutSignature = '';
  final ReaderThemeService _readerThemeService = ReaderThemeService();

  ReaderStore? _readerStore;
  HighlightStore? _highlightStore;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final providers = AppProvidersScope.of(context);
      _readerStore = providers.readerStore;
      _highlightStore = providers.highlightStore;

      await _readerStore!.openBook(widget.bookId);
      unawaited(_highlightStore!.loadHighlights(widget.bookId));
      if (!mounted) {
        return;
      }
      _syncPageController();
    });
  }

  @override
  void dispose() {
    _selectionFocusNode.dispose();
    _pageController.dispose();
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
        if (state.book == null || state.chapters.isEmpty) {
          return Scaffold(
            body: Center(child: Text(localizations.tr('bookNotFound'))),
          );
        }

        final preferences =
            state.preferences ??
            ReaderPreferencesEntity.defaultsForBook(widget.bookId);

        return LayoutBuilder(
          builder: (context, constraints) {
            _rebuildPaginationIfNeeded(
              state: state,
              preferences: preferences,
              size: constraints.biggest,
            );
            final safeBottom = MediaQuery.of(context).padding.bottom;
            final pages = state.pageSlices;
            final activePage = pages.isEmpty
                ? null
                : pages[state.currentPageIndex.clamp(0, pages.length - 1)];

            return Scaffold(
              backgroundColor: preferences.backgroundColor,
              body: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: pages.isEmpty
                        ? const SizedBox.shrink()
                        : PageView.builder(
                            controller: _pageController,
                            itemCount: pages.length,
                            onPageChanged: (index) {
                              readerStore.jumpToPage(index);
                              if (index >= pages.length - 2 || index <= 1) {
                                unawaited(
                                  readerStore.warmUpWindowPagination(
                                    chapterIndex: pages[index].chapterIndex,
                                  ),
                                );
                              }
                            },
                            itemBuilder: (context, index) {
                              final page = pages[index];
                              return _ReaderTextPage(
                                key: ValueKey<String>(
                                  'reader-page-${page.chapterId}-${page.startOffset}-$index',
                                ),
                                page: page,
                                highlights: _highlightsForChapter(
                                  highlightStore.state.items,
                                  page.chapterId,
                                ),
                                preferences: preferences,
                                selectionEpoch: _selectionEpoch,
                                selectionFocusNode: _selectionFocusNode,
                                highlightActionLabel: localizations.tr(
                                  'highlightAction',
                                ),
                                onSelectionChanged: (selection) {
                                  _hasActiveSelection = !selection.isCollapsed;
                                },
                                onHighlightRequested: (selection) {
                                  unawaited(
                                    _createHighlightFromSelection(
                                      page: page,
                                      highlightStore: highlightStore,
                                      selection: selection,
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _handleReaderTap,
                    ),
                  ),
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
                    activeIndex: _activeBottomIndex(),
                    onTapChapter: _openChapterList,
                    onTapHighlights: _openHighlightsSheet,
                    onTapProgress: _openProgressSheet,
                    onTapBrightness: _openBrightnessSheet,
                    onTapFont: _openFontSheet,
                  ),
                  Positioned(
                    right: 16,
                    bottom: safeBottom + 16,
                    child: IgnorePointer(
                      ignoring: _isChromeVisible,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 140),
                        opacity: _isChromeVisible ? 0 : 1,
                        child: Builder(
                          builder: (context) {
                            final isCatalogReady =
                                state.catalogMetricsStatus == 'ready';
                            final String pageLabel;
                            if (isCatalogReady && state.catalogTotalPages > 1) {
                              final metrics = readerStore
                                  .catalogPaginationMetrics();
                              final globalCurrent = _currentCatalogPage(
                                store: readerStore,
                                chapterStartPages: metrics.chapterStartPages,
                              );
                              pageLabel =
                                  '$globalCurrent / ${state.catalogTotalPages}';
                            } else {
                              pageLabel =
                                  '${state.currentPage} / ${state.totalPages}';
                            }
                            return Text(
                              pageLabel,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w600,
                                  ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  if (activePage != null)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 12,
                      left: 18,
                      right: 18,
                      child: IgnorePointer(
                        ignoring: true,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 160),
                          opacity: _isChromeVisible ? 0 : 1,
                          child: Text(
                            activePage.chapterTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: Colors.grey.shade600),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  int? _activeBottomIndex() {
    return null;
  }

  void _rebuildPaginationIfNeeded({
    required ReaderState state,
    required ReaderPreferencesEntity preferences,
    required Size size,
  }) {
    final bodyText = _readerThemeService.buildPaginationTextStyle(preferences);
    final horizontalPadding = _readerThemeService.horizontalPadding(
      preferences.pagePaddingLevel,
    );
    const verticalPadding = 96.0;
    final textVersion = _readerStore?.buildTextVersion(state.chapters) ?? 'na';
    final signature = <Object?>[
      size.width.toStringAsFixed(2),
      size.height.toStringAsFixed(2),
      preferences.fontSize,
      preferences.pagePaddingLevel,
      preferences.lineHeightLevel,
      preferences.letterSpacing,
      preferences.firstLineIndent,
      preferences.fontFamily,
      state.currentChapterIndex,
      state.chapters.length,
      state.chapters.fold<int>(
        0,
        (sum, chapter) => sum + chapter.content.length,
      ),
      textVersion,
    ].join('_');

    if (signature == _layoutSignature) {
      return;
    }
    _layoutSignature = signature;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _readerStore == null) {
        return;
      }

      final restored = await _readerStore!.restoreWindowFromCache(
        layoutKey: signature,
        chapterStart: _readerStore!.state.windowChapterStart,
        chapterEnd: _readerStore!.state.windowChapterEnd,
      );
      if (!mounted) {
        return;
      }
      if (restored) {
        _syncPageController();
      } else {
        // Math pagination is fast enough to run directly — no approx/timer.
        _readerStore!.rebuildPagination(
          layoutKey: signature,
          viewport: size,
          textStyle: bodyText,
          horizontalPadding: horizontalPadding,
          verticalPadding: verticalPadding,
        );
        _syncPageController();
      }

      // Always ensure catalog metrics are fresh after any layout change.
      unawaited(_readerStore!.ensureCatalogMetricsReady());
    });
  }

  void _syncPageController() {
    final store = _readerStore;
    if (store == null || !_pageController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController.hasClients || _readerStore == null) {
          return;
        }
        final target = _readerStore!.state.currentPageIndex;
        _pageController.jumpToPage(target);
      });
      return;
    }
    final target = store.state.currentPageIndex;
    final current = _pageController.page?.round() ?? 0;
    if (target != current) {
      _pageController.jumpToPage(target);
    }
  }

  void _handleReaderTap() {
    if (_hasActiveSelection) {
      return;
    }
    setState(() {
      _isChromeVisible = !_isChromeVisible;
      _selectionEpoch++;
    });
    _selectionFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  List<HighlightEntity> _highlightsForChapter(
    List<HighlightEntity> all,
    String chapterId,
  ) {
    return all
        .where((item) => item.chapterId == chapterId)
        .toList(growable: false);
  }

  Future<void> _createHighlightFromSelection({
    required ReaderPageSlice page,
    required HighlightStore highlightStore,
    required TextSelection selection,
  }) async {
    if (selection.isCollapsed) {
      return;
    }

    final store = _readerStore;
    if (store == null) {
      return;
    }
    final chapter = store.state.chapters[page.chapterIndex];
    final start = selection.start < selection.end
        ? selection.start
        : selection.end;
    final end = selection.start < selection.end
        ? selection.end
        : selection.start;

    final chapterStart = (page.startOffset + start).clamp(
      0,
      chapter.content.length,
    );
    final chapterEnd = (page.startOffset + end).clamp(
      0,
      chapter.content.length,
    );

    try {
      await highlightStore.createHighlight(
        bookId: widget.bookId,
        chapterId: chapter.id,
        chapterText: chapter.content,
        startOffset: chapterStart,
        endOffset: chapterEnd,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Highlight failed: $error')));
    }
  }

  Future<void> _openChapterList() async {
    final store = _readerStore;
    if (store == null) {
      return;
    }
    unawaited(store.ensureCatalogMetricsReady());

    final selectedChapter = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return AnimatedBuilder(
              animation: store,
              builder: (context, _) {
                final chapters = store.state.chapters;
                final filtered = chapters
                    .where((chapter) {
                      if (query.trim().isEmpty) {
                        return true;
                      }
                      return chapter.title.toLowerCase().contains(
                        query.toLowerCase(),
                      );
                    })
                    .toList(growable: false);
                final metrics = store.catalogPaginationMetrics();
                final chapterStartPages = metrics.chapterStartPages;
                final catalogTotalPages = metrics.totalPages;
                final currentGlobalPage = _currentCatalogPage(
                  store: store,
                  chapterStartPages: chapterStartPages,
                );
                final isCatalogReady =
                    store.state.catalogMetricsStatus == 'ready';

                return SafeArea(
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.82,
                    child: Column(
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                          child: TextField(
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search),
                              hintText: AppLocalizations.of(
                                context,
                              ).tr('readerSearchBook'),
                              filled: true,
                              fillColor: const Color(0xFFF0F0F2),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(26),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onChanged: (value) {
                              setSheetState(() {
                                query = value;
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final chapter = filtered[index];
                              final chapterIndex = chapters.indexWhere(
                                (c) => c.id == chapter.id,
                              );
                              final isCurrentChapter =
                                  chapterIndex ==
                                  store.state.currentChapterIndex;
                              final chapterStartPage =
                                  chapterStartPages[chapterIndex] ?? 1;
                              final localizations = AppLocalizations.of(
                                context,
                              );
                              final chapterTitle = _chapterDisplayTitle(
                                chapter: chapter,
                                languageCode: localizations.locale.languageCode,
                              );
                              return ListTile(
                                title: Text(
                                  chapterTitle,
                                  style: TextStyle(
                                    color: isCurrentChapter
                                        ? const Color(0xFF1685FF)
                                        : null,
                                    fontWeight: isCurrentChapter
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                                subtitle: isCurrentChapter
                                    ? Text(
                                        localizations
                                            .tr('readerCurrentReadProgress')
                                            .replaceAll(
                                              '{current}',
                                              '$currentGlobalPage',
                                            )
                                            .replaceAll(
                                              '{total}',
                                              '$catalogTotalPages',
                                            ),
                                      )
                                    : null,
                                trailing: Text(
                                  isCatalogReady ? '$chapterStartPage' : '--',
                                ),
                                onTap: () {
                                  Navigator.of(context).pop(chapterIndex);
                                },
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
          },
        );
      },
    );

    if (selectedChapter == null) {
      return;
    }
    await _jumpToChapter(selectedChapter);
  }

  int _firstPageIndexForChapterInWindow(int chapterIndex) {
    final pages = _readerStore?.state.pageSlices ?? const <ReaderPageSlice>[];
    if (chapterIndex < 0 || pages.isEmpty) {
      return 0;
    }
    for (var i = 0; i < pages.length; i++) {
      if (pages[i].chapterIndex == chapterIndex) {
        return i;
      }
    }
    return 0;
  }

  String _chapterDisplayTitle({
    required ChapterEntity chapter,
    required String languageCode,
  }) {
    final trimmed = chapter.title.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
    if (languageCode == 'zh') {
      return '第${chapter.idx + 1}章';
    }
    return 'Chapter ${chapter.idx + 1}';
  }

  int _currentCatalogPage({
    required ReaderStore store,
    required Map<int, int> chapterStartPages,
  }) {
    final currentChapter = store.state.currentChapterIndex;
    final chapterStart = chapterStartPages[currentChapter] ?? 1;
    final chapterFirstPageInWindow = _firstPageIndexForChapterInWindow(
      currentChapter,
    );
    final localOffset = store.state.currentPageIndex - chapterFirstPageInWindow;
    return chapterStart + (localOffset < 0 ? 0 : localOffset);
  }

  Future<void> _jumpToChapter(int chapterIndex) async {
    final store = _readerStore;
    if (store == null) {
      return;
    }
    await store.switchChapterByIndex(chapterIndex);
    _layoutSignature = '';
  }

  void _jumpToPage(int pageIndex) {
    final store = _readerStore;
    if (store == null) {
      return;
    }
    final total = store.state.pageSlices.length;
    if (total == 0) {
      return;
    }
    final safePage = pageIndex.clamp(0, total - 1).toInt();
    store.jumpToPage(safePage);
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        safePage,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _openMoreSheet(
    BookEntity book,
    AppLocalizations localizations,
  ) async {
    final coverBytes = _decodeCoverDataUrl(book.coverUrl);
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
                        icon: Icons.cloud_done_outlined,
                        label: localizations.tr('readerDownloadDone'),
                        onTap: _showComingSoon,
                      ),
                      _RoundMenuAction(
                        icon: Icons.flip,
                        label: localizations.tr('readerAutoFlip'),
                        onTap: _showComingSoon,
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
                      _RoundMenuAction(
                        icon: Icons.edit_note_outlined,
                        label: localizations.tr('readerOpenNotes'),
                        onTap: _showComingSoon,
                      ),
                      _RoundMenuAction(
                        icon: Icons.chat_bubble_outline,
                        label: localizations.tr('readerBookThoughts'),
                        selected: true,
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
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: () {
                                  Navigator.of(context).pop();
                                  Navigator.of(context).pushNamed(
                                    RouteNames.bookDetail,
                                    arguments: widget.bookId,
                                  );
                                },
                                child: const Text(
                                  '阅读明细',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFF1685FF),
                                    fontWeight: FontWeight.w600,
                                  ),
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
    if (store == null) {
      return;
    }
    final state = store.state;
    final total = state.totalPages;
    var sliderValue = total <= 1 ? 0.0 : state.currentPageIndex / (total - 1);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
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
                              label: '约 2 小时后读完',
                            ),
                          ),
                          Expanded(
                            child: _MetricBlock(
                              value: '10小时27分钟',
                              label: '阅读时长',
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
                      const SizedBox(height: 26),
                      Slider(
                        value: sliderValue,
                        onChanged: (value) {
                          setSheetState(() {
                            sliderValue = value;
                          });
                        },
                        onChangeEnd: (value) {
                          final page = ((total - 1) * value).round();
                          _jumpToPage(page);
                        },
                      ),
                      const Spacer(),
                      Row(
                        children: const <Widget>[
                          Expanded(child: _PillAction(label: '阅读明细')),
                          SizedBox(width: 12),
                          Expanded(child: _PillAction(label: '开启自动翻页')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openBrightnessSheet() async {
    final store = _readerStore;
    if (store == null) {
      return;
    }
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
                                store.updatePreferences(
                                  (current) =>
                                      current.copyWith(textColor: color),
                                ),
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
                                store.updatePreferences(
                                  (current) =>
                                      current.copyWith(backgroundColor: color),
                                ),
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
    if (store == null) {
      return;
    }
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
                        store.updatePreferences(
                          (current) => current.copyWith(fontSize: value),
                        ),
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
                              store.updatePreferences(
                                (current) => current.copyWith(
                                  lineHeightLevel: value,
                                  letterSpacing: spacing,
                                ),
                              ),
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
                              store.updatePreferences(
                                (current) => current.copyWith(
                                  fontFamily: current.fontFamily == 'sans'
                                      ? 'serif'
                                      : 'sans',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PillAction(
                          label: prefs.firstLineIndent ? '首行顶格' : '首行缩进',
                          onTap: () {
                            unawaited(
                              store.updatePreferences(
                                (current) => current.copyWith(
                                  firstLineIndent: !current.firstLineIndent,
                                ),
                              ),
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

  Uint8List? _decodeCoverDataUrl(String? dataUrl) {
    if (dataUrl == null || !dataUrl.startsWith('data:image/')) {
      return null;
    }
    const marker = ';base64,';
    final markerIndex = dataUrl.indexOf(marker);
    if (markerIndex <= 0 || markerIndex + marker.length >= dataUrl.length) {
      return null;
    }
    final payload = dataUrl.substring(markerIndex + marker.length);
    try {
      return base64Decode(payload);
    } catch (_) {
      return null;
    }
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).tr('menuComingSoon')),
      ),
    );
  }
}

class _ReaderTextPage extends StatelessWidget {
  const _ReaderTextPage({
    required this.page,
    required this.highlights,
    required this.preferences,
    required this.selectionEpoch,
    required this.selectionFocusNode,
    required this.highlightActionLabel,
    required this.onSelectionChanged,
    required this.onHighlightRequested,
    super.key,
  });

  final ReaderPageSlice page;
  final List<HighlightEntity> highlights;
  final ReaderPreferencesEntity preferences;
  final int selectionEpoch;
  final FocusNode selectionFocusNode;
  final String highlightActionLabel;
  final void Function(TextSelection selection) onSelectionChanged;
  final void Function(TextSelection selection) onHighlightRequested;
  static final ReaderThemeService _readerThemeService = ReaderThemeService();

  @override
  Widget build(BuildContext context) {
    final bodyStyle = _readerThemeService.buildRenderTextStyle(
      preferences: preferences,
      fallback:
          Theme.of(context).textTheme.bodyLarge ??
          const TextStyle(fontSize: 19, height: 1.7),
    );
    final horizontalPadding = _readerThemeService.horizontalPadding(
      preferences.pagePaddingLevel,
    );

    final isChapterStart = page.startOffset == 0;
    final text = isChapterStart && !preferences.firstLineIndent
        ? page.text
        : '  ${page.text}';

    final localHighlights = highlights
        .where(
          (item) =>
              item.startOffset < page.endOffset &&
              item.endOffset > page.startOffset,
        )
        .map(
          (item) => HighlightEntity(
            id: item.id,
            bookId: item.bookId,
            chapterId: item.chapterId,
            startOffset: (item.startOffset - page.startOffset).clamp(
              0,
              text.length,
            ),
            endOffset: (item.endOffset - page.startOffset).clamp(
              0,
              text.length,
            ),
            selectedText: item.selectedText,
            prefixContext: item.prefixContext,
            suffixContext: item.suffixContext,
            color: item.color,
            note: item.note,
            createdAt: item.createdAt,
            updatedAt: item.updatedAt,
          ),
        )
        .toList(growable: false);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          54,
          horizontalPadding,
          88,
        ),
        child: SelectableParagraph(
          key: ValueKey<String>(
            'selection-paragraph-${page.chapterId}-${page.startOffset}-$selectionEpoch',
          ),
          text: text,
          highlights: localHighlights,
          highlightActionLabel: highlightActionLabel,
          focusNode: selectionFocusNode,
          textStyle: bodyStyle,
          contentPadding: EdgeInsets.zero,
          onSelectionChanged: onSelectionChanged,
          onHighlightRequested: onHighlightRequested,
        ),
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
              style: TextStyle(
                fontSize: 16,
                color: selected
                    ? const Color(0xFF596171)
                    : const Color(0xFF596171),
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
