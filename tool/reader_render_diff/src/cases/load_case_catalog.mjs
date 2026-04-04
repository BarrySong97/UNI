import fs from 'node:fs/promises';

export async function loadCaseCatalog(caseCatalogPath) {
  const json = JSON.parse(await fs.readFile(caseCatalogPath, 'utf8'));
  const entries = Array.isArray(json.entries) ? json.entries : [];
  const byId = Object.fromEntries(entries.map((entry) => [entry.caseId, entry]));
  return {
    entries,
    byId,
  };
}
