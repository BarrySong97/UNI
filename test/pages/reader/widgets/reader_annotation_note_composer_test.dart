import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni/pages/reader/widgets/reader_annotation_note_composer.dart';

void main() {
  testWidgets('selection note sheet uses large text area and submit action', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReaderSelectionNoteSheet(quoteText: 'Selected quote'),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('selection-note-sheet')), findsOneWidget);
    expect(find.text('Add Note'), findsOneWidget);
    expect(find.text('Selected text'), findsOneWidget);
    expect(find.text('Selected quote'), findsOneWidget);

    final input = tester.widget<TextField>(
      find.byKey(const ValueKey('note-composer-input')),
    );
    expect(input.expands, isTrue);

    final publish = tester.widget<FilledButton>(
      find.byKey(const ValueKey('note-composer-publish')),
    );
    expect(publish.onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('note-composer-input')),
      'New note',
    );
    await tester.pump();

    final enabled = tester.widget<FilledButton>(
      find.byKey(const ValueKey('note-composer-publish')),
    );
    expect(enabled.onPressed, isNotNull);
  });

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

  testWidgets('selection note sheet opens as phone bottom sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  ReaderSelectionNoteSheet.show(
                    context: context,
                    quoteText: 'Phone quote',
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

    expect(find.byKey(const ValueKey('selection-note-sheet')), findsOneWidget);
    expect(find.text('Phone quote'), findsOneWidget);
  });

  testWidgets('selection note sheet opens on opposite side in tablet mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  ReaderSelectionNoteSheet.show(
                    context: context,
                    quoteText: 'Tablet quote',
                    isTablet: true,
                    selectionOnRightPage: true,
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

    final panelRect = tester.getRect(
      find.byKey(const ValueKey('selection-note-panel')),
    );
    expect(panelRect.left, lessThan(80));
    expect(find.text('Tablet quote'), findsOneWidget);
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
