import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni/pages/reader/models/reader_tooltip_action_spec.dart';
import 'package:uni/pages/reader/widgets/reader_tooltip_actions_bar.dart';

void main() {
  testWidgets('focused single mark hides quote card action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderTooltipActionsBar(
            actionSpec: ReaderTooltipActionSpec.forFocused(annotationCount: 1),
            onPhoneticsPressed: () {},
            onExplainPressed: () {},
            onNotePressed: () {},
            onUnmarkPressed: () {},
            onReadAloudPressed: () {},
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('reader-tooltip-phonetics')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('reader-tooltip-explain')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('reader-tooltip-primary')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('reader-tooltip-note')), findsOneWidget);
    expect(find.byKey(const ValueKey('reader-tooltip-unmark')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('reader-tooltip-quote-card')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('reader-tooltip-read-aloud')),
      findsOneWidget,
    );
  });

  testWidgets('focused multi mark shows unmark only', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderTooltipActionsBar(
            actionSpec: ReaderTooltipActionSpec.forFocused(annotationCount: 2),
            onPrimaryPressed: () {},
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('reader-tooltip-primary')),
      findsOneWidget,
    );
    expect(find.text('Unmark'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('reader-tooltip-phonetics')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('reader-tooltip-explain')), findsNothing);
    expect(find.byKey(const ValueKey('reader-tooltip-note')), findsNothing);
    expect(find.byKey(const ValueKey('reader-tooltip-unmark')), findsNothing);
    expect(
      find.byKey(const ValueKey('reader-tooltip-read-aloud')),
      findsNothing,
    );
  });
}
