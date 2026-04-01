import fs from 'node:fs/promises';
import path from 'node:path';

export async function writeJsonReport(config, report) {
  const filePath = path.join(config.outDir, 'report.json');
  await fs.writeFile(filePath, JSON.stringify(report, null, 2));
  return filePath;
}
