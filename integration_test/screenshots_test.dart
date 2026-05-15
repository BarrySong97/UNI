import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uni/app/app.dart';
import 'package:uni/app/bootstrap.dart';
import 'package:uni/app/routes/route-names.dart';
import 'package:uni/components/common/ui/floating-tab-bar.dart';
import 'package:uni/pages/statistics/statistics-types.dart';
import 'package:uni/stores/library/library-store.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture all screenshots', (tester) async {
    // Force the capture surface into a landscape geometry for iPad shots.
    // On recent iPad simulator windowing modes, iOS can reject programmatic
    // orientation changes even when the app supports landscape. Resizing the
    // Flutter test view keeps the screenshot output deterministic and yields the
    // wide iPad layout we actually want to validate.
    const orientation = String.fromEnvironment('SCREENSHOT_ORIENTATION');
    if (orientation == 'landscape') {
      await binding.setSurfaceSize(const Size(1376, 1032));
      addTearDown(() => binding.setSurfaceSize(null));
      await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await _settle(tester, seconds: 2);
    }

    await binding.convertFlutterSurfaceToImage();

    // Belt-and-braces: even if the simulator wasn't uninstalled between runs,
    // make sure onboarding is shown and any stale flag is gone.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('onboarding_completed');

    // Bootstrap directly. Skip SplashApp so the test doesn't have to wait
    // through the splash animation.
    final bootResult = await AppBootstrap.initialize();
    final app = bootResult.app as ImmersedApp;
    final libraryStore = app.providers.libraryStore;

    await tester.pumpWidget(app);
    await _settle(tester, seconds: 2);

    // -- Onboarding step 1 ----------------------------------------------------
    expect(find.text('AI-Powered Explanation'), findsOneWidget);
    await _shoot(binding, '01_onboarding_ai_step');
    await tester.tap(find.text('Skip').first);
    await _settle(tester, seconds: 1);

    // -- Onboarding step 2 ----------------------------------------------------
    await _shoot(binding, '02_onboarding_voice_step');
    await tester.tap(find.text('Skip').first);
    await _settle(tester, seconds: 2);

    // -- Shelf empty ----------------------------------------------------------
    await _shoot(binding, '10_shelf_empty');

    // -- Import sample epub directly via the store ----------------------------
    final epub = await _materializeSampleEpub();
    await libraryStore.importBookFromPath(epub.path);
    await _settle(tester, seconds: 3);

    // -- Shelf with imported book --------------------------------------------
    await _shoot(binding, '11_shelf_with_book');

    // -- Library tab (index 1) -----------------------------------------------
    await _switchTab(tester, 1);
    await _settle(tester, seconds: 2);
    await _shoot(binding, '12_library_books');

    // Notes inside Library
    final notesTab = find.text('Notes');
    if (notesTab.evaluate().isNotEmpty) {
      await tester.tap(notesTab.first);
      await _settle(tester, seconds: 2);
      await _shoot(binding, '13_library_notes_empty');
      final booksTab = find.text('Books');
      if (booksTab.evaluate().isNotEmpty) {
        await tester.tap(booksTab.first);
        await _settle(tester);
      }
    }

    // -- Book Detail (push by route to avoid deciding profile vs reader) ----
    await _captureRoute(
      tester,
      binding,
      name: '14_book_detail',
      pushRoute: (nav) => nav.pushNamed(
        RouteNames.bookDetail,
        arguments: _firstBookId(libraryStore),
      ),
    );

    // -- Statistics – Reading Time -------------------------------------------
    await _captureRoute(
      tester,
      binding,
      name: '30_statistics_reading_time',
      pushRoute: (nav) => nav.pushNamed(
        RouteNames.statistics,
        arguments: const StatisticsPageArguments(
          initialTab: StatisticsTab.readingTime,
          initialPeriodPreset: StatisticsPeriodPreset.thisMonth,
        ),
      ),
    );

    // -- Statistics – Books Read ---------------------------------------------
    await _captureRoute(
      tester,
      binding,
      name: '31_statistics_books_read',
      pushRoute: (nav) => nav.pushNamed(
        RouteNames.statistics,
        arguments: const StatisticsPageArguments(
          initialTab: StatisticsTab.booksRead,
          initialPeriodPreset: StatisticsPeriodPreset.thisYear,
        ),
      ),
    );

    // -- Words list (likely empty on a fresh install) ------------------------
    await _captureRoute(
      tester,
      binding,
      name: '40_words_list',
      pushRoute: (nav) => nav.pushNamed(RouteNames.words),
    );

    // -- Settings tab (index 2) ----------------------------------------------
    await _switchTab(tester, 2);
    await _settle(tester, seconds: 1);
    await _shoot(binding, '50_settings_root');

    await _tapSettingsRowAndShoot(
      tester,
      binding,
      label: 'AI Explain',
      shotName: '51_settings_ai',
      kind: _SettingsRowKind.push,
    );
    await _tapSettingsRowAndShoot(
      tester,
      binding,
      label: 'TTS',
      shotName: '52_settings_tts',
      kind: _SettingsRowKind.push,
    );
    await _tapSettingsRowAndShoot(
      tester,
      binding,
      label: 'Email',
      shotName: '53_settings_email_sheet',
      kind: _SettingsRowKind.sheet,
    );
    await _tapSettingsRowAndShoot(
      tester,
      binding,
      label: 'Social Media',
      shotName: '54_settings_social_sheet',
      kind: _SettingsRowKind.sheet,
    );
    await _tapSettingsRowAndShoot(
      tester,
      binding,
      label: 'Help & FAQ',
      shotName: '55_settings_help_faq',
      kind: _SettingsRowKind.push,
    );
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<void> _shoot(
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
) async {
  await binding.takeScreenshot(name);
}

Future<void> _settle(WidgetTester tester, {int seconds = 1}) async {
  // Real wall-clock wait so async IO (DB queries, EPUB pre-parse, etc.) can
  // make progress. Avoid pumpAndSettle because CircularProgressIndicator
  // animations never settle and would throw a timeout.
  await tester.runAsync(
    () => Future<void>.delayed(Duration(seconds: seconds)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<File> _materializeSampleEpub() async {
  final ByteData data = await rootBundle.load('assets/test/sample.epub');
  final tempDir = await getTemporaryDirectory();
  final file = File(p.join(tempDir.path, 'sample.epub'));
  await file.writeAsBytes(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    flush: true,
  );
  return file;
}

String _firstBookId(LibraryStore store) {
  final books = store.state.books;
  if (books.isEmpty) {
    return '';
  }
  return books.first.id;
}

NavigatorState _rootNav(WidgetTester tester) {
  return tester.state<NavigatorState>(find.byType(Navigator).first);
}

Future<void> _popToRoot(WidgetTester tester) async {
  _rootNav(tester).popUntil((route) => route.isFirst);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await _settle(tester, seconds: 1);
}

Future<void> _captureRoute(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding, {
  required String name,
  required Future<Object?> Function(NavigatorState nav) pushRoute,
}) async {
  // Fire-and-forget; the route stays on screen until we pop it below.
  unawaited(pushRoute(_rootNav(tester)));
  // Drive frames so the MaterialPageRoute transition (~300ms) fully completes
  // before we screenshot. Without this, the screenshot can capture a mid-
  // transition frame where the previous route is still partially visible.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await _settle(tester, seconds: 2);
  await tester.pump();
  await _shoot(binding, name);
  await _popToRoot(tester);
}

enum _SettingsRowKind { push, sheet }

Future<void> _tapSettingsRowAndShoot(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding, {
  required String label,
  required String shotName,
  required _SettingsRowKind kind,
}) async {
  final row = find.text(label);
  if (row.evaluate().isEmpty) {
    return;
  }
  await tester.tap(row.first);
  await _settle(tester, seconds: 2);
  await _shoot(binding, shotName);
  switch (kind) {
    case _SettingsRowKind.sheet:
      _rootNav(tester).pop();
      await _settle(tester);
      break;
    case _SettingsRowKind.push:
      await _popToRoot(tester);
      // Re-select the Settings tab; popping returned to the shell.
      await _switchTab(tester, 2);
      await _settle(tester);
      break;
  }
}

Future<void> _switchTab(WidgetTester tester, int index) async {
  // The bar exposes 3 GestureDetectors (one per tab item) inside a Row.
  // Find them via descendant scoping so we don't accidentally hit page icons.
  const items = <List<IconData>>[
    <IconData>[Icons.library_books_outlined, Icons.library_books],
    <IconData>[Icons.auto_stories_outlined, Icons.auto_stories],
    <IconData>[Icons.settings_outlined, Icons.settings],
  ];
  for (final iconData in items[index]) {
    final f = find.descendant(
      of: find.byType(FloatingTabBar),
      matching: find.byIcon(iconData),
    );
    if (f.evaluate().isNotEmpty) {
      // The active pill in FloatingTabBar visually overlays the icons; the
      // GestureDetector still receives the tap (HitTestBehavior.opaque), but
      // Flutter prints a "would not hit test" warning. Silence it.
      await tester.tap(f.first, warnIfMissed: false);
      return;
    }
  }
}
