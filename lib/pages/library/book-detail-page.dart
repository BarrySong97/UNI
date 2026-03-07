import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/i18n/app-localizations.dart';
import '../../app/providers/app-providers.dart';
import '../../app/routes/route-names.dart';
import '../../entities/book-entity.dart';
import '../../shared/utils/cover-image-cache.dart';
import '../../entities/reading-progress-entity.dart';
import '../../services/library/book-profile-color-service.dart';
import '../../shared/constants/library-design-tokens.dart';
import '../../shared/ui/loading-view.dart';

class BookDetailPage extends StatefulWidget {
  const BookDetailPage({required this.bookId, super.key});

  final String bookId;

  @override
  State<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> {
  final BookProfileColorService _colorService = const BookProfileColorService();
  Future<_BookProfileData?>? _dataFuture;
  Future<LinearGradient>? _topGradientFuture;
  String? _topGradientKey;
  bool _isNavigating = false;
  bool _isDeleting = false;
  bool _isBackfillingProfileColor = false;

  static const String _mockCategory = 'Fiction';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _dataFuture ??= _loadData();
  }

  Future<_BookProfileData?> _loadData() async {
    final providers = AppProvidersScope.of(context);
    final book = await providers.bookRepository.getBookById(widget.bookId);
    if (book == null) {
      return null;
    }
    final progress = await providers.progressRepository.getProgress(
      widget.bookId,
    );
    final chapters = await providers.chapterRepository.getChapters(
      widget.bookId,
    );
    final totalWordCount = chapters.fold<int>(
      0,
      (sum, ch) => sum + ch.wordCount,
    );
    return _BookProfileData(
      book: book,
      progress: progress,
      totalWordCount: totalWordCount,
    );
  }

  Future<void> _continueReading() async {
    if (_isNavigating || !mounted) {
      return;
    }
    _isNavigating = true;
    try {
      await Navigator.of(
        context,
      ).pushNamed(RouteNames.reader, arguments: widget.bookId);
    } finally {
      _isNavigating = false;
    }
  }


  void _ensureTopGradientFuture({
    required String gradientKey,
    required BookEntity book,
    required Uint8List? coverBytes,
  }) {
    if (_topGradientFuture != null && _topGradientKey == gradientKey) {
      return;
    }
    _topGradientKey = gradientKey;
    _topGradientFuture = _resolveTopGradient(
      book: book,
      coverBytes: coverBytes,
    );
  }

  Future<LinearGradient> _resolveTopGradient({
    required BookEntity book,
    required Uint8List? coverBytes,
  }) async {
    if (book.profileBgColor != null) {
      return _colorService.gradientFromStoredHex(book.profileBgColor);
    }
    final gradient = await _colorService.resolveTopGradient(coverBytes);
    unawaited(_tryBackfillProfileBgColor(book: book, coverBytes: coverBytes));
    return gradient;
  }

  Future<void> _tryBackfillProfileBgColor({
    required BookEntity book,
    required Uint8List? coverBytes,
  }) async {
    if (_isBackfillingProfileColor || book.profileBgColor != null) {
      return;
    }
    _isBackfillingProfileColor = true;
    try {
      final profileBgColor = await _colorService.resolveProfileBgColorHex(
        coverBytes,
      );
      if (profileBgColor == null || !mounted) {
        return;
      }
      final providers = AppProvidersScope.of(context);
      await providers.bookRepository.upsertBook(
        BookEntity(
          id: book.id,
          title: book.title,
          author: book.author,
          sourceType: book.sourceType,
          createdAt: book.createdAt,
          updatedAt: DateTime.now(),
          coverUrl: book.coverUrl,
          profileBgColor: profileBgColor,
          sourcePath: book.sourcePath,
        ),
      );
    } catch (_) {
      // Keep UI responsive on non-critical backfill errors.
    } finally {
      _isBackfillingProfileColor = false;
    }
  }

  Future<void> _onSettingsAction(_BookProfileMenuAction action) async {
    switch (action) {
      case _BookProfileMenuAction.deleteBook:
        await _deleteBook();
        break;
    }
  }

  Future<void> _deleteBook() async {
    if (_isDeleting || !mounted) {
      return;
    }
    final localizations = AppLocalizations.of(context);
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(localizations.tr('deleteBookConfirmTitle')),
          content: Text(localizations.tr('deleteBookConfirmMessage')),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(localizations.tr('cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(localizations.tr('delete')),
            ),
          ],
        );
      },
    );
    if (shouldDelete != true || !mounted) {
      return;
    }
    setState(() {
      _isDeleting = true;
    });
    try {
      final providers = AppProvidersScope.of(context);
      await providers.libraryStore.deleteBookById(widget.bookId);
      if (!mounted) {
        return;
      }
      await Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(RouteNames.mainTabs, (route) => false);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.tr('deleteBookFailed'))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  Color _statusBarSourceColorForGradient(LinearGradient gradient) {
    if (gradient.colors.isEmpty) {
      return LibraryDesignTokens.bookProfileTopBgBase;
    }
    return gradient.colors.first.withValues(alpha: 1);
  }

  bool _shouldShowAuthor(String author) {
    final normalized = author.trim().toLowerCase();
    return normalized.isNotEmpty && normalized != 'unknown';
  }

  SystemUiOverlayStyle _statusBarOverlayStyle(Color sourceColor) {
    final darkIcons = sourceColor.computeLuminance() > 0.5;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: darkIcons ? Brightness.dark : Brightness.light,
      statusBarBrightness: darkIcons ? Brightness.light : Brightness.dark,
    );
  }

  String _formatWordCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }

  Widget _buildStatItem({required String label, required String value}) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: LibraryDesignTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: LibraryDesignTokens.bookProfileMutedText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow({
    required double progressPercent,
    required int wordCount,
    required String category,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: <Widget>[
          _buildStatItem(
            label: 'Progress',
            value: '${(progressPercent * 100).round()}%',
          ),
          Container(
            width: 1,
            height: 32,
            color: LibraryDesignTokens.borderColor,
          ),
          _buildStatItem(
            label: 'Words',
            value: _formatWordCount(wordCount),
          ),
          Container(
            width: 1,
            height: 32,
            color: LibraryDesignTokens.borderColor,
          ),
          _buildStatItem(
            label: 'Category',
            value: category,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final defaultGradient = _colorService.defaultTopGradient();

    return FutureBuilder<_BookProfileData?>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: LoadingView());
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Text(
                localizations.tr('bookNotFound'),
                style: const TextStyle(color: LibraryDesignTokens.textPrimary),
              ),
            ),
          );
        }

        final data = snapshot.data!;
        final progressPercent = data.progress?.percent ?? 0;
        final coverBytes = CoverImageCache.decode(data.book.coverUrl);
        _ensureTopGradientFuture(
          gradientKey:
              '${data.book.id}_${data.book.coverUrl}_${data.book.profileBgColor}',
          book: data.book,
          coverBytes: coverBytes,
        );

        return FutureBuilder<LinearGradient>(
          future: _topGradientFuture,
          initialData: defaultGradient,
          builder: (context, gradientSnapshot) {
            final gradient = gradientSnapshot.data ?? defaultGradient;
            final statusBarSourceColor = _statusBarSourceColorForGradient(
              gradient,
            );
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: _statusBarOverlayStyle(statusBarSourceColor),
              child: Scaffold(
                backgroundColor: LibraryDesignTokens.pageBackground,
                body: Stack(
                  children: <Widget>[
                    SingleChildScrollView(
                      child: Column(
                        children: <Widget>[
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(gradient: gradient),
                            child: SafeArea(
                              bottom: false,
                              child: Column(
                                children: <Widget>[
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: <Widget>[
                                        IconButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(),
                                          icon: const Icon(
                                            Icons.arrow_back,
                                            color:
                                                LibraryDesignTokens.textPrimary,
                                          ),
                                        ),
                                        PopupMenuButton<_BookProfileMenuAction>(
                                          enabled: !_isDeleting,
                                          tooltip: localizations.tr(
                                            'bookProfileSettings',
                                          ),
                                          onSelected: _onSettingsAction,
                                          itemBuilder: (context) =>
                                              <
                                                PopupMenuEntry<
                                                  _BookProfileMenuAction
                                                >
                                              >[
                                                PopupMenuItem<
                                                  _BookProfileMenuAction
                                                >(
                                                  value: _BookProfileMenuAction
                                                      .deleteBook,
                                                  child: Text(
                                                    localizations.tr(
                                                      'deleteBook',
                                                    ),
                                                  ),
                                                ),
                                              ],
                                          icon: const Icon(
                                            Icons.more_vert,
                                            color:
                                                LibraryDesignTokens.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Center(
                                    child: Container(
                                      width: 160,
                                      height: 235,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: <BoxShadow>[
                                          BoxShadow(
                                            color:
                                                Colors.black.withValues(alpha: 0.2),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: coverBytes != null
                                          ? Image.memory(
                                              coverBytes,
                                              fit: BoxFit.cover,
                                            )
                                          : Container(
                                              color:
                                                  LibraryDesignTokens.coverGray,
                                              alignment: Alignment.center,
                                              child: const Text(
                                                'COVER',
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 16,
                                                  letterSpacing: 1.2,
                                                ),
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                    ),
                                    child: Text(
                                      data.book.title,
                                      textAlign: TextAlign.center,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w600,
                                        color: LibraryDesignTokens.textPrimary,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                  if (_shouldShowAuthor(
                                    data.book.author,
                                  )) ...<Widget>[
                                    const SizedBox(height: 8),
                                    Text(
                                      data.book.author,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: LibraryDesignTokens
                                            .bookProfileMutedText,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 24),
                                ],
                              ),
                            ),
                          ),
                          Container(
                            color: LibraryDesignTokens.pageBackground,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              children: <Widget>[
                                _buildStatsRow(
                                  progressPercent: progressPercent,
                                  wordCount: data.totalWordCount,
                                  category: _mockCategory,
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed:
                                        _isDeleting ? null : _continueReading,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          LibraryDesignTokens.textPrimary,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      localizations.tr('continueReading'),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 32),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isDeleting)
                      const Positioned.fill(
                        child: ColoredBox(
                          color: Color(0x66000000),
                          child: Center(child: CircularProgressIndicator()),
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
  }
}

enum _BookProfileMenuAction { deleteBook }

class _BookProfileData {
  const _BookProfileData({
    required this.book,
    required this.progress,
    required this.totalWordCount,
  });

  final BookEntity book;
  final ReadingProgressEntity? progress;
  final int totalWordCount;
}
