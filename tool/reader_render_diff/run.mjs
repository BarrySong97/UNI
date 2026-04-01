import fs from 'node:fs/promises';
import path from 'node:path';
import { spawn } from 'node:child_process';

import { resolveConfig } from './src/config.mjs';
import { renderReferenceArtifacts } from './src/reference/render_epubjs.mjs';
import { invokeFlutterHarness } from './src/canvas/invoke_flutter_harness.mjs';
import { alignAnchors } from './src/diff/align_anchors.mjs';
import { scoreDiffs } from './src/diff/score_diffs.mjs';
import { writeJsonReport } from './src/report/write_json_report.mjs';
import { writeHtmlReport } from './src/report/write_html_report.mjs';

async function main() {
  const config = await resolveConfig(process.argv.slice(2));
  await ensureDirs(config);
  await extractEpubForReference(config);

  await runCommand(
    'cargo',
    [
      'run',
      '--quiet',
      '--manifest-path',
      'rust/epub_parser/Cargo.toml',
      '--',
      config.epubPath,
      '--batch-export',
      config.cacheDir,
    ],
    config.repoRoot,
  );

  const referenceMetrics = await renderReferenceArtifacts(config);
  const canvasMetrics = await invokeFlutterHarness(config);
  const allowlist = JSON.parse(await fs.readFile(config.allowlistPath, 'utf8'));
  const { aligned, diffs: anchorDiffs } = alignAnchors(referenceMetrics, canvasMetrics);
  const scored = await scoreDiffs({
    referenceMetrics,
    canvasMetrics,
    alignedAnchors: aligned,
    anchorDiffs,
    allowlist,
    diffDir: config.diffDir,
    outDir: config.outDir,
  });

  const report = {
    run: {
      generatedAt: new Date().toISOString(),
      tool: 'reader-render-diff',
    },
    inputs: {
      epubPath: config.epubPath,
      sampleName: config.sampleName,
      viewport: config.viewport,
      devicePixelRatio: config.devicePixelRatio,
      maxChapters: config.maxChapters,
      maxPagesPerChapter: config.maxPagesPerChapter,
      chapterIndices: config.chapterIndices,
      readerPreferences: config.readerPreferences,
    },
    summary: {
      overallSeverity: scored.overallSeverity,
      thresholdResult: scored.thresholdResult,
      allowlistHitCount: scored.allowlistHits.length,
    },
    chapterRanking: scored.chapterRanking,
    pageRanking: scored.pageRanking,
    anchorRanking: scored.anchorRanking,
    allowlistHits: scored.allowlistHits,
    reference: referenceMetrics,
    canvas: canvasMetrics,
  };

  const reportJsonPath = await writeJsonReport(config, report);
  const reportHtmlPath = await writeHtmlReport(config, report);

  console.log(`Render diff complete.`);
  console.log(`JSON report: ${reportJsonPath}`);
  console.log(`HTML report: ${reportHtmlPath}`);
  console.log(`Threshold result: ${scored.thresholdResult.status}`);
}

async function ensureDirs(config) {
  await Promise.all([
    fs.mkdir(config.inputDir, { recursive: true }),
    fs.mkdir(config.extractedDir, { recursive: true }),
    fs.mkdir(config.cacheDir, { recursive: true }),
    fs.mkdir(config.referenceDir, { recursive: true }),
    fs.mkdir(config.canvasDir, { recursive: true }),
    fs.mkdir(config.diffDir, { recursive: true }),
  ]);
}

async function extractEpubForReference(config) {
  await runCommand(
    'unzip',
    ['-o', '-q', config.epubPath, '-d', config.extractedDir],
    config.repoRoot,
  );
  const containerXmlPath = path.join(
    config.extractedDir,
    'META-INF',
    'container.xml',
  );
  const containerXml = await fs.readFile(containerXmlPath, 'utf8');
  const match = containerXml.match(/full-path="([^"]+)"/i);
  if (match == null) {
    throw new Error(`Unable to locate OPF path in ${containerXmlPath}`);
  }
  config.opfPath = match[1];
}

function runCommand(command, args, cwd) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      cwd,
      stdio: 'inherit',
    });
    child.on('error', reject);
    child.on('exit', (code) => {
      if (code === 0) {
        resolve();
        return;
      }
      reject(new Error(`${command} ${args.join(' ')} failed with exit code ${code}`));
    });
  });
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
