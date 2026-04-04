import {
  buildImageSignature,
  canonicalizeText,
  computeTextSignalScore,
  normalizeText,
  stableHash,
} from '../shared/text_utils.mjs';

export {
  buildImageSignature,
  canonicalizeText,
  computeTextSignalScore,
  normalizeText,
  stableHash,
};

export function buildReferencePageMetric(rawPage, screenshotPath) {
  const blocks = rawPage.blocks.map((block, order) => {
    const fullText = block.fullText ?? block.text ?? '';
    const visibleText = block.visibleText ?? block.text ?? '';
    const normalizedText = normalizeText(fullText);
    const canonicalText = canonicalizeText(fullText);
    const imageSignature =
      block.imageInfo == null
        ? null
        : buildImageSignature({
            alt: block.imageInfo.alt,
            width: block.imageInfo.naturalWidth,
            height: block.imageInfo.naturalHeight,
          });

    return {
      blockId: `reference-${rawPage.chapterIndex}-${rawPage.pageIndex}-${order}`,
      chapterIndex: rawPage.chapterIndex,
      pageIndex: rawPage.pageIndex,
      order,
      tagName: block.tagName ?? block.nodeType?.toLowerCase() ?? '',
      nodeType: block.nodeType ?? block.tagName?.toUpperCase() ?? '',
      kind: block.kind ?? 'text',
      domPath: block.domPath ?? '',
      rect: block.rect,
      text: visibleText || null,
      visibleText: visibleText || null,
      fullText: fullText || null,
      normalizedText: normalizedText || null,
      canonicalText: canonicalText || null,
      textSignalScore: computeTextSignalScore(fullText),
      imageSignature,
      styleSignature: buildReferenceStyleSignature(block),
      computedStyleSummary: block.computedStyleSummary ?? null,
      featureFlags: block.featureFlags ?? {},
      featureCaseHints: block.featureCaseHints ?? [],
      observedCaseHints: block.observedCaseHints ?? [],
      listInfo: block.listInfo ?? null,
      tableInfo: block.tableInfo ?? null,
      imageInfo: block.imageInfo ?? null,
      lineCount: block.lineCount || null,
      appearanceKey:
        block.domPath != null && block.domPath !== ''
          ? stableHash(`${rawPage.chapterIndex}|${block.domPath}`)
          : null,
    };
  });

  return {
    chapterIndex: rawPage.chapterIndex,
    pageIndex: rawPage.pageIndex,
    screenshotPath,
    normalizedText: normalizeText(
      blocks.map((block) => block.visibleText ?? '').join(' '),
    ),
    blocks,
    href: rawPage.href,
    locationKey: rawPage.locationKey,
  };
}

function buildReferenceStyleSignature(block) {
  const style = block.computedStyleSummary ?? {};
  const parts = [
    `node=${block.nodeType ?? block.tagName ?? ''}`,
    `kind=${block.kind ?? 'text'}`,
  ];

  if (style.fontSizePx != null) {
    parts.push(`size=${Number(style.fontSizePx).toFixed(2)}`);
  }
  parts.push(`weight=${style.fontWeight ?? 400}`);
  parts.push(`italic=${style.fontStyle === 'italic' || style.fontStyle === 'oblique'}`);
  parts.push(`underline=${Boolean(block.featureFlags?.underline)}`);
  parts.push(`strike=${Boolean(block.featureFlags?.strikethrough)}`);
  if (style.colorHex) {
    parts.push(`color=${style.colorHex}`);
  }
  if (style.backgroundHex) {
    parts.push(`bg=${style.backgroundHex}`);
  }
  if (style.textAlign) {
    parts.push(`align=${style.textAlign}`);
  }
  parts.push(`lines=${block.lineCount ?? 0}`);
  return parts.join('|');
}
