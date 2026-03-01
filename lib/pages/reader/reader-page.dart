import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/providers/app-providers.dart';
import '../../app/routes/route-names.dart';
import '../../components/reader/chapter-header.dart';
import '../../components/reader/reader-toolbar.dart';
import '../../components/reader/selectable-paragraph.dart';
import '../../entities/chapter-entity.dart';
import '../../stores/highlight/highlight-store.dart';
import '../../stores/reader/reader-store.dart';
import '../../shared/ui/loading-view.dart';
import '../../shared/ui/app-scaffold.dart';
import '../../app/i18n/app-localizations.dart';

class ReaderPage extends StatefulWidget {
  const ReaderPage({required this.bookId, super.key});

  final String bookId;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  final ScrollController _scrollController = ScrollController();
  final FocusNode _selectionFocusNode = FocusNode(
    debugLabel: 'reader-selection-focus',
  );
  TextSelection? _lastSelection;
  int _selectionEpoch = 0;
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
      final chapter = _readerStore!.state.chapter;
      if (chapter != null) {
        await _highlightStore!.loadHighlights(
          widget.bookId,
          chapterId: chapter.id,
        );
      }
    });

    _scrollController.addListener(() {
      _readerStore?.updateOffset(_scrollController.offset.floor());
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _selectionFocusNode.dispose();
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
        final chapter = state.chapter;
        final localizations = AppLocalizations.of(context);
        if (state.isLoading || chapter == null) {
          return const AppScaffold(title: 'Reader', body: LoadingView());
        }

        return AppScaffold(
          title: state.book?.title ?? 'Reader',
          actions: <Widget>[
            ReaderToolbar(
              onOpenBookProfile: () {
                Navigator.of(
                  context,
                ).pushNamed(RouteNames.bookDetail, arguments: widget.bookId);
              },
              onOpenHighlights: () {
                Navigator.of(context).pushNamed(
                  RouteNames.highlights,
                  arguments: <String, String>{
                    'bookId': widget.bookId,
                    'chapterId': chapter.id,
                  },
                );
              },
              onOpenSettings: () {
                Navigator.of(context).pushNamed(RouteNames.readerSettings);
              },
            ),
          ],
          body: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _clearSelection,
            child: Column(
              children: <Widget>[
                ChapterHeader(title: chapter.title),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SelectableParagraph(
                          key: ValueKey<String>(
                            'selection-paragraph-$_selectionEpoch',
                          ),
                          text: chapter.content,
                          highlights: highlightStore.state.items,
                          highlightActionLabel: localizations.tr(
                            'highlightAction',
                          ),
                          focusNode: _selectionFocusNode,
                          onSelectionChanged: (selection) {
                            _lastSelection = selection.isCollapsed
                                ? null
                                : selection;
                          },
                          onHighlightRequested: (selection) {
                            _lastSelection = selection;
                            unawaited(
                              _createHighlightFromSelection(
                                chapter: chapter,
                                highlightStore: highlightStore,
                                selection: selection,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              final selection = _lastSelection;
              if (selection == null) {
                return;
              }
              unawaited(
                _createHighlightFromSelection(
                  chapter: chapter,
                  highlightStore: highlightStore,
                  selection: selection,
                ),
              );
            },
            child: const Icon(Icons.highlight),
          ),
        );
      },
    );
  }

  void _clearSelection() {
    setState(() {
      _lastSelection = null;
      _selectionEpoch++;
    });
    _selectionFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _createHighlightFromSelection({
    required ChapterEntity chapter,
    required HighlightStore highlightStore,
    required TextSelection selection,
  }) async {
    if (selection.isCollapsed) {
      return;
    }
    final start = selection.start < selection.end
        ? selection.start
        : selection.end;
    final end = selection.start < selection.end
        ? selection.end
        : selection.start;

    try {
      await highlightStore.createHighlight(
        bookId: widget.bookId,
        chapterId: chapter.id,
        chapterText: chapter.content,
        startOffset: start,
        endOffset: end,
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
}
