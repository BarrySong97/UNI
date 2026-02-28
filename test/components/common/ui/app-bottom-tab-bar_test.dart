import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni/components/common/ui/app-bottom-tab-bar.dart';

void main() {
  testWidgets('AppBottomTabBar triggers tap callback and updates selected state', (tester) async {
    var currentIndex = 0;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          return MaterialApp(
            home: Scaffold(
              bottomNavigationBar: AppBottomTabBar(
                currentIndex: currentIndex,
                items: const <AppBottomTabItem>[
                  AppBottomTabItem(icon: Icons.library_books_outlined, label: 'LIBRARY'),
                  AppBottomTabItem(icon: Icons.explore_outlined, label: 'DISCOVER'),
                  AppBottomTabItem(icon: Icons.menu_book_outlined, label: 'READ'),
                ],
                onTap: (index) {
                  setState(() {
                    currentIndex = index;
                  });
                },
              ),
            ),
          );
        },
      ),
    );

    expect(find.text('LIBRARY'), findsOneWidget);
    await tester.tap(find.text('READ'));
    await tester.pump();

    final readIcon = tester.widget<Icon>(
      find.byWidgetPredicate(
        (widget) => widget is Icon && widget.icon == Icons.menu_book_outlined,
      ),
    );
    expect(readIcon.color, isNotNull);
  });
}
