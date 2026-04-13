import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni/pages/reader/widgets/reader_annotation_note_composer.dart';

void main() {
  testWidgets('publish stays disabled until note text is entered', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReaderAnnotationNoteComposer(quoteText: 'Selected quote'),
        ),
      ),
    );

    final publish = tester.widget<TextButton>(
      find.byKey(const ValueKey('note-composer-publish')),
    );
    expect(publish.onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('note-composer-input')),
      'New note',
    );
    await tester.pump();

    final enabled = tester.widget<TextButton>(
      find.byKey(const ValueKey('note-composer-publish')),
    );
    expect(enabled.onPressed, isNotNull);
    expect(find.textContaining('Quote: Selected quote'), findsOneWidget);
  });

  testWidgets('shared editor submits and disables while saving', (
    tester,
  ) async {
    var submittedText = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderAnnotationNoteEditor(
            quoteText: 'Inline quote',
            onSubmit: (value) async {
              submittedText = value;
            },
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('note-composer-input')),
      'Inline note',
    );
    await tester.pump();
    final publish = tester.widget<TextButton>(
      find.byKey(const ValueKey('note-composer-publish')),
    );
    publish.onPressed!.call();
    await tester.pump();

    expect(submittedText, 'Inline note');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderAnnotationNoteEditor(
            quoteText: 'Inline quote',
            isSubmitting: true,
            onSubmit: (value) async {
              submittedText = value;
            },
          ),
        ),
      ),
    );
    await tester.pump();

    final disabled = tester.widget<TextButton>(
      find.byKey(const ValueKey('note-composer-publish')),
    );
    expect(disabled.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
