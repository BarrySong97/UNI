import fs from 'node:fs/promises';
import path from 'node:path';
import { spawn } from 'node:child_process';

import { resolveConfig } from './src/config.mjs';
import { loadCaseCatalog } from './src/cases/load_case_catalog.mjs';
import { renderReferenceArtifacts } from './src/reference/render_epubjs.mjs';
import { invokeFlutterHarness } from './src/canvas/invoke_flutter_harness.mjs';
import { buildBrowserObjects } from './src/cases/classify_browser_object.mjs';
import { buildCanvasObjects } from './src/cases/classify_canvas_object.mjs';
import { buildCaseInventory } from './src/audit/build_case_inventory.mjs';
import { findMissingConversions } from './src/audit/find_missing_conversions.mjs';
import {
  buildMatchedScreenshotPairs,
  matchContentObjects,
} from './src/report/build_matched_screenshot_pairs.mjs';
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

  const caseCatalog = await loadCaseCatalog(config.caseCatalogPath);
  const referenceMetrics = await renderReferenceArtifacts(config);
  const canvasMetrics = await invokeFlutterHarness(config);
  const { browserObjects, ignoredCaseCounts } = buildBrowserObjects(
    referenceMetrics,
    caseCatalog,
  );
  const canvasObjects = buildCanvasObjects(canvasMetrics, caseCatalog);
  const matchedObjects = matchContentObjects({
    browserObjects,
    canvasObjects,
  });
  const missingConversions = await findMissingConversions({
    outDir: config.outDir,
    referenceMetrics,
    browserObjects,
    matchedObjects,
    caseCatalog,
  });
  const caseInventory = buildCaseInventory({
    caseCatalog,
    browserObjects,
    canvasObjects,
    missingConversions,
    ignoredCaseCounts,
  });
  const matchedComparisons = await buildMatchedScreenshotPairs({
    outDir: config.outDir,
    referenceMetrics,
    canvasMetrics,
    matchedObjects,
    browserObjects,
    canvasObjects,
  });

  const report = {
    run: {
      generatedAt: new Date().toISOString(),
      tool: 'reader-render-diff',
      mode: 'case_inventory_missing_conversion_matched_compare',
    },
    inputs: {
      epubPath: config.epubPath,
      sampleName: config.sampleName,
      viewport: config.viewport,
      devicePixelRatio: config.devicePixelRatio,
      fullBook: config.fullBook,
      maxChapters: config.maxChapters,
      maxPagesPerChapter: config.maxPagesPerChapter,
      chapterIndices: config.chapterIndices,
      readerPreferences: config.readerPreferences,
    },
    summary: {
      browserObjectCount: browserObjects.length,
      canvasObjectCount: canvasObjects.length,
      missingConversionCount: missingConversions.length,
      matchedComparisonCount: matchedComparisons.length,
      matchedObjectCount: matchedObjects.length,
      observedBrowserCaseCount: caseInventory.filter((item) => item.observedInBrowser).length,
      convertedCaseCount: caseInventory.filter((item) => item.convertedToNodes).length,
    },
    caseCatalog: caseCatalog.entries,
    caseInventory,
    browserObjects,
    canvasObjects,
    missingConversions,
    matchedComparisons,
  };

  await writeArtifacts(config, {
    caseCatalog: caseCatalog.entries,
    caseInventory,
    browserObjects,
    canvasObjects,
    missingConversions,
    matchedComparisons,
    matchedObjects,
  });

  const reportJsonPath = await writeJsonReport(config, report);
  const reportHtmlPath = await writeHtmlReport(config, report);

  console.log('Reader render diff complete.');
  console.log(`JSON report: ${reportJsonPath}`);
  console.log(`HTML report: ${reportHtmlPath}`);
  console.log(`Browser objects: ${browserObjects.length}`);
  console.log(`Canvas objects: ${canvasObjects.length}`);
  console.log(`Missing conversions: ${missingConversions.length}`);
  console.log(`Matched screenshot comparisons: ${matchedComparisons.length}`);
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

async function writeArtifacts(config, artifacts) {
  const writes = [
    ['case_catalog.json', artifacts.caseCatalog],
    ['case_inventory.json', artifacts.caseInventory],
    ['browser_objects.json', artifacts.browserObjects],
    ['canvas_objects.json', artifacts.canvasObjects],
    ['missing_conversions.json', artifacts.missingConversions],
    ['matched_comparisons.json', artifacts.matchedComparisons],
    ['matched_objects.debug.json', artifacts.matchedObjects],
  ].map(([name, value]) =>
    fs.writeFile(path.join(config.outDir, name), JSON.stringify(value, null, 2)),
  );

  await Promise.all(writes);
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
