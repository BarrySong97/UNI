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
    required List<String> noteTexts,
    required String color,
    required int chapterIndex,
    required String chapterTitle,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    final notes = <AnnotationNoteEntity>[
      for (int i = 0; i < noteTexts.length; i++)
        AnnotationNoteEntity(
          id: 'note-$annotationId-$i',
          annotationId: annotationId,
          bookId: 'b1',
          text: noteTexts[i],
          createdAt: updatedAt.add(Duration(minutes: i)),
        ),
    ];
    return ReaderAnnotationCardItem(
      annotation: AnnotationEntity(
        id: annotationId,
        bookId: 'b1',
        kind: AnnotationKind.mark,
        style: AnnotationStyle.highlight,
        quoteText: quoteText,
        anchorJson: '{}',
        color: color,
        note: noteTexts.isEmpty ? null : noteTexts.last,
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
      notes: notes,
      chapterTitle: chapterTitle,
      chapterIndex: chapterIndex,
      latestNoteText: noteTexts.isEmpty ? null : noteTexts.last,
      noteCount: noteTexts.length,
      activityTime: updatedAt,
    );
  }

  testWidgets(
    'shows cards, supports list search, and opens redesigned detail',
    (tester) async {
      final now = DateTime.now();
      final items = <ReaderAnnotationCardItem>[
        buildItem(
          annotationId: 'a1',
          quoteText: 'First quote',
          noteTexts: <String>['alpha note'],
          color: '#FFE082',
          chapterIndex: 0,
          chapterTitle: 'Chapter 1',
          createdAt: now.subtract(const Duration(days: 2)),
          updatedAt: now.subtract(const Duration(hours: 4)),
        ),
        buildItem(
          annotationId: 'a2',
          quoteText: 'Second quote',
          noteTexts: <String>['beta thought'],
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
              onShare: (_) async {},
              onDelete: (_) async => true,
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

      expect(find.text('MARK DETAIL'), findsOneWidget);
      expect(find.text('Chapter 2'), findsOneWidget);
      expect(find.textContaining('Page'), findsNothing);
      expect(find.text('GO TO THE MARK'), findsOneWidget);
      expect(find.text('Add'), findsWidgets);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
      expect(find.byKey(const ValueKey('marks-search-input')), findsNothing);
      expect(
        find.byKey(const ValueKey('mark-detail-editorial-quote')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('mark-detail-latest-note-card')),
        findsOneWidget,
      );
      expect(find.text('beta thought'), findsOneWidget);
      expect(find.text('Go to mark'), findsNothing);
    },
  );

  testWidgets(
    'adds note inline and keeps detail open with latest thought card',
    (tester) async {
      final now = DateTime.now();
      final initial = buildItem(
        annotationId: 'a1',
        quoteText: 'Inline quote',
        noteTexts: <String>['first note'],
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
              onShare: (_) async {},
              onDelete: (_) async => true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Inline quote'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('mark-detail-note-input')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey('mark-detail-action-add')));
      await tester.pumpAndSettle();

      final inputFinder = find.byKey(const ValueKey('mark-detail-note-input'));
      expect(inputFinder, findsOneWidget);

      final visibleInput = tester.widget<TextField>(inputFinder);
      expect(visibleInput.focusNode?.hasFocus, isTrue);

      await tester.enterText(inputFinder, 'second note');
      await tester.pump();
      final publishButton = tester.widget<TextButton>(
        find.byKey(const ValueKey('note-composer-publish')),
      );
      publishButton.onPressed!.call();
      await tester.pumpAndSettle();

      expect(find.text('MARK DETAIL'), findsOneWidget);
      expect(find.text('second note'), findsOneWidget);
      expect(find.text('first note'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('mark-detail-note-input')),
        findsNothing,
      );
    },
  );

  testWidgets('can cancel note composer from mark detail', (tester) async {
    final now = DateTime.now();
    final initial = buildItem(
      annotationId: 'a1',
      quoteText: 'Cancelable quote',
      noteTexts: <String>['first note'],
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
            items: <ReaderAnnotationCardItem>[initial],
            onAddNote: (item, noteText) async => item,
            onShare: (_) async {},
            onDelete: (_) async => true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Cancelable quote'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('mark-detail-action-add')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('mark-detail-note-input')),
      findsOneWidget,
    );
    expect(find.text('Cancel'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('mark-detail-action-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mark-detail-note-input')), findsNothing);
    expect(find.text('Cancel'), findsNothing);
  });

  testWidgets('composing hides the first rendered thought item', (
    tester,
  ) async {
    final now = DateTime.now();
    final initial = buildItem(
      annotationId: 'a1',
      quoteText: 'Stacked quote',
      noteTexts: <String>['oldest note', 'latest note'],
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
            items: <ReaderAnnotationCardItem>[initial],
            onAddNote: (item, noteText) async => item,
            onShare: (_) async {},
            onDelete: (_) async => true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Stacked quote'));
    await tester.pumpAndSettle();
    expect(find.text('oldest note'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mark-detail-action-add')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('mark-detail-note-input')),
      findsOneWidget,
    );
    expect(find.text('oldest note'), findsNothing);
    expect(find.text('latest note'), findsNothing);
  });

  testWidgets('go to the mark dismisses with open location result', (
    tester,
  ) async {
    final now = DateTime.now();
    final item = buildItem(
      annotationId: 'a1',
      quoteText: 'Jump quote',
      noteTexts: <String>['note'],
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
                    onShare: (_) async {},
                    onDelete: (_) async => true,
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
    await tester.tap(find.byKey(const ValueKey('mark-detail-go-to-mark')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.type, ReaderAnnotationSheetActionType.openLocation);
    expect(result!.annotation.id, 'a1');
  });

  testWidgets(
    'share and delete actions invoke callbacks and delete returns to list',
    (tester) async {
      final now = DateTime.now();
      final items = <ReaderAnnotationCardItem>[
        buildItem(
          annotationId: 'a1',
          quoteText: 'Delete quote',
          noteTexts: <String>['note one'],
          color: '#FFE082',
          chapterIndex: 0,
          chapterTitle: 'Chapter 1',
          createdAt: now,
          updatedAt: now,
        ),
        buildItem(
          annotationId: 'a2',
          quoteText: 'Keep quote',
          noteTexts: <String>['note two'],
          color: '#90CAF9',
          chapterIndex: 0,
          chapterTitle: 'Chapter 1',
          createdAt: now,
          updatedAt: now,
        ),
      ];
      var sharedId = '';
      var deletedId = '';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderAnnotationSheet(
              items: items,
              onAddNote: (item, noteText) async => item,
              onShare: (item) async {
                sharedId = item.annotation.id;
              },
              onDelete: (item) async {
                deletedId = item.annotation.id;
                return true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Delete quote'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('mark-detail-action-share')));
      await tester.pumpAndSettle();
      expect(sharedId, 'a1');

      await tester.tap(find.byKey(const ValueKey('mark-detail-action-delete')));
      await tester.pumpAndSettle();
      expect(find.text('Delete mark?'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, 'Delete'),
        ),
      );
      await tester.pumpAndSettle();

      expect(deletedId, 'a1');
      expect(find.text('Marks'), findsOneWidget);
      expect(find.text('Keep quote'), findsOneWidget);
      expect(find.text('Delete quote'), findsNothing);
    },
  );

  testWidgets('annotation card uses words palette colors', (tester) async {
    final now = DateTime.now();
    final item = buildItem(
      annotationId: 'a1',
      quoteText: 'Palette quote',
      noteTexts: <String>['note'],
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
}
