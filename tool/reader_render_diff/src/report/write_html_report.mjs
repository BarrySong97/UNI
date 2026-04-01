import fs from 'node:fs/promises';
import path from 'node:path';

export async function writeHtmlReport(config, report) {
  const anchorByPage = groupAnchorsByPage(report.anchorRanking);
  const pageItems = report.pageRanking
    .slice(0, 20)
    .map((diff) => {
      const details = diff.details ?? {};
      const referencePath = relativeAsset('reference', details.referenceScreenshotPath);
      const canvasPath = relativeAsset('canvas', details.canvasScreenshotPath);
      const diffPath = relativeAsset('diff', details.diffImagePath);
      const relatedAnchorDiffs = anchorByPage.get(pageKey(diff.chapterIndex, diff.pageIndex)) ?? [];
      const issueItems = summarizePageIssues(diff, relatedAnchorDiffs)
        .map((item) => `<li>${escapeHtml(item)}</li>`)
        .join('\n');
      const excerpt = pickExcerpt(relatedAnchorDiffs);
      return `
        <section class="card">
          <h3>Chapter ${diff.chapterIndex} / Page ${diff.pageIndex}</h3>
          <p>Severity: ${diff.severity.toFixed(3)} | Pixel diff: ${Number(details.pixelDiffRatio ?? 0).toFixed(3)}</p>
          <div class="page-layout">
            <div class="visuals">
              <div class="grid">
                <figure><figcaption>Reference</figcaption><img src="${referencePath}" /></figure>
                <figure><figcaption>Canvas</figcaption><img src="${canvasPath}" /></figure>
                <figure><figcaption>Diff</figcaption><img src="${diffPath}" /></figure>
              </div>
            </div>
            <aside class="issues">
              <h4>Problems</h4>
              <ul>${issueItems || '<li>No explicit issues were summarized for this page.</li>'}</ul>
              ${
                excerpt == null
                  ? ''
                  : `<div class="excerpt"><div class="label">Excerpt</div><code>${escapeHtml(excerpt)}</code></div>`
              }
            </aside>
          </div>
        </section>
      `;
    })
    .join('\n');

  const anchorItems = report.anchorRanking
    .slice(0, 30)
    .map(
      (diff) => `
        <tr>
          <td>${diff.chapterIndex}</td>
          <td>${diff.pageIndex ?? ''}</td>
          <td>${diff.diffType}</td>
          <td>${diff.anchorHash ?? ''}</td>
          <td>${diff.severity.toFixed(3)}</td>
          <td><code>${escapeHtml(diff.details?.referenceText ?? diff.details?.canvasText ?? '')}</code></td>
        </tr>
      `,
    )
    .join('\n');

  const html = `<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8" />
    <title>Reader Render Diff Report</title>
    <style>
      body { font-family: Georgia, serif; margin: 24px; color: #1a1a1a; background: #f4f1ea; }
      h1, h2, h3, h4 { margin: 0 0 12px; }
      .summary { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 12px; margin-bottom: 24px; }
      .card { background: #fffdf8; border: 1px solid #d6cdbf; border-radius: 12px; padding: 16px; margin-bottom: 16px; }
      .metric { font-size: 24px; font-weight: 600; }
      .label { color: #6a6258; font-size: 12px; text-transform: uppercase; letter-spacing: 0.08em; }
      .grid { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 12px; }
      .page-layout { display: grid; grid-template-columns: minmax(0, 2.2fr) minmax(280px, 1fr); gap: 16px; align-items: start; }
      .issues { background: #f7f1e6; border: 1px solid #ddd1bf; border-radius: 10px; padding: 12px; }
      .issues ul { margin: 0; padding-left: 18px; }
      .issues li { margin-bottom: 8px; }
      .excerpt { margin-top: 12px; }
      figure { margin: 0; }
      img { width: 100%; border: 1px solid #d6cdbf; background: #ffffff; }
      table { width: 100%; border-collapse: collapse; }
      th, td { border-top: 1px solid #e3dbcf; padding: 8px; text-align: left; vertical-align: top; }
      code { white-space: pre-wrap; }
      @media (max-width: 1100px) {
        .page-layout { grid-template-columns: 1fr; }
      }
    </style>
  </head>
  <body>
    <h1>Reader Render Diff Report</h1>
    <p>${escapeHtml(report.inputs.sampleName ?? path.basename(report.inputs.epubPath))}</p>

    <section class="summary">
      <div class="card"><div class="label">Threshold</div><div class="metric">${report.summary.thresholdResult.status}</div></div>
      <div class="card"><div class="label">Overall Severity</div><div class="metric">${report.summary.overallSeverity.toFixed(3)}</div></div>
      <div class="card"><div class="label">Page Diffs</div><div class="metric">${report.pageRanking.length}</div></div>
      <div class="card"><div class="label">Anchor Diffs</div><div class="metric">${report.anchorRanking.length}</div></div>
    </section>

    <section class="card">
      <h2>Chapter Ranking</h2>
      <table>
        <thead><tr><th>Chapter</th><th>Severity</th><th>Count</th></tr></thead>
        <tbody>
          ${report.chapterRanking
            .map(
              (entry) => `
                <tr>
                  <td>${entry.chapterIndex}</td>
                  <td>${entry.severity.toFixed(3)}</td>
                  <td>${entry.count}</td>
                </tr>
              `,
            )
            .join('\n')}
        </tbody>
      </table>
    </section>

    <section class="card">
      <h2>Top Page Diffs</h2>
      ${pageItems || '<p>No page diffs.</p>'}
    </section>

    <section class="card">
      <h2>Top Anchor Diffs</h2>
      <table>
        <thead><tr><th>Chapter</th><th>Page</th><th>Type</th><th>Anchor</th><th>Severity</th><th>Text</th></tr></thead>
        <tbody>${anchorItems || '<tr><td colspan="6">No anchor diffs.</td></tr>'}</tbody>
      </table>
    </section>
  </body>
</html>`;

  const filePath = path.join(config.outDir, 'report.html');
  await fs.writeFile(filePath, html);
  return filePath;
}

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
}

function relativeAsset(scope, relativePath) {
  if (relativePath == null) {
    return '';
  }
  return `./${scope}/${relativePath}`.replaceAll('\\', '/');
}

function summarizePageIssues(pageDiff, anchorDiffs) {
  const details = pageDiff.details ?? {};
  const issues = [];

  if (details.textMismatch) {
    issues.push('The visible text content differs between browser rendering and Canvas rendering on this page.');
  }

  if ((details.pixelDiffRatio ?? 0) > 0.08) {
    issues.push(
      `The page-level visual difference is high (${Number(details.pixelDiffRatio).toFixed(3)}), so spacing, positioning, or paint output is noticeably different.`,
    );
  }

  if ((details.blockCountDelta ?? 0) > 0) {
    issues.push(
      `The two renderers produced a different number of visible blocks (${details.blockCountDelta} block delta).`,
    );
  }

  const missingCanvas = anchorDiffs.filter((diff) => diff.diffType === 'missing-anchor-on-canvas');
  if (missingCanvas.length > 0) {
    issues.push(
      `Canvas is missing ${missingCanvas.length} anchor segment(s) that are visible in the browser reference.`,
    );
  }

  const missingReference = anchorDiffs.filter((diff) => diff.diffType === 'missing-anchor-on-reference');
  if (missingReference.length > 0) {
    issues.push(
      `Canvas produced ${missingReference.length} anchor segment(s) that could not be matched back to the browser reference.`,
    );
  }

  const anchorMismatch = anchorDiffs.filter((diff) => diff.diffType === 'anchor-mismatch');
  if (anchorMismatch.length > 0) {
    const styleMismatch = anchorMismatch.some((diff) => diff.details?.styleMismatch);
    const nodeTypeMismatch = anchorMismatch.some((diff) => diff.details?.nodeTypeMismatch);
    const lineDelta = Math.max(
      0,
      ...anchorMismatch.map((diff) => Number(diff.details?.lineCountDelta ?? 0)),
    );
    if (styleMismatch) {
      issues.push('Matched text anchors have style differences, so font weight, decoration, color, or block styling is drifting.');
    }
    if (nodeTypeMismatch) {
      issues.push('Matched text anchors map to different block types across the two renderers.');
    }
    if (lineDelta > 0) {
      issues.push(`Matched text anchors disagree on line count, with a maximum delta of ${lineDelta}.`);
    }
  }

  return issues;
}

function pickExcerpt(anchorDiffs) {
  for (const diff of anchorDiffs) {
    const text = diff.details?.referenceText ?? diff.details?.canvasText;
    if (text != null && text !== '') {
      return text;
    }
  }
  return null;
}

function groupAnchorsByPage(anchorRanking) {
  const map = new Map();
  for (const diff of anchorRanking) {
    const key = pageKey(diff.chapterIndex, diff.pageIndex);
    const list = map.get(key) ?? [];
    list.push(diff);
    map.set(key, list);
  }
  return map;
}

function pageKey(chapterIndex, pageIndex) {
  return `${chapterIndex}:${pageIndex ?? ''}`;
}
