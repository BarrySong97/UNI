import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni/components/library/library-reading-stats.dart';
import 'package:uni/entities/reading-time-entity.dart';

void main() {
  testWidgets('renders monthly reading time from ReadingTimeEntity', (
    tester,
  ) async {
    final dailySeconds = List<int>.filled(31, 0);
    dailySeconds[0] = 900;
    dailySeconds[1] = 4500;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LibraryReadingStats(
            readingTime: ReadingTimeEntity(
              year: 2026,
              month: 3,
              totalSeconds: 5400,
              dailySeconds: dailySeconds,
            ),
            booksReadThisYear: 7,
          ),
        ),
      ),
    );

    expect(find.text('MARCH'), findsOneWidget);
    final richTexts = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((widget) => widget.text.toPlainText())
        .toList();
    expect(richTexts.any((text) => text.contains('1h 30m')), isTrue);
    expect(richTexts.any((text) => text.contains('7  this year')), isTrue);
    expect(
      find.byKey(const ValueKey<String>('reading-bar-bg-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('reading-bar-bg-30')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('reading-bar-fill-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('reading-bar-fill-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('reading-bar-fill-2')),
      findsNothing,
    );

    final firstFill = tester.widget<FractionallySizedBox>(
      find.ancestor(
        of: find.byKey(const ValueKey<String>('reading-bar-fill-0')),
        matching: find.byType(FractionallySizedBox),
      ),
    );
    final secondFill = tester.widget<FractionallySizedBox>(
      find.ancestor(
        of: find.byKey(const ValueKey<String>('reading-bar-fill-1')),
        matching: find.byType(FractionallySizedBox),
      ),
    );
    expect(firstFill.heightFactor, closeTo(900 / 86400, 0.0001));
    expect(secondFill.heightFactor, closeTo(4500 / 86400, 0.0001));
  });

  testWidgets('renders zero reading time when no monthly data exists', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LibraryReadingStats(
            readingTime: ReadingTimeEntity.empty(year: 2026, month: 3),
            booksReadThisYear: 0,
          ),
        ),
      ),
    );

    final richTexts = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((widget) => widget.text.toPlainText())
        .toList();
    expect(richTexts.any((text) => text.contains('0h 0m')), isTrue);
    expect(richTexts.any((text) => text.contains('0  this year')), isTrue);
    expect(
      find.byKey(const ValueKey<String>('reading-bar-bg-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('reading-bar-fill-0')),
      findsNothing,
    );
  });
}
