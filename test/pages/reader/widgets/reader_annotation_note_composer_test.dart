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
}
