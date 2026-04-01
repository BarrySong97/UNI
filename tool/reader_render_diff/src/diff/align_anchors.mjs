export function alignAnchors(referenceMetrics, canvasMetrics) {
  const canvasByChapter = groupAnchorsByChapter(canvasMetrics.pages);
  const usedCanvasAnchors = new Set();
  const aligned = [];
  const diffs = [];

  for (const page of referenceMetrics.pages) {
    const chapterAnchors = canvasByChapter.get(page.chapterIndex) ?? [];
    for (const referenceAnchor of page.anchors) {
      const matched = matchAnchor(referenceAnchor, chapterAnchors, usedCanvasAnchors);
      if (matched == null) {
        diffs.push({
          scope: 'anchor',
          diffType: 'missing-anchor-on-canvas',
          chapterIndex: referenceAnchor.chapterIndex,
          pageIndex: referenceAnchor.pageIndex,
          anchorHash: referenceAnchor.anchorHash,
          severity: 0.9,
          details: {
            referenceText: referenceAnchor.normalizedText,
          },
        });
        continue;
      }

      usedCanvasAnchors.add(matched.anchorHash + ':' + matched.pageIndex + ':' + matched.order);
      const styleMismatch = referenceAnchor.styleSignature !== matched.styleSignature;
      const lineCountDelta = Math.abs(referenceAnchor.lineCount - matched.lineCount);
      const bboxDelta = bboxDeltaRatio(referenceAnchor.rect, matched.rect);
      const nodeTypeMismatch = referenceAnchor.nodeType !== matched.nodeType;
      const severity = Math.min(
        1,
        (styleMismatch ? 0.35 : 0) +
          Math.min(0.25, lineCountDelta * 0.08) +
          Math.min(0.35, bboxDelta) +
          (nodeTypeMismatch ? 0.2 : 0),
      );

      aligned.push({
        chapterIndex: referenceAnchor.chapterIndex,
        anchorHash: referenceAnchor.anchorHash,
        reference: referenceAnchor,
        canvas: matched,
        severity,
        styleMismatch,
        lineCountDelta,
        bboxDelta,
        nodeTypeMismatch,
      });

      if (severity > 0.01) {
        diffs.push({
          scope: 'anchor',
          diffType: 'anchor-mismatch',
          chapterIndex: referenceAnchor.chapterIndex,
          pageIndex: referenceAnchor.pageIndex,
          anchorHash: referenceAnchor.anchorHash,
          severity,
          details: {
            lineCountDelta,
            bboxDelta,
            nodeTypeMismatch,
            styleMismatch,
            referenceText: referenceAnchor.normalizedText,
          },
        });
      }
    }
  }

  for (const page of canvasMetrics.pages) {
    for (const anchor of page.anchors) {
      const key = anchor.anchorHash + ':' + anchor.pageIndex + ':' + anchor.order;
      if (usedCanvasAnchors.has(key)) {
        continue;
      }
      diffs.push({
        scope: 'anchor',
        diffType: 'missing-anchor-on-reference',
        chapterIndex: anchor.chapterIndex,
        pageIndex: anchor.pageIndex,
        anchorHash: anchor.anchorHash,
        severity: 0.8,
        details: {
          canvasText: anchor.normalizedText,
        },
      });
    }
  }

  return {
    aligned,
    diffs,
  };
}

function groupAnchorsByChapter(pages) {
  const map = new Map();
  for (const page of pages) {
    const list = map.get(page.chapterIndex) ?? [];
    for (const anchor of page.anchors) {
      list.push(anchor);
    }
    map.set(page.chapterIndex, list);
  }
  return map;
}

function matchAnchor(referenceAnchor, chapterAnchors, usedCanvasAnchors) {
  const exact = chapterAnchors.find((anchor) => {
    const key = anchor.anchorHash + ':' + anchor.pageIndex + ':' + anchor.order;
    return !usedCanvasAnchors.has(key) && anchor.anchorHash === referenceAnchor.anchorHash;
  });
  if (exact != null) {
    return exact;
  }

  return chapterAnchors.find((anchor) => {
    const key = anchor.anchorHash + ':' + anchor.pageIndex + ':' + anchor.order;
    return !usedCanvasAnchors.has(key) && anchor.normalizedText === referenceAnchor.normalizedText;
  });
}

function bboxDeltaRatio(a, b) {
  const dx = Math.abs(a.left - b.left);
  const dy = Math.abs(a.top - b.top);
  const dw = Math.abs(a.width - b.width);
  const dh = Math.abs(a.height - b.height);
  const denominator = Math.max(1, a.width + a.height + b.width + b.height);
  return (dx + dy + dw + dh) / denominator;
}
