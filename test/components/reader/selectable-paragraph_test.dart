import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni/components/reader/selectable-paragraph.dart';
import 'package:uni/entities/highlight-entity.dart';

void main() {
  testWidgets('SelectableParagraph uses custom contextMenuBuilder', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SelectableParagraph(
            text: 'Hello world',
            highlights: const <HighlightEntity>[],
            highlightActionLabel: 'Highlight',
            focusNode: FocusNode(),
            onSelectionChanged: (_) {},
            onHighlightRequested: (_) {},
          ),
        ),
      ),
    );

    final selectable = tester.widget<SelectableText>(find.byType(SelectableText));
    expect(selectable.contextMenuBuilder, isNotNull);
  });

  testWidgets('SelectableParagraph reports selection changes including collapsed', (tester) async {
    TextSelection? captured;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SelectableParagraph(
            text: 'Hello world',
            highlights: const <HighlightEntity>[],
            highlightActionLabel: 'Highlight',
            focusNode: FocusNode(),
            onSelectionChanged: (selection) {
              captured = selection;
            },
            onHighlightRequested: (_) {},
          ),
        ),
      ),
    );

    final selectable = tester.widget<SelectableText>(find.byType(SelectableText));
    selectable.onSelectionChanged!(const TextSelection(baseOffset: 0, extentOffset: 5), null);
    selectable.onSelectionChanged!(const TextSelection.collapsed(offset: 2), null);

    expect(captured, const TextSelection.collapsed(offset: 2));
  });

  testWidgets('context menu includes highlight action item', (tester) async {
    var highlightCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SelectableParagraph(
            text: 'Hello world',
            highlights: const <HighlightEntity>[],
            highlightActionLabel: 'Highlight',
            focusNode: FocusNode(),
            onSelectionChanged: (_) {},
            onHighlightRequested: (_) {
              highlightCalled = true;
            },
          ),
        ),
      ),
    );

    final selectable = tester.widget<SelectableText>(find.byType(SelectableText));
    selectable.onSelectionChanged!(const TextSelection(baseOffset: 0, extentOffset: 5), null);

    final editableState = tester.state<EditableTextState>(find.byType(EditableText));
    editableState.userUpdateTextEditingValue(
      const TextEditingValue(
        text: 'Hello world',
        selection: TextSelection(baseOffset: 0, extentOffset: 5),
      ),
      SelectionChangedCause.tap,
    );

    final menu = selectable.contextMenuBuilder!(
      tester.element(find.byType(SelectableText)),
      editableState,
    );

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: menu)));
    await tester.tap(find.text('Highlight'));
    await tester.pump();

    expect(highlightCalled, isTrue);
  });
}
