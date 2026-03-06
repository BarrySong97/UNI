import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/i18n/app-localizations.dart';
import '../../app/providers/app-providers.dart';
import '../../app/routes/route-names.dart';
import '../../entities/book-entity.dart';
import '../../entities/highlight-entity.dart';
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
    final highlights = await providers.highlightRepository.getHighlights(
      widget.bookId,
    );
    final progress = await providers.progressRepository.getProgress(
      widget.bookId,
    );
    return _BookProfileData(
      book: book,
      progress: progress,
      highlights: highlights,
    );
  }

  Future<void> _openHighlights() async {
    if (_isNavigating || !mounted) {
      return;
    }
    _isNavigating = true;
    try {
      await Navigator.of(context).pushNamed(
        RouteNames.highlights,
        arguments: <String, String>{
          'bookId': widget.bookId,
        },
      );
    } finally {
      _isNavigating = false;
    }
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
        final displayPage = data.progress == null
            ? 1
            : ((data.progress!.percent * 100).round().clamp(1, 100));
        final coverBytes = _decodeCoverDataUrl(data.book.coverUrl);
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
            final statusBarTopInset = MediaQuery.paddingOf(context).top;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: _statusBarOverlayStyle(statusBarSourceColor),
              child: Scaffold(
                backgroundColor: LibraryDesignTokens.pageBackground,
                body: Stack(
                  children: <Widget>[
                    SafeArea(
                      top: false,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Container(
                              decoration: BoxDecoration(gradient: gradient),
                              padding: EdgeInsets.fromLTRB(
                                14,
                                statusBarTopInset + 18,
                                14,
                                22,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: Text(
                                          data.book.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: LibraryDesignTokens
                                                .bookProfileTopTitleSize,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1.2,
                                            color:
                                                LibraryDesignTokens.textPrimary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
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
                                          Icons.settings_outlined,
                                          color:
                                              LibraryDesignTokens.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      SizedBox(
                                        width: 128,
                                        height: 188,
                                        child: coverBytes != null
                                            ? Image.memory(
                                                coverBytes,
                                                fit: BoxFit.cover,
                                              )
                                            : Container(
                                                color: LibraryDesignTokens
                                                    .coverGray,
                                                alignment: Alignment.center,
                                                child: const Text(
                                                  'COVER',
                                                  style: TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 14,
                                                    letterSpacing: 1.2,
                                                  ),
                                                ),
                                              ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              data.book.title.toUpperCase(),
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: LibraryDesignTokens
                                                    .bookProfileBookTitleSize,
                                                fontWeight: FontWeight.w500,
                                                color: LibraryDesignTokens
                                                    .textPrimary,
                                                height: 1.2,
                                              ),
                                            ),
                                            if (_shouldShowAuthor(
                                              data.book.author,
                                            )) ...<Widget>[
                                              const SizedBox(height: 8),
                                              Text(
                                                data.book.author,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: LibraryDesignTokens
                                                      .bookProfileMetaSize,
                                                  fontWeight: FontWeight.w400,
                                                  color: LibraryDesignTokens
                                                      .bookProfileMutedText,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: <Widget>[
                                      Text(
                                        localizations
                                            .tr('pageLabel')
                                            .replaceAll(
                                              '{page}',
                                              '$displayPage',
                                            ),
                                        style: const TextStyle(
                                          fontSize: LibraryDesignTokens
                                              .bookProfileMetaSize,
                                          color: LibraryDesignTokens
                                              .bookProfileMutedText,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        '${(progressPercent * 100).round()}%',
                                        style: const TextStyle(
                                          fontSize: LibraryDesignTokens
                                              .bookProfileMetaSize,
                                          color: LibraryDesignTokens
                                              .bookProfileMutedText,
                                        ),
                                      ),
                                      const Spacer(),
                                      ElevatedButton.icon(
                                        onPressed: _isDeleting
                                            ? null
                                            : _continueReading,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              LibraryDesignTokens.textPrimary,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 10,
                                          ),
                                          textStyle: const TextStyle(
                                            fontSize: LibraryDesignTokens
                                                .bookProfileActionSize,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          shape: const StadiumBorder(),
                                        ),
                                        icon: const Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 16,
                                        ),
                                        label: Text(
                                          localizations.tr('continueReading'),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      value: progressPercent
                                          .clamp(0, 1)
                                          .toDouble(),
                                      minHeight: 2,
                                      backgroundColor:
                                          LibraryDesignTokens.borderColor,
                                      color: LibraryDesignTokens.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(
                              height: 1,
                              thickness: 1,
                              color: LibraryDesignTokens.borderColor,
                            ),
                            Container(
                              color:
                                  LibraryDesignTokens.bookProfileCollectionBg,
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                22,
                                14,
                                32,
                              ),
                              child: Column(
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Text(
                                        localizations.tr('myHighlights'),
                                        style: const TextStyle(
                                          fontSize: LibraryDesignTokens
                                              .bookProfileSectionLabelSize,
                                          fontWeight: FontWeight.w600,
                                          color:
                                              LibraryDesignTokens.textSecondary,
                                          letterSpacing: 1.8,
                                        ),
                                      ),
                                      const Spacer(),
                                      OutlinedButton.icon(
                                        onPressed: _isDeleting
                                            ? null
                                            : () => _openHighlights(),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              LibraryDesignTokens.textPrimary,
                                          side: const BorderSide(
                                            color:
                                                LibraryDesignTokens.borderColor,
                                          ),
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          textStyle: const TextStyle(
                                            fontSize: LibraryDesignTokens
                                                .bookProfileActionSize,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          shape: const StadiumBorder(),
                                        ),
                                        icon: const Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 16,
                                        ),
                                        label: Text(
                                          localizations.tr('viewAll'),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  if (data.highlights.isEmpty)
                                    Text(
                                      localizations.tr('noHighlightsYet'),
                                      style: const TextStyle(
                                        fontSize: LibraryDesignTokens
                                            .bookProfileCollectionAuthorSize,
                                        color: LibraryDesignTokens
                                            .bookProfileMutedText,
                                      ),
                                    ),
                                  for (
                                    var i = 0;
                                    i < data.highlights.length;
                                    i++
                                  ) ...<Widget>[
                                    InkWell(
                                      onTap: _isDeleting
                                          ? null
                                          : () => _openHighlights(),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: <Widget>[
                                                  Text(
                                                    data
                                                            .highlights[i]
                                                            .selectedText
                                                            .trim()
                                                            .isEmpty
                                                        ? localizations.tr(
                                                            'emptyHighlight',
                                                          )
                                                        : data
                                                              .highlights[i]
                                                              .selectedText,
                                                    style: const TextStyle(
                                                      fontSize: LibraryDesignTokens
                                                          .bookProfileCollectionTitleSize,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: LibraryDesignTokens
                                                          .textPrimary,
                                                      height: 1.2,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    data.highlights[i].color,
                                                    style: const TextStyle(
                                                      fontSize: LibraryDesignTokens
                                                          .bookProfileCollectionAuthorSize,
                                                      color: LibraryDesignTokens
                                                          .bookProfileMutedText,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            const Padding(
                                              padding: EdgeInsets.only(top: 8),
                                              child: Text(
                                                '->',
                                                style: TextStyle(
                                                  fontSize: 24,
                                                  color: LibraryDesignTokens
                                                      .textPrimary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (i != data.highlights.length - 1)
                                      const Divider(
                                        height: 20,
                                        thickness: 1,
                                        color: LibraryDesignTokens.borderColor,
                                      ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
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
    required this.highlights,
  });

  final BookEntity book;
  final ReadingProgressEntity? progress;
  final List<HighlightEntity> highlights;
}
