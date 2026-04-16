import 'package:flutter/material.dart';

import '../../app/providers/app-providers.dart';
import '../../entities/explain-history-entity.dart';
import 'widgets/word_pronunciation_row.dart';
import '../../services/db/app-database.dart';
import '../../shared/constants/common-design-tokens.dart';
import '../../shared/constants/shelf-design-tokens.dart';
import '../../shared/utils/pronunciation_selection_text_utils.dart';
import '../../shared/widgets/english_pronunciation_selection_area.dart';

class WordsPage extends StatefulWidget {
  const WordsPage({this.database, super.key});

  final AppDatabase? database;

  @override
  State<WordsPage> createState() => _WordsPageState();
}

class _WordsPageState extends State<WordsPage> {
  Future<List<ExplainHistoryEntity>>? _historyFuture;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _historyFuture ??= _database.listExplainHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  AppDatabase get _database =>
      widget.database ?? AppProvidersScope.of(context).database;

  List<ExplainHistoryEntity> _filterItems(List<ExplainHistoryEntity> items) {
    if (_searchQuery.isEmpty) return items;
    final query = _searchQuery.toLowerCase();
    return items
        .where((item) => item.selectedText.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CommonDesignTokens.pageBackground,
      appBar: AppBar(
        title: const Text('Words'),
        backgroundColor: CommonDesignTokens.pageBackground,
        foregroundColor: CommonDesignTokens.textPrimary,
        elevation: 0,
      ),
      body: FutureBuilder<List<ExplainHistoryEntity>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final allItems = snapshot.data ?? const <ExplainHistoryEntity>[];
          if (allItems.isEmpty) {
            return const _WordsEmptyState();
          }

          final filteredItems = _filterItems(allItems);

          return Column(
            children: <Widget>[
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  style: const TextStyle(
                    fontSize: 15,
                    color: CommonDesignTokens.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search words...',
                    hintStyle: const TextStyle(
                      fontSize: 15,
                      color: CommonDesignTokens.textSecondary,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 20,
                      color: CommonDesignTokens.textSecondary,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? GestureDetector(
                            onTap: () => setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            }),
                            child: const Icon(
                              Icons.close,
                              size: 18,
                              color: CommonDesignTokens.textSecondary,
                            ),
                          )
                        : null,
                    filled: true,
                    fillColor: CommonDesignTokens.cardBg,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              // List
              Expanded(
                child: filteredItems.isEmpty
                    ? Center(
                        child: Text(
                          'No results for "$_searchQuery"',
                          style: const TextStyle(
                            fontSize: 15,
                            color: CommonDesignTokens.textSecondary,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: filteredItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) => _WordsHistoryCard(
                          item: filteredItems[index],
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  WordDetailPage(item: filteredItems[index]),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class WordDetailPage extends StatelessWidget {
  const WordDetailPage({required this.item, super.key});

  final ExplainHistoryEntity item;

  @override
  Widget build(BuildContext context) {
    final structured = item.structuredData;
    final detailExplain = structured?.detailExplain ?? const <String>[];
    final partOfSpeech = isPronunciationSingleWordSelection(item.selectedText)
        ? structured?.partOfSpeech.trim() ?? ''
        : '';
    final contextSentence = item.contextSentence.trim();
    final providers = AppProvidersScope.maybeOf(context);
    final longFormContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (contextSentence.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: CommonDesignTokens.pageBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text.rich(
              TextSpan(
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.55,
                  fontStyle: FontStyle.italic,
                  color: CommonDesignTokens.textSecondary,
                ),
                children: _buildContextSpans(
                  contextSentence,
                  item.selectedText.trim(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
        Text(
          'MEANING',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: ShelfDesignTokens.statsLabelColor,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          item.previewMeaning,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            height: 1.55,
            color: CommonDesignTokens.textPrimary,
          ),
        ),
        if (detailExplain.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'DETAILS & USAGE',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: ShelfDesignTokens.statsLabelColor,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 12),
          ...detailExplain.map(
            (detail) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.only(top: 7),
                    child: Icon(
                      Icons.circle,
                      size: 6,
                      color: CommonDesignTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      detail,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: CommonDesignTokens.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );

    return Scaffold(
      backgroundColor: CommonDesignTokens.pageBackground,
      appBar: AppBar(
        title: Text(item.selectedText),
        backgroundColor: CommonDesignTokens.pageBackground,
        foregroundColor: CommonDesignTokens.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: CommonDesignTokens.cardBg,
            borderRadius: BorderRadius.circular(CommonDesignTokens.cardRadius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Book source + date
              Row(
                children: <Widget>[
                  Icon(
                    Icons.book_outlined,
                    size: 13,
                    color: CommonDesignTokens.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.bookTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: CommonDesignTokens.textSecondary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _formatDate(item.createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: CommonDesignTokens.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Word title
              Text(
                item.selectedText,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: CommonDesignTokens.textPrimary,
                ),
              ),
              if (partOfSpeech.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: CommonDesignTokens.pageBackground,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    partOfSpeech,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: CommonDesignTokens.textSecondary,
                    ),
                  ),
                ),
              ],
              if (providers != null)
                WordPronunciationRow(
                  selectedText: item.selectedText,
                  phoneticsService: providers.phoneticsService,
                  ttsService: providers.ttsService,
                  padding: const EdgeInsets.only(top: 12, bottom: 14),
                ),
              if (providers != null)
                EnglishPronunciationSelectionArea(
                  phoneticsService: providers.phoneticsService,
                  ttsService: providers.ttsService,
                  child: longFormContent,
                )
              else
                longFormContent,
            ],
          ),
        ),
      ),
    );
  }

  List<InlineSpan> _buildContextSpans(String text, String selected) {
    if (selected.isEmpty) {
      return <InlineSpan>[TextSpan(text: text)];
    }
    final lowerText = text.toLowerCase();
    final lowerSelected = selected.toLowerCase();
    final matchIndex = lowerText.indexOf(lowerSelected);
    if (matchIndex < 0) {
      return <InlineSpan>[TextSpan(text: text)];
    }
    final endIndex = matchIndex + selected.length;
    return <InlineSpan>[
      if (matchIndex > 0) TextSpan(text: text.substring(0, matchIndex)),
      TextSpan(
        text: text.substring(matchIndex, endIndex),
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontStyle: FontStyle.normal,
          color: CommonDesignTokens.textPrimary,
        ),
      ),
      if (endIndex < text.length) TextSpan(text: text.substring(endIndex)),
    ];
  }
}

class _WordsEmptyState extends StatelessWidget {
  const _WordsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const <Widget>[
            Icon(
              Icons.auto_awesome_outlined,
              size: 40,
              color: CommonDesignTokens.textSecondary,
            ),
            SizedBox(height: 12),
            Text(
              'No words yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: CommonDesignTokens.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Select a word in Reader and tap Explain.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: CommonDesignTokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WordsHistoryCard extends StatelessWidget {
  const _WordsHistoryCard({required this.item, required this.onTap});

  final ExplainHistoryEntity item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final contextSentence = item.contextSentence.trim();
    final hasContext = contextSentence.isNotEmpty;

    return Material(
      color: CommonDesignTokens.cardBg,
      borderRadius: BorderRadius.circular(CommonDesignTokens.cardRadius),
      child: InkWell(
        key: ValueKey<String>(
          'words-history-${item.bookId}-${item.chapterIndex}-${item.selectedText}',
        ),
        borderRadius: BorderRadius.circular(CommonDesignTokens.cardRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Word title with icon
              Row(
                children: <Widget>[
                  Icon(
                    Icons.auto_awesome,
                    size: 18,
                    color: ShelfDesignTokens.wordOfDayIconColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.selectedText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: CommonDesignTokens.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              // Context sentence with highlighted word
              if (hasContext) ...[
                const SizedBox(height: 10),
                RichText(
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: CommonDesignTokens.textPrimary,
                    ),
                    children: _buildContextSpans(
                      contextSentence,
                      item.selectedText.trim(),
                    ),
                  ),
                ),
              ],
              // Meaning
              const SizedBox(height: 8),
              Text(
                item.previewMeaning,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: CommonDesignTokens.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              // Book source + date
              Row(
                children: <Widget>[
                  Icon(
                    Icons.book_outlined,
                    size: 13,
                    color: CommonDesignTokens.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.bookTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: CommonDesignTokens.textSecondary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _formatDate(item.createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: CommonDesignTokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<InlineSpan> _buildContextSpans(String text, String selected) {
    if (selected.isEmpty) {
      return <InlineSpan>[TextSpan(text: text)];
    }
    final lowerText = text.toLowerCase();
    final lowerSelected = selected.toLowerCase();
    final matchIndex = lowerText.indexOf(lowerSelected);
    if (matchIndex < 0) {
      return <InlineSpan>[TextSpan(text: text)];
    }
    final endIndex = matchIndex + selected.length;
    return <InlineSpan>[
      if (matchIndex > 0) TextSpan(text: text.substring(0, matchIndex)),
      TextSpan(
        text: text.substring(matchIndex, endIndex),
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: ShelfDesignTokens.wordOfDayIconColor,
        ),
      ),
      if (endIndex < text.length) TextSpan(text: text.substring(endIndex)),
    ];
  }
}

String _formatDate(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
