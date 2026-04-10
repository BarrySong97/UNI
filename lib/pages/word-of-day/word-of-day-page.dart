import 'package:flutter/material.dart';

import '../../app/providers/app-providers.dart';
import '../../entities/explain-history-entity.dart';
import '../../services/db/app-database.dart';
import '../../shared/constants/common-design-tokens.dart';

class WordsPage extends StatefulWidget {
  const WordsPage({this.database, super.key});

  final AppDatabase? database;

  @override
  State<WordsPage> createState() => _WordsPageState();
}

class _WordsPageState extends State<WordsPage> {
  Future<List<ExplainHistoryEntity>>? _historyFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _historyFuture ??= _database.listExplainHistory();
  }

  AppDatabase get _database =>
      widget.database ?? AppProvidersScope.of(context).database;

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

          final items = snapshot.data ?? const <ExplainHistoryEntity>[];
          if (items.isEmpty) {
            return const _WordsEmptyState();
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _WordsHistoryCard(
              item: items[index],
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => WordDetailPage(item: items[index]),
                ),
              ),
            ),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _WordDetailHero(item: item),
            const SizedBox(height: 16),
            _WordDetailSection(
              title: 'Meaning',
              child: Text(
                item.previewMeaning,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.55,
                  color: CommonDesignTokens.textPrimary,
                ),
              ),
            ),
            if (detailExplain.isNotEmpty) ...[
              const SizedBox(height: 16),
              _WordDetailSection(
                title: 'Details',
                child: Column(
                  children: detailExplain
                      .map(
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
                                    fontSize: 14,
                                    height: 1.5,
                                    color: CommonDesignTokens.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ],
            if (item.contextSentence.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              _WordDetailSection(
                title: 'Context',
                child: Text(
                  item.contextSentence,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.55,
                    color: CommonDesignTokens.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      item.selectedText,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: CommonDesignTokens.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: CommonDesignTokens.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                item.previewMeaning,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: CommonDesignTokens.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
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
}

class _WordDetailHero extends StatelessWidget {
  const _WordDetailHero({required this.item});

  final ExplainHistoryEntity item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CommonDesignTokens.cardBg,
        borderRadius: BorderRadius.circular(CommonDesignTokens.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            item.selectedText,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: CommonDesignTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  item.bookTitle,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: CommonDesignTokens.textSecondary,
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
    );
  }
}

class _WordDetailSection extends StatelessWidget {
  const _WordDetailSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CommonDesignTokens.cardBg,
        borderRadius: BorderRadius.circular(CommonDesignTokens.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: CommonDesignTokens.textSecondary,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

String _formatDate(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
