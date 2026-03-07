import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni/pages/shell/main-tab-shell-page.dart';

class _CounterPage extends StatefulWidget {
  const _CounterPage({required this.label});

  final String label;

  @override
  State<_CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<_CounterPage> {
  int count = 0;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(widget.label),
          Text('Count: $count'),
          ElevatedButton(
            onPressed: () {
              setState(() {
                count++;
              });
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _SimplePage extends StatelessWidget {
  const _SimplePage({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(label));
  }
}

void main() {
  testWidgets('MainTabShellPage preserves tab state via IndexedStack',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MainTabShellPage(
          pages: <Widget>[
            _CounterPage(label: 'Library'),
            _CounterPage(label: 'Reading'),
            _CounterPage(label: 'Settings'),
          ],
        ),
      ),
    );

    // First tab (Library) - increment counter
    await tester.tap(find.text('Add'));
    await tester.pump();
    expect(find.text('Count: 1'), findsOneWidget);

    // Switch to second tab (Reading) by tapping the reading icon
    await tester.tap(find.byIcon(Icons.auto_stories_outlined));
    await tester.pump();
    expect(find.text('Reading'), findsOneWidget);

    // Switch back to first tab (Library) by tapping the library icon (now inactive)
    await tester.tap(find.byIcon(Icons.library_books_outlined));
    await tester.pump();
    // State should be preserved
    expect(find.text('Count: 1'), findsOneWidget);
  });

  testWidgets('MainTabShellPage shows three tab icons', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MainTabShellPage(
          pages: <Widget>[
            _SimplePage(label: 'Library'),
            _SimplePage(label: 'Reading'),
            _SimplePage(label: 'Settings'),
          ],
        ),
      ),
    );

    // Verify all three tab icons are present (active icon for first tab)
    expect(find.byIcon(Icons.library_books), findsOneWidget);
    expect(find.byIcon(Icons.auto_stories_outlined), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
  });
}
