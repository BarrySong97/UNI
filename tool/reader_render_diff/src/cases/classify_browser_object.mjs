import {
  buildImageSignature,
  canonicalizeText,
  computeTextSignalScore,
  isTextMatchEligible,
  normalizeText,
  uniqueSorted,
} from '../shared/text_utils.mjs';

const LIST_STYLE_TO_CASE = {
  disc: 'layout.list_style.disc',
  circle: 'layout.list_style.circle',
  square: 'layout.list_style.square',
  decimal: 'layout.list_style.decimal',
  'lower-alpha': 'layout.list_style.lower_alpha',
  'upper-alpha': 'layout.list_style.upper_alpha',
  'lower-roman': 'layout.list_style.lower_roman',
  'upper-roman': 'layout.list_style.upper_roman',
};

export function buildBrowserObjects(referenceMetrics, caseCatalog) {
  const aggregated = new Map();

  for (const page of referenceMetrics.pages ?? []) {
    for (const block of page.blocks ?? []) {
      const classified = classifyBrowserBlock(block, caseCatalog);
      if (classified == null) {
        continue;
      }

      const key = `${page.chapterIndex}:${classified.domPath}`;
      const appearance = {
        pageIndex: page.pageIndex,
        order: block.order,
        rect: block.rect,
        screenshotPath: page.screenshotPath,
      };
      const existing = aggregated.get(key);
      if (existing == null) {
        aggregated.set(key, {
          ...classified,
          chapterIndex: page.chapterIndex,
          appearances: [appearance],
          firstAppearance: appearance,
          order: page.pageIndex * 10000 + block.order,
        });
        continue;
      }

      existing.featureCaseIds = uniqueSorted([
        ...existing.featureCaseIds,
        ...classified.featureCaseIds,
      ]);
      existing.observedCaseIds = uniqueSorted([
        ...existing.observedCaseIds,
        ...classified.observedCaseIds,
      ]);
      existing.appearances.push(appearance);
      if (existing.fullText.length < classified.fullText.length) {
        existing.fullText = classified.fullText;
        existing.text = classified.text;
        existing.visibleText = classified.visibleText;
        existing.normalizedText = classified.normalizedText;
        existing.canonicalText = classified.canonicalText;
        existing.textSignalScore = classified.textSignalScore;
      }
      if (existing.imageSignature == null && classified.imageSignature != null) {
        existing.imageSignature = classified.imageSignature;
      }
      if (
        appearance.pageIndex < existing.firstAppearance.pageIndex ||
        (appearance.pageIndex === existing.firstAppearance.pageIndex &&
          appearance.order < existing.firstAppearance.order)
      ) {
        existing.firstAppearance = appearance;
      }
    }
  }

  const browserObjects = [...aggregated.values()]
    .sort((a, b) => a.chapterIndex - b.chapterIndex || a.order - b.order)
    .map((object, index) => finalizeBrowserObject(object, index, caseCatalog));

  return {
    browserObjects,
    ignoredCaseCounts: buildIgnoredCaseCounts(referenceMetrics),
  };
}

function classifyBrowserBlock(block, caseCatalog) {
  const tagName = String(block.tagName ?? '').toLowerCase();
  const blockCaseId = blockCaseForTag(tagName, block);
  if (blockCaseId == null) {
    return null;
  }

  const featureCaseIds = uniqueSorted([
    ...inlineFeatureCases(block.featureFlags ?? {}),
    ...layoutFeatureCases(block.computedStyleSummary ?? {}, block),
    ...listFeatureCases(block.listInfo),
    ...tableFeatureCases(block.tableInfo),
    ...imageFeatureCases(block.imageInfo),
  ]);
  const observedCaseIds = uniqueSorted([
    blockCaseId,
    ...featureCaseIds,
    ...extraObservedCases(block),
  ]);

  const fullText = String(block.fullText ?? block.text ?? '');
  const visibleText = String(block.visibleText ?? block.text ?? '');
  const imageSignature =
    block.imageInfo == null
      ? null
      : buildImageSignature({
          alt: block.imageInfo.alt,
          width: block.imageInfo.naturalWidth,
          height: block.imageInfo.naturalHeight,
        });

  return {
    blockCaseId,
    featureCaseIds,
    observedCaseIds,
    tagName,
    domPath: block.domPath,
    text: fullText,
    fullText,
    visibleText,
    normalizedText: normalizeText(fullText),
    canonicalText: canonicalizeText(fullText),
    textSignalScore: computeTextSignalScore(fullText),
    imageSignature,
    computedStyleSummary: block.computedStyleSummary ?? {},
    status: caseCatalog.byId[blockCaseId]?.status ?? 'unsupported',
  };
}

function finalizeBrowserObject(object, index, caseCatalog) {
  const appearanceCount = object.appearances.length;
  const firstAppearance = object.firstAppearance;
  const objectId = `browser:${object.chapterIndex}:${String(index).padStart(5, '0')}`;
  const matchEligible = computeBrowserMatchEligibility(object);

  return {
    objectId,
    chapterIndex: object.chapterIndex,
    ordinal: index,
    blockCaseId: object.blockCaseId,
    featureCaseIds: object.featureCaseIds,
    observedCaseIds: object.observedCaseIds,
    tagName: object.tagName,
    text: object.text,
    visibleText: object.visibleText,
    normalizedText: normalizeText(object.normalizedText),
    canonicalText: canonicalizeText(object.canonicalText),
    textSignalScore: object.textSignalScore,
    imageSignature: object.imageSignature,
    domPath: object.domPath,
    rect: firstAppearance?.rect ?? null,
    computedStyleSummary: object.computedStyleSummary,
    screenshotPath: firstAppearance?.screenshotPath ?? null,
    status: caseCatalog.byId[object.blockCaseId]?.status ?? object.status,
    matchEligible: matchEligible.eligible,
    matchIneligibilityReason: matchEligible.reason,
    appearanceCount,
    appearances: object.appearances
      .sort((a, b) => a.pageIndex - b.pageIndex || a.order - b.order)
      .map((appearance) => ({
        pageIndex: appearance.pageIndex,
        order: appearance.order,
        rect: appearance.rect,
        screenshotPath: appearance.screenshotPath,
      })),
  };
}

function blockCaseForTag(tagName, block) {
  if (tagName === 'p') {
    return 'block.paragraph';
  }
  if (/^h[1-6]$/.test(tagName)) {
    return `block.heading.${tagName}`;
  }
  if (tagName === 'ul') {
    return block.listInfo?.nestingDepth > 0 ? 'block.list.nested' : 'block.list.ul';
  }
  if (tagName === 'ol') {
    return block.listInfo?.nestingDepth > 0 ? 'block.list.nested' : 'block.list.ol';
  }
  if (tagName === 'table') {
    return 'block.table.basic';
  }
  if (tagName === 'blockquote') {
    return 'block.blockquote';
  }
  if (tagName === 'pre') {
    return 'block.code.pre';
  }
  if (tagName === 'img') {
    return 'block.image';
  }
  if (tagName === 'hr') {
    return 'block.horizontal_rule';
  }
  if (tagName === 'dt') {
    return 'block.definition_list.dt';
  }
  if (tagName === 'dd') {
    return 'block.definition_list.dd';
  }
  return null;
}

function inlineFeatureCases(flags) {
  const result = [];
  if (flags.bold) {
    result.push('inline.bold');
  }
  if (flags.italic) {
    result.push('inline.italic');
  }
  if (flags.underline) {
    result.push('inline.underline');
  }
  if (flags.strikethrough) {
    result.push('inline.strikethrough');
  }
  if (flags.link) {
    result.push('inline.link');
  }
  if (flags.superscript) {
    result.push('inline.superscript');
  }
  if (flags.subscript) {
    result.push('inline.subscript');
  }
  if (flags.small) {
    result.push('inline.small');
  }
  if (flags.mark) {
    result.push('inline.mark');
  }
  if (flags.inlineCode) {
    result.push('inline.inline_code');
  }
  if (flags.lineBreak) {
    result.push('inline.line_break');
  }
  if (flags.inlineImage) {
    result.push('inline.inline_image_alt_fallback');
  }
  return result;
}

function layoutFeatureCases(style, block) {
  const result = [];
  const textAlign = String(style.textAlign ?? '').toLowerCase();
  if (textAlign === 'center') {
    result.push('layout.align.center');
  } else if (textAlign === 'right' || textAlign === 'end') {
    result.push('layout.align.right');
  } else if (textAlign === 'justify') {
    result.push('layout.align.justify');
  } else if (textAlign !== '') {
    result.push('layout.align.left');
  }

  if (hasAnyPositive(style.marginTopPx, style.marginBottomPx, style.marginLeftPx, style.marginRightPx)) {
    result.push('layout.margin');
  }
  if (hasAnyPositive(style.paddingTopPx, style.paddingBottomPx, style.paddingLeftPx, style.paddingRightPx)) {
    result.push('layout.padding');
  }
  if ((style.textIndentPx ?? 0) > 0) {
    result.push('layout.text_indent');
  }
  if ((style.lineHeightPx ?? 0) > 0) {
    result.push('layout.line_height');
  }
  if (style.colorHex != null) {
    result.push('layout.text_color');
  }
  if (style.backgroundHex != null) {
    result.push('layout.background_color');
  }
  if (String(block.tagName ?? '').toLowerCase() === 'img' && style.renderedWidthPx != null) {
    result.push('layout.image.width_hint');
  }
  return result;
}

function listFeatureCases(listInfo) {
  if (listInfo == null) {
    return [];
  }
  const caseId = LIST_STYLE_TO_CASE[String(listInfo.listStyleType ?? '').toLowerCase()];
  return caseId == null ? [] : [caseId];
}

function tableFeatureCases(tableInfo) {
  if (tableInfo == null) {
    return [];
  }
  const result = [];
  if (tableInfo.hasBorders) {
    result.push('layout.table.border');
  }
  if (tableInfo.hasCellBackground) {
    result.push('layout.table.cell_background');
  }
  if (tableInfo.hasVerticalAlign) {
    result.push('layout.table.vertical_align');
  }
  return result;
}

function imageFeatureCases(imageInfo) {
  if (imageInfo == null) {
    return [];
  }
  const result = [];
  if (imageInfo.widthHint != null) {
    result.push('layout.image.width_hint');
  }
  if (
    Number.isFinite(imageInfo.naturalWidth) &&
    imageInfo.naturalWidth > 0 &&
    Number.isFinite(imageInfo.naturalHeight) &&
    imageInfo.naturalHeight > 0
  ) {
    result.push('layout.image.native_size');
  }
  return result;
}

function extraObservedCases(block) {
  const result = [];
  if (block.tableInfo?.hasCaption) {
    result.push('block.table.caption');
  }
  if (block.tableInfo?.hasHeaderRow) {
    result.push('block.table.header_row');
  }
  if (block.tableInfo?.hasColspan) {
    result.push('block.table.colspan');
  }
  if (block.tableInfo?.hasRowspan) {
    result.push('block.table.rowspan');
  }
  return result;
}

function computeBrowserMatchEligibility(object) {
  if (object.blockCaseId === 'block.horizontal_rule') {
    return { eligible: false, reason: 'rule' };
  }
  if (object.blockCaseId === 'block.image') {
    const info = object.imageSignature != null;
    return {
      eligible: info,
      reason: info ? null : 'image_without_signature',
    };
  }
  const eligible = isTextMatchEligible(object.normalizedText);
  return {
    eligible,
    reason: eligible ? null : 'low_text_signal',
  };
}

function hasAnyPositive(...values) {
  return values.some((value) => Number.isFinite(value) && value > 0.5);
}

function buildIgnoredCaseCounts(referenceMetrics) {
  const counts = {};
  for (const chapter of referenceMetrics.chapterSpecialCases ?? []) {
    for (const entry of chapter.cases ?? []) {
      counts[entry.caseId] = (counts[entry.caseId] ?? 0) + (entry.count ?? 0);
    }
  }
  return counts;
}
