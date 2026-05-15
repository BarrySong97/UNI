import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni/dtos/db/book-dto.dart';
import 'package:uni/pages/word-of-day/word-of-day-page.dart';
import 'package:uni/services/db/app-database.dart';

void main() {
  testWidgets('renders explain history entries on words page', (tester) async {
    final database = AppDatabase();
    final nowMillis = DateTime(2026, 3, 1).millisecondsSinceEpoch;

    await database.upsertBook(
      BookDto(
        id: 'book-1',
        title: 'Deep Work',
        author: 'Author',
        sourceType: 'local_epub',
        createdAtMillis: nowMillis,
        updatedAtMillis: nowMillis,
      ),
    );
    await database.upsertExplainCache(
      bookId: 'book-1',
      chapterIndex: 0,
      selectedText: 'clarity',
      contextSentence: 'Clarity makes deep work possible.',
      response:
          '{"partOfSpeech":"noun","meaningExplain":"a state of being easy to understand","detailExplain":["It suggests clear thinking.","It fits focused work in this sentence."]}',
    );

    await tester.pumpWidget(MaterialApp(home: WordsPage(database: database)));
    await tester.pumpAndSettle();

    expect(find.text('Words'), findsOneWidget);
    expect(find.text('clarity'), findsOneWidget);
    expect(find.text('a state of being easy to understand'), findsOneWidget);
    expect(find.text('Deep Work'), findsOneWidget);
    expect(find.text('Details'), findsNothing);
  });

  testWidgets('opens detail page when tapping a word', (tester) async {
    final database = AppDatabase();
    final nowMillis = DateTime(2026, 3, 1).millisecondsSinceEpoch;

    await database.upsertBook(
      BookDto(
        id: 'book-1',
        title: 'Deep Work',
        author: 'Author',
        sourceType: 'local_epub',
        createdAtMillis: nowMillis,
        updatedAtMillis: nowMillis,
      ),
    );
    await database.upsertExplainCache(
      bookId: 'book-1',
      chapterIndex: 0,
      selectedText: 'clarity',
      contextSentence: 'Clarity makes deep work possible.',
      response:
          '{"partOfSpeech":"noun","meaningExplain":"a state of being easy to understand","detailExplain":["It suggests clear thinking.","It fits focused work in this sentence."]}',
    );

    await tester.pumpWidget(MaterialApp(home: WordsPage(database: database)));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('words-history-book-1-0-clarity')),
    );
    await tester.pumpAndSettle();

    expect(find.text('MEANING'), findsOneWidget);
    expect(find.text('DETAILS & USAGE'), findsOneWidget);
    expect(find.text('noun'), findsOneWidget);
    expect(find.text('It suggests clear thinking.'), findsOneWidget);
    expect(find.byType(RichText), findsWidgets);
  });

  testWidgets('renders empty state when no explain history exists', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: WordsPage(database: AppDatabase())),
    );
    await tester.pumpAndSettle();

    expect(find.text('No words yet'), findsOneWidget);
    expect(
      find.text('Select a word in Reader and tap Explain.'),
      findsOneWidget,
    );
  });
}
