import 'package:flutter/material.dart';

import '../../app/providers/app-providers.dart';
import '../../components/highlight/highlight-item.dart';
import '../../shared/ui/app-scaffold.dart';
import '../../shared/ui/empty-view.dart';

class HighlightListPage extends StatefulWidget {
  const HighlightListPage({
    required this.bookId,
    super.key,
  });

  final String bookId;

  @override
  State<HighlightListPage> createState() => _HighlightListPageState();
}

class _HighlightListPageState extends State<HighlightListPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppProvidersScope.of(context).highlightStore.loadHighlights(
        widget.bookId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = AppProvidersScope.of(context).highlightStore;

    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final items = store.state.items;
        return AppScaffold(
          title: 'Highlights',
          body: items.isEmpty
              ? const EmptyView(message: 'No highlights')
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return HighlightItem(
                      highlight: item,
                      onDelete: () {
                        store.deleteHighlight(item.id);
                      },
                    );
                  },
                ),
        );
      },
    );
  }
}
