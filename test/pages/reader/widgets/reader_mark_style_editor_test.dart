import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni/entities/annotation-entity.dart';
import 'package:uni/pages/reader/widgets/reader_mark_style_editor.dart';

void main() {
  testWidgets('renders selected state and invokes callbacks', (tester) async {
    String selectedColor = '#FFE082';
    AnnotationStyle selectedStyle = AnnotationStyle.highlight;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: StatefulBuilder(
            builder: (context, setState) {
              return ReaderMarkStyleEditor(
                selectedColor: selectedColor,
                selectedStyle: selectedStyle,
                onColorChanged: (value) {
                  setState(() => selectedColor = value);
                },
                onStyleChanged: (value) {
                  setState(() => selectedStyle = value);
                },
              );
            },
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('mark-style-highlight')), findsOneWidget);
    expect(find.byKey(const ValueKey('mark-style-underline')), findsOneWidget);
    expect(find.byKey(const ValueKey('mark-apply')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('mark-style-underline')));
    await tester.pumpAndSettle();
    expect(selectedStyle, AnnotationStyle.underline);

    await tester.tap(find.byKey(const ValueKey('mark-color-#90CAF9')));
    await tester.pumpAndSettle();
    expect(selectedColor, '#90CAF9');
  });
}
