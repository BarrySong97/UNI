import '../models/render_node.dart';
import 'render_diff_case_extractor.dart';
import 'render_diff_metrics.dart';

class RenderDiffNodeInventoryResult {
  const RenderDiffNodeInventoryResult({
    required this.items,
    required this.byNode,
  });

  final List<RenderDiffNodeInventoryItem> items;
  final Map<RenderNode, RenderDiffNodeInventoryItem> byNode;
}

class RenderDiffNodeInventory {
  const RenderDiffNodeInventory._();

  static RenderDiffNodeInventoryResult extractChapter({
    required int chapterIndex,
    required List<RenderNode> nodes,
  }) {
    final items = <RenderDiffNodeInventoryItem>[];
    final byNode = <RenderNode, RenderDiffNodeInventoryItem>{};
    var nodeOrdinal = 0;

    void addNode(
      RenderNode node,
      String nodePath, {
      bool isNestedList = false,
    }) {
      if (_isBlockObject(node)) {
        final extracted = RenderDiffCaseExtractor.extract(
          node,
          isNestedList: isNestedList,
        );
        final item = RenderDiffNodeInventoryItem(
          objectId: 'canvas:$chapterIndex:$nodeOrdinal',
          chapterIndex: chapterIndex,
          nodeOrdinal: nodeOrdinal,
          nodePath: nodePath,
          renderNodeKind: node.runtimeType.toString(),
          blockCaseHint: extracted.blockCaseHint,
          featureCaseHints: extracted.featureCaseHints,
          observedCaseHints: extracted.observedCaseHints,
          rawNodeSummary: extracted.rawNodeSummary,
          text: extracted.text,
          normalizedText: extracted.normalizedText,
          imageSignature: extracted.imageSignature,
        );
        items.add(item);
        byNode[node] = item;
        nodeOrdinal += 1;
      }

      switch (node) {
        case ListNode():
          for (
            var itemIndex = 0;
            itemIndex < node.items.length;
            itemIndex += 1
          ) {
            final item = node.items[itemIndex];
            for (
              var subNodeIndex = 0;
              subNodeIndex < item.subNodes.length;
              subNodeIndex += 1
            ) {
              final subNode = item.subNodes[subNodeIndex];
              addNode(
                subNode,
                '$nodePath.items[$itemIndex].subNodes[$subNodeIndex]',
                isNestedList: subNode is ListNode,
              );
            }
          }
          break;
        case _:
          break;
      }
    }

    for (var index = 0; index < nodes.length; index += 1) {
      addNode(nodes[index], 'chapter[$chapterIndex].nodes[$index]');
    }

    return RenderDiffNodeInventoryResult(items: items, byNode: byNode);
  }

  static bool _isBlockObject(RenderNode node) {
    return switch (node) {
      ParagraphNode() ||
      HeadingNode() ||
      ListNode() ||
      TableNode() ||
      BlockQuoteNode() ||
      CodeBlockNode() ||
      ImageNode() ||
      HorizontalRuleNode() ||
      TextNode() => true,
      LineBreakNode() => false,
    };
  }
}
