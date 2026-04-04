import { parseHTML } from 'linkedom';

/**
 * Parse an XHTML string into a walkable DOM Document.
 *
 * Uses linkedom which handles both HTML5 and XML-flavoured XHTML found in
 * EPUBs.  The returned Document supports standard DOM traversal
 * (querySelector, childNodes, etc.) without a full browser environment.
 */
export function parseXhtmlDom(xhtmlString) {
  const { document } = parseHTML(xhtmlString);
  return document;
}
