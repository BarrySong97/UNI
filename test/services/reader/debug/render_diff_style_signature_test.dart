import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni/services/reader/debug/render_diff_style_signature.dart';
import 'package:uni/services/reader/models/page_layout.dart';
import 'package:uni/services/reader/models/render_node.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('style signature includes text and decoration traits', () {
    final element = LayoutElement(
      rect: const Rect.fromLTWH(0, 0, 100, 20),
      sourceNode: const ParagraphNode(
        children: [TextNode(content: 'Example', bold: true, underline: true)],
      ),
      textPainter: TextPainter(
        text: const TextSpan(
          text: 'Example',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.underline,
            color: Color(0xFF112233),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(),
      backgroundPaint: Paint()..color = const Color(0xFFEFEFEF),
    );

    final signature = RenderDiffStyleSignature.forLayoutBlock(
      sourceNode: element.sourceNode,
      elements: [element],
    );

    expect(signature, contains('node=ParagraphNode'));
    expect(signature, contains('weight=700'));
    expect(signature, contains('underline=true'));
    expect(signature, contains('color=ff112233'));
    expect(signature, contains('bg=ffefefef'));
  });
}
