export function normalizeText(text) {
  return text
    .replaceAll('\u00A0', ' ')
    .replaceAll('\u200B', '')
    .replaceAll('\r\n', '\n')
    .replaceAll('\r', '\n')
    .replace(/\s+/g, ' ')
    .trim();
}

export function stableHash(input) {
  let hash = 0x811c9dc5;
  for (let index = 0; index < input.length; index += 1) {
    hash ^= input.charCodeAt(index);
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  return hash.toString(16).padStart(8, '0');
}

export function buildReferencePageMetric(rawPage, screenshotPath) {
  const blocks = rawPage.blocks.map((block, order) => {
    const normalized = normalizeText(block.text ?? '');
    const anchorHash =
      normalized.length === 0
        ? null
        : stableHash(`${rawPage.chapterIndex}|${block.nodeType}|${normalized}`);
    return {
      blockId: `reference-${rawPage.chapterIndex}-${rawPage.pageIndex}-${order}`,
      chapterIndex: rawPage.chapterIndex,
      pageIndex: rawPage.pageIndex,
      order,
      nodeType: block.nodeType,
      kind: block.kind,
      styleSignature: buildReferenceStyleSignature(block),
      rect: block.rect,
      text: block.text || null,
      normalizedText: normalized || null,
      lineCount: block.lineCount || null,
      anchorHash,
    };
  });

  const anchors = blocks
    .filter((block) => block.anchorHash != null)
    .map((block) => ({
      anchorHash: block.anchorHash,
      chapterIndex: block.chapterIndex,
      pageIndex: block.pageIndex,
      order: block.order,
      nodeType: block.nodeType,
      text: block.text ?? '',
      normalizedText: block.normalizedText,
      styleSignature: block.styleSignature,
      rect: block.rect,
      lineCount: block.lineCount ?? 0,
    }));

  return {
    chapterIndex: rawPage.chapterIndex,
    pageIndex: rawPage.pageIndex,
    screenshotPath,
    normalizedText: normalizeText(blocks.map((block) => block.normalizedText ?? '').join(' ')),
    blocks,
    anchors,
    href: rawPage.href,
    locationKey: rawPage.locationKey,
  };
}

function buildReferenceStyleSignature(block) {
  const parts = [
    `node=${block.nodeType}`,
    `kind=${block.kind}`,
  ];
  if (block.fontSize != null) {
    parts.push(`size=${Number(block.fontSize).toFixed(2)}`);
  }
  parts.push(`weight=${block.fontWeight ?? 400}`);
  parts.push(`italic=${Boolean(block.italic)}`);
  parts.push(`underline=${Boolean(block.underline)}`);
  parts.push(`strike=${Boolean(block.strike)}`);
  if (block.colorHex) {
    parts.push(`color=${block.colorHex}`);
  }
  if (block.backgroundHex) {
    parts.push(`bg=${block.backgroundHex}`);
  }
  parts.push(`lines=${block.lineCount ?? 0}`);
  return parts.join('|');
}
