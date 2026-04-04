import fs from 'node:fs/promises';
import path from 'node:path';

export async function writeHtmlReport(config, report) {
  const html = `<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8" />
    <title>Reader Render Diff Report</title>
    <style>
      :root {
        --bg: #f5f2ec;
        --panel: #fffdfa;
        --panel-alt: #faf4ea;
        --line: #dfd5c6;
        --text: #241d16;
        --muted: #6b6256;
        --accent: #9a5c2f;
      }
      * { box-sizing: border-box; }
      body {
        margin: 0;
        padding: 24px;
        background: linear-gradient(180deg, #f4eee4 0%, var(--bg) 100%);
        color: var(--text);
        font-family: Georgia, "Times New Roman", serif;
      }
      h1, h2, h3, p { margin: 0; }
      h1 { font-size: 36px; margin-bottom: 8px; }
      h2 { font-size: 24px; margin-bottom: 12px; }
      p { line-height: 1.5; }
      .lede { color: var(--muted); margin-bottom: 20px; max-width: 880px; }
      .summary {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
        gap: 12px;
        margin-bottom: 24px;
      }
      .metric {
        background: var(--panel);
        border: 1px solid var(--line);
        border-radius: 16px;
        padding: 16px;
      }
      .metric-label {
        color: var(--muted);
        font-size: 12px;
        text-transform: uppercase;
        letter-spacing: 0.08em;
        margin-bottom: 10px;
      }
      .metric-value {
        font-size: 30px;
        font-weight: 700;
      }
      section {
        background: var(--panel);
        border: 1px solid var(--line);
        border-radius: 18px;
        padding: 20px;
        margin-bottom: 18px;
      }
      .section-inner {
        max-width: 1480px;
      }
      table {
        width: 100%;
        border-collapse: collapse;
        font-size: 14px;
      }
      th, td {
        text-align: left;
        padding: 10px 8px;
        border-bottom: 1px solid #ede4d8;
        vertical-align: top;
      }
      th {
        color: var(--muted);
        font-size: 12px;
        text-transform: uppercase;
        letter-spacing: 0.08em;
      }
      .pill {
        display: inline-block;
        padding: 4px 8px;
        border-radius: 999px;
        font-size: 12px;
        background: var(--panel-alt);
        border: 1px solid var(--line);
      }
      .cards {
        display: flex;
        flex-direction: column;
        gap: 16px;
        max-width: 1480px;
      }
      .card {
        border: 1px solid var(--line);
        border-radius: 16px;
        padding: 18px;
        background: #fffaf4;
        width: 100%;
      }
      .meta {
        color: var(--muted);
        font-size: 12px;
        margin-bottom: 8px;
      }
      .excerpt {
        padding: 10px 12px;
        border-radius: 12px;
        background: var(--panel-alt);
        border: 1px solid var(--line);
        margin-bottom: 12px;
        white-space: pre-wrap;
      }
      .gallery {
        display: grid;
        grid-template-columns: repeat(2, minmax(0, 1fr));
        gap: 16px;
        align-items: start;
      }
      figure {
        margin: 0;
      }
      figcaption {
        font-size: 12px;
        color: var(--muted);
        margin-bottom: 8px;
      }
      img {
        width: 100%;
        display: block;
        border: 1px solid var(--line);
        border-radius: 12px;
        background: #fff;
      }
      .empty {
        color: var(--muted);
      }
      @media (max-width: 900px) {
        .gallery {
          grid-template-columns: 1fr;
        }
      }
    </style>
  </head>
  <body>
    <h1>Reader Render Diff</h1>
    <p class="lede">${escapeHtml(report.inputs.sampleName ?? path.basename(report.inputs.epubPath))} · Three-stage audit: case inventory, missing conversion evidence, matched screenshot compare.</p>

    <div class="summary">
      <div class="metric"><div class="metric-label">Browser Objects</div><div class="metric-value">${report.summary.browserObjectCount}</div></div>
      <div class="metric"><div class="metric-label">Canvas Objects</div><div class="metric-value">${report.summary.canvasObjectCount}</div></div>
      <div class="metric"><div class="metric-label">Missing Conversions</div><div class="metric-value">${report.summary.missingConversionCount}</div></div>
      <div class="metric"><div class="metric-label">Matched Compares</div><div class="metric-value">${report.summary.matchedComparisonCount}</div></div>
    </div>

    <section>
      <div class="section-inner">
      <h2>Case Inventory</h2>
      <p class="lede">This table is case-first, not page-first. It shows what appeared in browser HTML, what already exists in RenderNode inventory, and where missing conversions still remain.</p>
      <table>
        <thead>
          <tr>
            <th>Case ID</th>
            <th>Layer</th>
            <th>Status</th>
            <th>Observed In Browser</th>
            <th>Converted To Nodes</th>
            <th>Missing Count</th>
            <th>Ignored Count</th>
            <th>Example Chapters</th>
          </tr>
        </thead>
        <tbody>
          ${report.caseInventory.map((item) => renderInventoryRow(item)).join('\n')}
        </tbody>
      </table>
      </div>
    </section>

    <section>
      <div class="section-inner">
      <h2>Missing Conversion</h2>
      <p class="lede">Only browser-side evidence is shown here. These are observed browser content objects for supported or partial cases that did not get a high-confidence RenderNode match.</p>
      ${renderMissingSection(report.missingConversions)}
      </div>
    </section>

    <section>
      <div class="section-inner">
      <h2>Matched Screenshot Compare</h2>
      <p class="lede">Only high-confidence one-to-one matches appear here. No page parity, no fuzzy matches, and no automatic judgment about which rendering is correct.</p>
      ${renderMatchedSection(report.matchedComparisons)}
      </div>
    </section>
  </body>
</html>`;

  const filePath = path.join(config.outDir, 'report.html');
  await fs.writeFile(filePath, html);
  return filePath;
}

function renderInventoryRow(item) {
  return `
    <tr>
      <td><strong>${escapeHtml(item.caseId)}</strong></td>
      <td>${escapeHtml(item.layer)}</td>
      <td><span class="pill">${escapeHtml(item.status)}</span></td>
      <td>${item.observedInBrowser ? `yes (${item.browserCount})` : 'no'}</td>
      <td>${item.convertedToNodes ? `yes (${item.canvasCount})` : 'no'}</td>
      <td>${item.missingCount}</td>
      <td>${item.ignoredCount}</td>
      <td>${item.exampleChapters.length === 0 ? '<span class="empty">not observed</span>' : item.exampleChapters.map((chapter) => `ch${chapter}`).join(', ')}</td>
    </tr>
  `;
}

function renderMissingSection(items) {
  if ((items ?? []).length === 0) {
    return '<p class="empty">No missing conversions were detected in this run.</p>';
  }

  return `<div class="cards">${items.map((item) => renderMissingCard(item)).join('\n')}</div>`;
}

function renderMissingCard(item) {
  const featureCases =
    item.featureCaseIds?.length > 0
      ? escapeHtml(item.featureCaseIds.join(', '))
      : 'none';

  return `
    <article class="card">
      <div class="meta">Chapter ${item.chapterIndex} · ${escapeHtml(item.blockCaseId)} · ${escapeHtml(item.reason)}</div>
      <div class="meta">Feature cases: ${featureCases}</div>
      <div class="meta">DOM path: ${escapeHtml(item.domPath)}</div>
      <div class="excerpt">${escapeHtml(item.excerpt || '')}</div>
      ${item.browserCropPath ? `<figure><figcaption>Browser HTML evidence</figcaption><img loading="lazy" src="./${item.browserCropPath}" /></figure>` : '<p class="empty">No browser crop was available for this item.</p>'}
    </article>
  `;
}

function renderMatchedSection(items) {
  if ((items ?? []).length === 0) {
    return '<p class="empty">No high-confidence matched screenshot pairs were generated.</p>';
  }

  return `<div class="cards">${items.map((item) => renderMatchedCard(item)).join('\n')}</div>`;
}

function renderMatchedCard(item) {
  const featureCases =
    item.featureCaseIds?.length > 0
      ? escapeHtml(item.featureCaseIds.join(', '))
      : 'none';

  return `
    <article class="card">
      <div class="meta">Chapter ${item.chapterIndex} · ${escapeHtml(item.blockCaseId)} · ${escapeHtml(item.matchKind)}</div>
      <div class="meta">Feature cases: ${featureCases}</div>
      <div class="excerpt">${escapeHtml(item.excerpt || '')}</div>
      <div class="gallery">
        <figure>
          <figcaption>Browser HTML · page ${item.browserPageIndex}</figcaption>
          <img loading="lazy" src="./${item.browserCropPath}" />
        </figure>
        <figure>
          <figcaption>Flutter Canvas · page ${item.canvasPageIndex}</figcaption>
          <img loading="lazy" src="./${item.canvasCropPath}" />
        </figure>
      </div>
    </article>
  `;
}

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}
