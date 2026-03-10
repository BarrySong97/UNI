import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni/components/reader/reader-overlay-controls.dart';

void main() {
  Future<void> pumpControls(
    WidgetTester tester, {
    required bool isVisible,
  }) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          viewPadding: EdgeInsets.only(top: 47, bottom: 34),
        ),
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: <Widget>[
                ReaderOverlayControls(
                  isVisible: isVisible,
                  onBack: () {},
                  onSettings: () {},
                  onActionTap: (_) {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('ReaderOverlayControls renders header and five actions', (
    tester,
  ) async {
    await pumpControls(tester, isVisible: true);

    expect(find.byKey(const Key('reader_overlay_back')), findsOneWidget);
    expect(find.byKey(const Key('reader_overlay_settings')), findsOneWidget);
    expect(
      find.byKey(const Key('reader_overlay_action_contents')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('reader_overlay_action_notes')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('reader_overlay_action_progress')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('reader_overlay_action_brightness')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('reader_overlay_action_font')), findsOneWidget);
    expect(find.text('Contents'), findsNothing);
    expect(find.text('Notes'), findsNothing);
    expect(find.text('Progress'), findsNothing);
    expect(find.text('Brightness'), findsNothing);
    expect(find.text('Font'), findsNothing);
  });

  testWidgets(
    'ReaderOverlayControls slides from screen edges and uses white surfaces',
    (tester) async {
      await pumpControls(tester, isVisible: false);
      await tester.pump();

      final hiddenTopRect = tester.getRect(
        find.byKey(const Key('reader_overlay_top_bar')),
      );
      final hiddenBottomRect = tester.getRect(
        find.byKey(const Key('reader_overlay_bottom_bar')),
      );
      final screenBottom = tester.getRect(find.byType(Scaffold)).bottom;
      expect(hiddenTopRect.bottom, lessThanOrEqualTo(0));
      expect(hiddenBottomRect.top, greaterThanOrEqualTo(screenBottom));

      await pumpControls(tester, isVisible: true);
      await tester.pumpAndSettle();

      final visibleTopRect = tester.getRect(
        find.byKey(const Key('reader_overlay_top_bar')),
      );
      final visibleBottomRect = tester.getRect(
        find.byKey(const Key('reader_overlay_bottom_bar')),
      );
      expect(visibleTopRect.top, 0);
      expect(visibleBottomRect.bottom, screenBottom);

      final topSurface = tester.widget<DecoratedBox>(
        find.byKey(const Key('reader_overlay_top_surface')),
      );
      final bottomSurface = tester.widget<DecoratedBox>(
        find.byKey(const Key('reader_overlay_bottom_surface')),
      );
      final topDecoration = topSurface.decoration as BoxDecoration;
      final bottomDecoration = bottomSurface.decoration as BoxDecoration;
      expect(topDecoration.color, const Color(0xFFFFFFFF));
      expect(bottomDecoration.color, const Color(0xFFFFFFFF));
    },
  );

  testWidgets('ReaderOverlayControls callbacks are invoked', (tester) async {
    var backTapped = false;
    var settingsTapped = false;
    String? actionId;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: <Widget>[
              ReaderOverlayControls(
                isVisible: true,
                onBack: () => backTapped = true,
                onSettings: () => settingsTapped = true,
                onActionTap: (id) => actionId = id,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('reader_overlay_back')));
    await tester.pump();
    expect(backTapped, isTrue);

    await tester.tap(find.byKey(const Key('reader_overlay_settings')));
    await tester.pump();
    expect(settingsTapped, isTrue);

    await tester.tap(find.byKey(const Key('reader_overlay_action_font')));
    await tester.pump();
    expect(actionId, 'font');
  });
}
