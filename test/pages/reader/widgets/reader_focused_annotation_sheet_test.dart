import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni/entities/annotation-entity.dart';
import 'package:uni/entities/annotation-note-entity.dart';
import 'package:uni/pages/reader/models/reader_annotation_card_item.dart';
import 'package:uni/pages/reader/widgets/reader_focused_annotation_sheet.dart';

void main() {
  ReaderAnnotationCardItem buildItem() {
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
        note: 'first note',
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now,
      ),
      notes: <AnnotationNoteEntity>[
        AnnotationNoteEntity(
          id: 'n1',
          annotationId: 'a1',
          bookId: 'b1',
          text: 'first note',
          createdAt: now,
        ),
      ],
      chapterTitle: 'Chapter 1',
      chapterIndex: 0,
      latestNoteText: 'first note',
      noteCount: 1,
      activityTime: now,
    );
  }

  testWidgets('renders notes and quote card styling', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderFocusedAnnotationSheet(
            item: buildItem(),
            onAddNote: (noteText) async => buildItem(),
            formatTimestamp: (_) => '1 min ago',
          ),
        ),
      ),
    );

    expect(find.text('Mark Notes'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('first note'), findsOneWidget);
    expect(find.text('Explain'), findsNothing);
    expect(find.text('Phonetics'), findsNothing);
    expect(find.text('Go to mark'), findsNothing);

    final quoteCard = tester.widget<Container>(
      find.byKey(const ValueKey('focused-mark-quote-card')),
    );
    final decoration = quoteCard.decoration! as BoxDecoration;
    expect(decoration.color, Colors.white);

    final richText = tester.widget<RichText>(
      find.descendant(
        of: find.byKey(const ValueKey('focused-mark-quote-card')),
        matching: find.byType(RichText),
      ),
    );
    final text = richText.text as TextSpan;
    expect(text.style?.fontStyle, FontStyle.italic);
    expect(find.byType(RichText), findsWidgets);
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
            formatTimestamp: (_) => '1 min ago',
          ),
        ),
      ),
    );

    await tester.tap(find.text('Add Note'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('focused-mark-note-input')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('focused-mark-note-input')),
      'second note',
    );
    await tester.pump();
    final publishButton = tester.widget<TextButton>(
      find.byKey(const ValueKey('note-composer-publish')),
    );
    publishButton.onPressed!.call();
    await tester.pumpAndSettle();

    expect(find.text('second note'), findsOneWidget);
    expect(find.text('Close Note'), findsNothing);
    expect(find.text('Add Note'), findsOneWidget);
  });
}
