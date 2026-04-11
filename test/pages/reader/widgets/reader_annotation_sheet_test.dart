import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni/entities/annotation-entity.dart';
import 'package:uni/entities/annotation-note-entity.dart';
import 'package:uni/pages/reader/models/reader_annotation_card_item.dart';
import 'package:uni/pages/reader/widgets/reader_annotation_sheet.dart';

void main() {
  testWidgets('shows cards, supports search, and opens detail view', (
    tester,
  ) async {
    final now = DateTime.now();
    final items = <ReaderAnnotationCardItem>[
      ReaderAnnotationCardItem(
        annotation: AnnotationEntity(
          id: 'a1',
          bookId: 'b1',
          kind: AnnotationKind.mark,
          style: AnnotationStyle.highlight,
          quoteText: 'First quote',
          anchorJson: '{}',
          color: '#FFE082',
          note: 'alpha note',
          createdAt: now.subtract(const Duration(days: 2)),
          updatedAt: now.subtract(const Duration(hours: 4)),
        ),
        notes: <AnnotationNoteEntity>[
          AnnotationNoteEntity(
            id: 'n1',
            annotationId: 'a1',
            bookId: 'b1',
            text: 'alpha note',
            createdAt: now.subtract(const Duration(hours: 4)),
          ),
        ],
        chapterTitle: 'Chapter 1',
        chapterIndex: 0,
        latestNoteText: 'alpha note',
        noteCount: 1,
        activityTime: now.subtract(const Duration(hours: 4)),
      ),
      ReaderAnnotationCardItem(
        annotation: AnnotationEntity(
          id: 'a2',
          bookId: 'b1',
          kind: AnnotationKind.mark,
          style: AnnotationStyle.underline,
          quoteText: 'Second quote',
          anchorJson: '{}',
          color: '#90CAF9',
          note: 'beta thought',
          createdAt: now.subtract(const Duration(days: 1)),
          updatedAt: now.subtract(const Duration(hours: 1)),
        ),
        notes: <AnnotationNoteEntity>[
          AnnotationNoteEntity(
            id: 'n2',
            annotationId: 'a2',
            bookId: 'b1',
            text: 'beta thought',
            createdAt: now.subtract(const Duration(hours: 1)),
          ),
        ],
        chapterTitle: 'Chapter 2',
        chapterIndex: 1,
        latestNoteText: 'beta thought',
        noteCount: 1,
        activityTime: now.subtract(const Duration(hours: 1)),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ReaderAnnotationSheet(items: items)),
      ),
    );

    expect(find.text('Marks'), findsOneWidget);
    expect(find.text('CHAPTER 1'), findsOneWidget);
    expect(find.text('CHAPTER 2'), findsOneWidget);

    // Search is always visible — enter text directly
    await tester.enterText(
      find.byKey(const ValueKey('marks-search-input')),
      'beta',
    );
    await tester.pumpAndSettle();

    expect(find.text('CHAPTER 2'), findsOneWidget);
    expect(find.text('CHAPTER 1'), findsNothing);

    await tester.tap(find.text('Second quote'));
    await tester.pumpAndSettle();

    expect(find.text('Mark Details'), findsOneWidget);
    expect(find.text('Add Note'), findsOneWidget);
    expect(find.text('Go to location →'), findsOneWidget);
  });
}
