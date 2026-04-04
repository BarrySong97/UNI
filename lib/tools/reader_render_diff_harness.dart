import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:uni/services/reader/debug/render_diff_canvas_exporter.dart';
import 'package:uni/services/reader/debug/render_diff_font_loader.dart';
import 'package:uni/services/reader/debug/render_diff_job.dart';

const _jobPath = String.fromEnvironment('RENDER_DIFF_JOB', defaultValue: '');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (_jobPath.isEmpty) {
    stderr.writeln('RENDER_DIFF_JOB was not provided.');
    exitCode = 64;
    return;
  }

  final file = File(_jobPath);
  if (!await file.exists()) {
    stderr.writeln('Render diff job file not found: $_jobPath');
    exitCode = 66;
    return;
  }

  try {
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final job = RenderDiffJob.fromJson(json);
    await RenderDiffFontLoader.ensureLoaded(job.preferences.fontFamily);

    final exporter = RenderDiffCanvasExporter();
    await exporter.export(job);
  } catch (error, stackTrace) {
    stderr.writeln(error);
    stderr.writeln(stackTrace);
    exitCode = 1;
  } finally {
    // Give pending file writes a brief chance to flush before terminating.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    exit(exitCode == 0 ? 0 : exitCode);
  }
}
