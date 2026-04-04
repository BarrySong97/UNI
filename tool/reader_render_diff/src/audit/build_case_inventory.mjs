export function buildCaseInventory({
  caseCatalog,
  browserObjects,
  canvasObjects,
  missingConversions,
  ignoredCaseCounts = {},
}) {
  const browserCaseCounts = countByObservedCase(browserObjects);
  const canvasCaseCounts = countByObservedCase(canvasObjects);
  const missingCaseCounts = countByObservedCase(missingConversions, {
    observedSelector: (item) => [item.blockCaseId, ...(item.featureCaseIds ?? [])],
  });
  const exampleChapters = collectCaseChapters(browserObjects, canvasObjects, missingConversions);

  return caseCatalog.entries.map((entry) => {
    const browserCount = browserCaseCounts[entry.caseId] ?? 0;
    const canvasCount = canvasCaseCounts[entry.caseId] ?? 0;
    const missingCount = missingCaseCounts[entry.caseId] ?? 0;
    const ignoredCount = ignoredCaseCounts[entry.caseId] ?? 0;

    return {
      caseId: entry.caseId,
      layer: entry.layer,
      label: entry.label,
      status: entry.status,
      notes: entry.notes,
      observedInBrowser: browserCount > 0,
      convertedToNodes: canvasCount > 0,
      notObserved: browserCount === 0 && canvasCount === 0 && ignoredCount === 0,
      browserCount,
      canvasCount,
      missingCount,
      ignoredCount,
      exampleChapters: [...(exampleChapters.get(entry.caseId) ?? [])].sort((a, b) => a - b),
    };
  });
}

function countByObservedCase(items, { observedSelector } = {}) {
  const counts = {};
  for (const item of items ?? []) {
    const observed = observedSelector?.(item) ?? item.observedCaseIds ?? [];
    for (const caseId of observed) {
      counts[caseId] = (counts[caseId] ?? 0) + 1;
    }
  }
  return counts;
}

function collectCaseChapters(browserObjects, canvasObjects, missingConversions) {
  const byCase = new Map();

  for (const item of [...browserObjects, ...canvasObjects]) {
    for (const caseId of item.observedCaseIds ?? []) {
      const chapters = byCase.get(caseId) ?? new Set();
      chapters.add(item.chapterIndex);
      byCase.set(caseId, chapters);
    }
  }

  for (const item of missingConversions ?? []) {
    const observed = [item.blockCaseId, ...(item.featureCaseIds ?? [])];
    for (const caseId of observed) {
      const chapters = byCase.get(caseId) ?? new Set();
      chapters.add(item.chapterIndex);
      byCase.set(caseId, chapters);
    }
  }

  return byCase;
}
