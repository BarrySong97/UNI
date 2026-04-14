import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni/shared/widgets/pronunciation_selection_toolbar.dart';

void main() {
  testWidgets('renders IPA with pronounce and copy actions', (tester) async {
    var pronounceTapped = false;
    var copyTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PronunciationSelectionToolbar(
            anchors: const TextSelectionToolbarAnchors(
              primaryAnchor: Offset(120, 120),
            ),
            ipaLabel: '/ɪˈfem.ə.rəl/',
            buttonItems: [
              ContextMenuButtonItem(
                label: 'Pronounce',
                onPressed: () => pronounceTapped = true,
              ),
              ContextMenuButtonItem(
                label: 'Copy',
                onPressed: () => copyTapped = true,
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('pronunciation-selection-ipa')),
      findsOneWidget,
    );
    expect(find.text('/ɪˈfem.ə.rəl/'), findsOneWidget);
    expect(find.text('Pronounce'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);

    await tester.tap(find.text('Pronounce'));
    await tester.pump();
    expect(pronounceTapped, isTrue);

    await tester.tap(find.text('Copy'));
    await tester.pump();
    expect(copyTapped, isTrue);
  });

  testWidgets('hides IPA section when no IPA is available', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PronunciationSelectionToolbar(
            anchors: const TextSelectionToolbarAnchors(
              primaryAnchor: Offset(120, 120),
            ),
            buttonItems: [
              ContextMenuButtonItem(label: 'Pronounce', onPressed: () {}),
              ContextMenuButtonItem(label: 'Copy', onPressed: () {}),
            ],
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('pronunciation-selection-ipa')),
      findsNothing,
    );
    expect(find.text('Pronounce'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
  });

  testWidgets('renders AI button when IPA is unavailable', (tester) async {
    var aiTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PronunciationSelectionToolbar(
            anchors: const TextSelectionToolbarAnchors(
              primaryAnchor: Offset(120, 120),
            ),
            aiButtonLabel: 'AI',
            onAiPressed: () => aiTapped = true,
            buttonItems: [
              ContextMenuButtonItem(label: 'Pronounce', onPressed: () {}),
              ContextMenuButtonItem(label: 'Copy', onPressed: () {}),
            ],
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('pronunciation-selection-ai')),
      findsOneWidget,
    );
    await tester.tap(find.text('AI'));
    await tester.pump();
    expect(aiTapped, isTrue);
  });
}
