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

void main() {
  testWidgets('MainTabShellPage preserves tab state via IndexedStack', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MainTabShellPage(
          pages: <Widget>[
            _CounterPage(label: 'Library'),
            _CounterPage(label: 'Discover'),
            _CounterPage(label: 'Read'),
          ],
        ),
      ),
    );

    await tester.tap(find.text('Add'));
    await tester.pump();
    expect(find.text('Count: 1'), findsOneWidget);

    await tester.tap(find.text('DISCOVER'));
    await tester.pump();
    expect(find.text('Discover'), findsOneWidget);

    await tester.tap(find.text('LIBRARY'));
    await tester.pump();
    expect(find.text('Count: 1'), findsOneWidget);
  });
}
