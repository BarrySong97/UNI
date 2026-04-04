import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uni/services/reader/debug/render_diff_canvas_exporter.dart';
import 'package:uni/services/reader/debug/render_diff_font_loader.dart';
import 'package:uni/services/reader/debug/render_diff_job.dart';

const _jobPath = String.fromEnvironment('RENDER_DIFF_JOB', defaultValue: '');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('exports canvas screenshots and metrics for render diff jobs', () async {
    if (_jobPath.isEmpty) {
      return;
    }

    final file = File(_jobPath);
    expect(
      await file.exists(),
      isTrue,
      reason: 'Job file not found: $_jobPath',
    );

    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final job = RenderDiffJob.fromJson(json);
    await RenderDiffFontLoader.ensureLoaded(job.preferences.fontFamily);

    final exporter = RenderDiffCanvasExporter();
    final metrics = await exporter.export(job);

    expect(metrics.pages, isNotEmpty);
    expect(metrics.nodeInventory, isNotEmpty);
    expect(
      metrics.pages
          .expand((page) => page.blocks)
          .any((block) => block.objectId != null && block.nodePath != null),
      isTrue,
      reason:
          'Canvas metrics did not preserve stable objectId/nodePath mapping.',
    );
    expect(
      File('${job.outputDir}/metrics.json').existsSync(),
      isTrue,
      reason: 'Canvas metrics file was not written.',
    );
  });
}
