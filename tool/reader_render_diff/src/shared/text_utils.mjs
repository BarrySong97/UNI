export function normalizeText(text) {
  return String(text ?? '')
    .replaceAll('\u00A0', ' ')
    .replaceAll('\u200B', '')
    .replaceAll('\r\n', '\n')
    .replaceAll('\r', '\n')
    .replace(/\s+/g, ' ')
    .trim();
}

export function canonicalizeText(text) {
  return normalizeText(text)
    .replace(/[^\p{Letter}\p{Number}]+/gu, '')
    .toLowerCase();
}

export function stableHash(input) {
  let hash = 0x811c9dc5;
  for (let index = 0; index < input.length; index += 1) {
    hash ^= input.charCodeAt(index);
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  return hash.toString(16).padStart(8, '0');
}

export function alphaNumericCount(text) {
  const normalized = normalizeText(text);
  return [...normalized].filter((char) => /[\p{Letter}\p{Number}]/u.test(char)).length;
}

export function wordCount(text) {
  const normalized = normalizeText(text);
  if (normalized === '') {
    return 0;
  }
  return normalized.split(/\s+/).filter(Boolean).length;
}

export function computeTextSignalScore(text) {
  const normalized = normalizeText(text);
  const canonical = canonicalizeText(normalized);
  if (canonical === '') {
    return 0;
  }
  return Math.min(100, Math.max(wordCount(normalized) * 12, canonical.length));
}

export function isTextMatchEligible(text) {
  const normalized = normalizeText(text);
  if (normalized === '') {
    return false;
  }
  return wordCount(normalized) >= 2 || alphaNumericCount(normalized) >= 12;
}

export function buildImageSignature({ alt, width, height }) {
  const normalizedAlt = canonicalizeText(alt ?? '');
  const safeWidth = Number.isFinite(width) ? Math.trunc(width) : 0;
  const safeHeight = Number.isFinite(height) ? Math.trunc(height) : 0;
  if (normalizedAlt === '' && safeWidth <= 0 && safeHeight <= 0) {
    return null;
  }
  return `${normalizedAlt}|${safeWidth}x${safeHeight}`;
}

export function excerptText(text, maxLength = 180) {
  const normalized = normalizeText(text);
  if (normalized.length <= maxLength) {
    return normalized;
  }
  return `${normalized.slice(0, Math.max(0, maxLength - 3))}...`;
}

export function uniqueSorted(values) {
  return [...new Set(values.filter(Boolean))].sort();
}
