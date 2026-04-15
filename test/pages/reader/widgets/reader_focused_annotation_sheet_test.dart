import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni/entities/annotation-entity.dart';
import 'package:uni/entities/annotation-note-entity.dart';
import 'package:uni/pages/reader/models/reader_annotation_card_item.dart';
import 'package:uni/pages/reader/widgets/reader_focused_annotation_sheet.dart';

void main() {
  ReaderAnnotationCardItem buildItem({
    List<String> noteTexts = const <String>['first note'],
  }) {
    final now = DateTime.now();
    return ReaderAnnotationCardItem(
      annotation: AnnotationEntity(
        id: 'a1',
        bookId: 'b1',
        kind: AnnotationKind.mark,
        style: AnnotationStyle.highlight,
        quoteText: 'Focused quote',
        anchorJson: '{}',
        color: '#FFE082',
        note: noteTexts.isEmpty ? null : noteTexts.last,
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now,
      ),
      notes: <AnnotationNoteEntity>[
        for (int i = 0; i < noteTexts.length; i++)
          AnnotationNoteEntity(
            id: 'n$i',
            annotationId: 'a1',
            bookId: 'b1',
            text: noteTexts[i],
            createdAt: now.add(Duration(minutes: i)),
          ),
      ],
      chapterTitle: 'Chapter 1',
      chapterIndex: 0,
      latestNoteText: noteTexts.isEmpty ? null : noteTexts.last,
      noteCount: noteTexts.length,
      activityTime: now,
    );
  }

  testWidgets('renders redesigned mark detail layout and actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderFocusedAnnotationSheet(
            item: buildItem(),
            onAddNote: (noteText) async =>
                buildItem(noteTexts: <String>['first note', noteText]),
            onShare: () async {},
            onDelete: () async => true,
            onGoToLocation: () {},
            formatTimestamp: (_) => '1 min ago',
          ),
        ),
      ),
    );

    expect(find.text('MARK DETAIL'), findsOneWidget);
    expect(find.text('Chapter 1'), findsOneWidget);
    expect(find.textContaining('Page'), findsNothing);
    expect(find.text('GO TO THE MARK'), findsOneWidget);
    expect(find.text('Add'), findsWidgets);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Go to mark'), findsNothing);
    expect(
      find.byKey(const ValueKey('mark-detail-editorial-quote')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('mark-detail-latest-note-card')),
      findsOneWidget,
    );
    expect(find.text('first note'), findsOneWidget);
  });

  testWidgets('adds note inline inside focused sheet', (tester) async {
    final updatedNow = DateTime.now();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderFocusedAnnotationSheet(
            item: buildItem(),
            onAddNote: (noteText) async {
              return ReaderAnnotationCardItem(
                annotation: AnnotationEntity(
                  id: 'a1',
                  bookId: 'b1',
                  kind: AnnotationKind.mark,
                  style: AnnotationStyle.highlight,
                  quoteText: 'Focused quote',
                  anchorJson: '{}',
                  color: '#FFE082',
                  note: noteText,
                  createdAt: updatedNow.subtract(const Duration(days: 1)),
                  updatedAt: updatedNow,
                ),
                notes: <AnnotationNoteEntity>[
                  AnnotationNoteEntity(
                    id: 'n1',
                    annotationId: 'a1',
                    bookId: 'b1',
                    text: 'first note',
                    createdAt: updatedNow.subtract(const Duration(minutes: 1)),
                  ),
                  AnnotationNoteEntity(
                    id: 'n2',
                    annotationId: 'a1',
                    bookId: 'b1',
                    text: noteText,
                    createdAt: updatedNow,
                  ),
                ],
                chapterTitle: 'Chapter 1',
                chapterIndex: 0,
                latestNoteText: noteText,
                noteCount: 2,
                activityTime: updatedNow,
              );
            },
            onShare: () async {},
            onDelete: () async => true,
            onGoToLocation: () {},
            formatTimestamp: (_) => '1 min ago',
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('mark-detail-action-add')));
    await tester.pumpAndSettle();

    final inputFinder = find.byKey(const ValueKey('focused-mark-note-input'));
    expect(inputFinder, findsOneWidget);

    await tester.enterText(inputFinder, 'second note');
    await tester.pump();
    final publishButton = tester.widget<TextButton>(
      find.byKey(const ValueKey('note-composer-publish')),
    );
    publishButton.onPressed!.call();
    await tester.pumpAndSettle();

    expect(find.text('second note'), findsOneWidget);
    expect(find.text('first note'), findsOneWidget);
    expect(find.byKey(const ValueKey('focused-mark-note-input')), findsNothing);
  });

  testWidgets('can cancel note composer inside focused sheet', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderFocusedAnnotationSheet(
            item: buildItem(),
            onAddNote: (noteText) async =>
                buildItem(noteTexts: <String>['first note', noteText]),
            onShare: () async {},
            onDelete: () async => true,
            onGoToLocation: () {},
            formatTimestamp: (_) => '1 min ago',
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('mark-detail-action-add')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('focused-mark-note-input')),
      findsOneWidget,
    );
    expect(find.text('Cancel'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('mark-detail-action-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('focused-mark-note-input')), findsNothing);
    expect(find.text('Cancel'), findsNothing);
  });

  testWidgets('share delete and go-to-mark callbacks are wired', (
    tester,
  ) async {
    var didShare = false;
    var didDelete = false;
    var didGoTo = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderFocusedAnnotationSheet(
            item: buildItem(),
            onAddNote: (noteText) async =>
                buildItem(noteTexts: <String>['first note', noteText]),
            onShare: () async {
              didShare = true;
            },
            onDelete: () async {
              didDelete = true;
              return true;
            },
            onGoToLocation: () {
              didGoTo = true;
            },
            formatTimestamp: (_) => '1 min ago',
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('mark-detail-action-share')));
    await tester.pumpAndSettle();
    expect(didShare, isTrue);

    await tester.tap(find.byKey(const ValueKey('mark-detail-go-to-mark')));
    await tester.pumpAndSettle();
    expect(didGoTo, isTrue);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderFocusedAnnotationSheet(
            item: buildItem(),
            onAddNote: (noteText) async =>
                buildItem(noteTexts: <String>['first note', noteText]),
            onShare: () async {},
            onDelete: () async {
              didDelete = true;
              return true;
            },
            onGoToLocation: () {},
            formatTimestamp: (_) => '1 min ago',
          ),
        ),
      ),
    );

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

    expect(didDelete, isTrue);
  });
}
