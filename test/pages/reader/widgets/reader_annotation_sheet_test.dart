import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni/entities/annotation-entity.dart';
import 'package:uni/entities/annotation-note-entity.dart';
import 'package:uni/pages/reader/models/reader_annotation_card_item.dart';
import 'package:uni/pages/reader/widgets/reader_annotation_card.dart';
import 'package:uni/pages/reader/widgets/reader_annotation_sheet.dart';
import 'package:uni/shared/constants/shelf-design-tokens.dart';

void main() {
  ReaderAnnotationCardItem buildItem({
    required String annotationId,
    required String quoteText,
    required String noteText,
    required String color,
    required int chapterIndex,
    required String chapterTitle,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    return ReaderAnnotationCardItem(
      annotation: AnnotationEntity(
        id: annotationId,
        bookId: 'b1',
        kind: AnnotationKind.mark,
        style: AnnotationStyle.highlight,
        quoteText: quoteText,
        anchorJson: '{}',
        color: color,
        note: noteText,
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
      notes: <AnnotationNoteEntity>[
        AnnotationNoteEntity(
          id: 'note-$annotationId',
          annotationId: annotationId,
          bookId: 'b1',
          text: noteText,
          createdAt: updatedAt,
        ),
      ],
      chapterTitle: chapterTitle,
      chapterIndex: chapterIndex,
      latestNoteText: noteText,
      noteCount: 1,
      activityTime: updatedAt,
    );
  }

  testWidgets('shows cards, supports search, and opens detail view', (
    tester,
  ) async {
    final now = DateTime.now();
    final items = <ReaderAnnotationCardItem>[
      buildItem(
        annotationId: 'a1',
        quoteText: 'First quote',
        noteText: 'alpha note',
        color: '#FFE082',
        chapterIndex: 0,
        chapterTitle: 'Chapter 1',
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(hours: 4)),
      ),
      buildItem(
        annotationId: 'a2',
        quoteText: 'Second quote',
        noteText: 'beta thought',
        color: '#90CAF9',
        chapterIndex: 1,
        chapterTitle: 'Chapter 2',
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(hours: 1)),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderAnnotationSheet(
            items: items,
            onAddNote: (item, noteText) async => item,
          ),
        ),
      ),
    );

    expect(find.text('Marks'), findsOneWidget);
    expect(find.text('CHAPTER 1'), findsOneWidget);
    expect(find.text('CHAPTER 2'), findsOneWidget);

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
    expect(find.text('Go to mark'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('mark-detail-quote-card')),
      findsOneWidget,
    );
  });

  testWidgets('adds note inline and keeps detail open', (tester) async {
    final now = DateTime.now();
    final initial = buildItem(
      annotationId: 'a1',
      quoteText: 'Inline quote',
      noteText: 'first note',
      color: '#FFE082',
      chapterIndex: 0,
      chapterTitle: 'Chapter 1',
      createdAt: now.subtract(const Duration(days: 2)),
      updatedAt: now.subtract(const Duration(hours: 4)),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderAnnotationSheet(
            items: <ReaderAnnotationCardItem>[initial],
            onAddNote: (item, noteText) async {
              final createdAt = DateTime.now();
              return ReaderAnnotationCardItem(
                annotation: AnnotationEntity(
                  id: item.annotation.id,
                  bookId: item.annotation.bookId,
                  kind: item.annotation.kind,
                  style: item.annotation.style,
                  quoteText: item.annotation.quoteText,
                  anchorJson: item.annotation.anchorJson,
                  color: item.annotation.color,
                  note: noteText,
                  createdAt: item.annotation.createdAt,
                  updatedAt: createdAt,
                ),
                notes: <AnnotationNoteEntity>[
                  ...item.notes,
                  AnnotationNoteEntity(
                    id: 'note-2',
                    annotationId: item.annotation.id,
                    bookId: item.annotation.bookId,
                    text: noteText,
                    createdAt: createdAt,
                  ),
                ],
                chapterTitle: item.chapterTitle,
                chapterIndex: item.chapterIndex,
                latestNoteText: noteText,
                noteCount: item.noteCount + 1,
                activityTime: createdAt,
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Inline quote'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Note'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('mark-detail-note-input')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('mark-detail-note-input')),
      'second note',
    );
    await tester.pump();
    final publishButton = tester.widget<TextButton>(
      find.byKey(const ValueKey('note-composer-publish')),
    );
    publishButton.onPressed!.call();
    await tester.pumpAndSettle();

    expect(find.text('Mark Details'), findsOneWidget);
    expect(find.text('second note'), findsOneWidget);
    final offstage = tester.widget<Offstage>(
      find
          .ancestor(
            of: find.byKey(
              const ValueKey('mark-detail-note-input'),
              skipOffstage: false,
            ),
            matching: find.byType(Offstage, skipOffstage: false),
          )
          .first,
    );
    expect(offstage.offstage, isTrue);
  });

  testWidgets('go to mark dismisses with open location result', (tester) async {
    final now = DateTime.now();
    final item = buildItem(
      annotationId: 'a1',
      quoteText: 'Jump quote',
      noteText: 'note',
      color: '#FFE082',
      chapterIndex: 0,
      chapterTitle: 'Chapter 1',
      createdAt: now.subtract(const Duration(days: 2)),
      updatedAt: now.subtract(const Duration(hours: 4)),
    );

    ReaderAnnotationSheetResult? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await ReaderAnnotationSheet.show(
                    context: context,
                    items: <ReaderAnnotationCardItem>[item],
                    onAddNote: (item, noteText) async => item,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jump quote'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Go to mark'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.type, ReaderAnnotationSheetActionType.openLocation);
    expect(result!.annotation.id, 'a1');
  });

  testWidgets('annotation card uses words palette colors', (tester) async {
    final now = DateTime.now();
    final item = buildItem(
      annotationId: 'a1',
      quoteText: 'Palette quote',
      noteText: 'note',
      color: '#FFE082',
      chapterIndex: 0,
      chapterTitle: 'Chapter 1',
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderAnnotationCard(
            item: item,
            timestampText: '1 min ago',
            onTap: () {},
          ),
        ),
      ),
    );

    final ink = tester.widget<Ink>(find.byType(Ink));
    final decoration = ink.decoration! as BoxDecoration;
    expect(decoration.color, ShelfDesignTokens.wordOfDayCardBg);
    expect(
      decoration.border,
      Border.all(color: ShelfDesignTokens.wordOfDayIconBg),
    );
  });

  testWidgets('mark detail quote uses explain-style typography', (
    tester,
  ) async {
    final now = DateTime.now();
    final item = buildItem(
      annotationId: 'a1',
      quoteText: 'Styled quote',
      noteText: 'note',
      color: '#FFE082',
      chapterIndex: 0,
      chapterTitle: 'Chapter 1',
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderAnnotationSheet(
            items: <ReaderAnnotationCardItem>[item],
            onAddNote: (item, noteText) async => item,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Styled quote'));
    await tester.pumpAndSettle();

    final quoteContainer = tester.widget<Container>(
      find.byKey(const ValueKey('mark-detail-quote-card')),
    );
    final decoration = quoteContainer.decoration! as BoxDecoration;
    expect(decoration.color, Colors.white);

    final richText = tester.widget<RichText>(
      find.descendant(
        of: find.byKey(const ValueKey('mark-detail-quote-card')),
        matching: find.byType(RichText),
      ),
    );
    final text = richText.text as TextSpan;
    expect(text.style?.fontStyle, FontStyle.italic);
  });
}
