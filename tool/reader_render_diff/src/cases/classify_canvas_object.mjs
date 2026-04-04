import {
  canonicalizeText,
  computeTextSignalScore,
  isTextMatchEligible,
  normalizeText,
  uniqueSorted,
} from '../shared/text_utils.mjs';

export function buildCanvasObjects(canvasMetrics, caseCatalog) {
  const appearancesByObjectId = new Map();

  for (const page of canvasMetrics.pages ?? []) {
    for (const block of page.blocks ?? []) {
      if (block.objectId == null) {
        continue;
      }
      const list = appearancesByObjectId.get(block.objectId) ?? [];
      list.push({
        pageIndex: page.pageIndex,
        order: block.order,
        rect: block.rect,
        screenshotPath: page.screenshotPath,
        nodePath: block.nodePath ?? null,
      });
      appearancesByObjectId.set(block.objectId, list);
    }
  }

  return (canvasMetrics.nodeInventory ?? [])
    .map((item) => classifyCanvasItem(item, appearancesByObjectId.get(item.objectId) ?? [], caseCatalog))
    .filter(Boolean)
    .sort((a, b) => a.chapterIndex - b.chapterIndex || a.nodeOrdinal - b.nodeOrdinal);
}

function classifyCanvasItem(item, appearances, caseCatalog) {
  const blockCaseId = item.blockCaseHint ?? blockCaseFromRenderNodeKind(item.renderNodeKind);
  if (blockCaseId == null) {
    return null;
  }

  const featureCaseIds = uniqueSorted(item.featureCaseHints ?? []);
  const observedCaseIds = uniqueSorted([
    blockCaseId,
    ...(item.observedCaseHints ?? []),
    ...featureCaseIds,
  ]);
  const text = String(item.text ?? '');
  const normalizedText = normalizeText(item.normalizedText ?? text);
  const canonicalText = canonicalizeText(normalizedText);
  const firstAppearance = [...appearances].sort(
    (a, b) => a.pageIndex - b.pageIndex || a.order - b.order,
  )[0];
  const matchEligible = computeCanvasMatchEligibility({
    blockCaseId,
    normalizedText,
    imageSignature: item.imageSignature ?? null,
  });

  return {
    objectId: item.objectId,
    chapterIndex: item.chapterIndex,
    nodeOrdinal: item.nodeOrdinal,
    ordinal: item.nodeOrdinal,
    blockCaseId,
    featureCaseIds,
    observedCaseIds,
    renderNodeKind: item.renderNodeKind,
    text,
    normalizedText,
    canonicalText,
    textSignalScore: computeTextSignalScore(normalizedText),
    imageSignature: item.imageSignature ?? null,
    nodePath: item.nodePath,
    rawNodeSummary: item.rawNodeSummary ?? {},
    status: caseCatalog.byId[blockCaseId]?.status ?? 'unsupported',
    matchEligible: matchEligible.eligible,
    matchIneligibilityReason: matchEligible.reason,
    screenshotPath: firstAppearance?.screenshotPath ?? null,
    rect: firstAppearance?.rect ?? null,
    appearances: [...appearances].sort((a, b) => a.pageIndex - b.pageIndex || a.order - b.order),
  };
}

function computeCanvasMatchEligibility({ blockCaseId, normalizedText, imageSignature }) {
  if (blockCaseId === 'block.horizontal_rule') {
    return { eligible: false, reason: 'rule' };
  }
  if (blockCaseId === 'block.image') {
    return {
      eligible: imageSignature != null,
      reason: imageSignature != null ? null : 'image_without_signature',
    };
  }
  const eligible = isTextMatchEligible(normalizedText);
  return {
    eligible,
    reason: eligible ? null : 'low_text_signal',
  };
}

function blockCaseFromRenderNodeKind(renderNodeKind) {
  switch (renderNodeKind) {
    case 'ParagraphNode':
      return 'block.paragraph';
    case 'HeadingNode':
      return 'block.heading.h1';
    case 'ListNode':
      return 'block.list.ul';
    case 'TableNode':
      return 'block.table.basic';
    case 'BlockQuoteNode':
      return 'block.blockquote';
    case 'CodeBlockNode':
      return 'block.code.pre';
    case 'ImageNode':
      return 'block.image';
    case 'HorizontalRuleNode':
      return 'block.horizontal_rule';
    case 'TextNode':
      return 'block.bare_text_wrapped_paragraph';
    default:
      return null;
  }
}
