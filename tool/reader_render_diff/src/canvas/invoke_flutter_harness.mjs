import fs from 'node:fs/promises';
import path from 'node:path';
import { spawn } from 'node:child_process';

export async function invokeFlutterHarness(config) {
  await fs.mkdir(config.canvasDir, { recursive: true });
  const jobPath = path.join(config.inputDir, 'canvas_job.json');
  const job = {
    epubPath: config.epubPath,
    cacheDir: config.cacheDir,
    outputDir: config.canvasDir,
    viewportWidth: config.viewport.width,
    viewportHeight: config.viewport.height,
    devicePixelRatio: config.devicePixelRatio,
    preferences: config.readerPreferences,
    sampleName: config.sampleName,
    chapterIndices: config.chapterIndices,
    maxChapters: config.maxChapters,
    maxPagesPerChapter: config.maxPagesPerChapter,
  };
  await fs.mkdir(config.inputDir, { recursive: true });
  await fs.writeFile(jobPath, JSON.stringify(job, null, 2));

  await runCommand(
    'flutter',
    [
      'test',
      'test/tools/reader_render_diff/canvas_snapshot_harness_test.dart',
      `--dart-define=RENDER_DIFF_JOB=${jobPath}`,
    ],
    config.repoRoot,
  );

  const metricsPath = path.join(config.canvasDir, 'metrics.json');
  const json = JSON.parse(await fs.readFile(metricsPath, 'utf8'));
  return json;
}

function runCommand(command, args, cwd) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      cwd,
      stdio: 'inherit',
    });

    child.on('exit', (code) => {
      if (code === 0) {
        resolve();
        return;
      }
      reject(new Error(`${command} ${args.join(' ')} failed with exit code ${code}`));
    });
    child.on('error', reject);
  });
}
