import { mkdtempSync, readdirSync, readFileSync, rmSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { synth } from './synth';

function files(directory: string, prefix = ''): string[] {
  return readdirSync(path.join(directory, prefix), { withFileTypes: true })
    .flatMap((entry) => {
      const name = path.join(prefix, entry.name);
      return entry.isDirectory() ? files(directory, name) : [name];
    }).sort();
}

const expected = path.resolve(__dirname, '../../kubernetes/dist');
const temporary = mkdtempSync(path.join(os.tmpdir(), 'tenant-cdk8s-'));
try {
  synth(temporary);
  const generatedFiles = files(temporary);
  const committedFiles = files(expected);
  if (JSON.stringify(generatedFiles) !== JSON.stringify(committedFiles)) {
    throw new Error('Generated file list differs; run npm run synth and commit the results.');
  }
  for (const name of generatedFiles) {
    if (!readFileSync(path.join(temporary, name)).equals(readFileSync(path.join(expected, name)))) {
      throw new Error(`${name} is out of date; run npm run synth and commit the results.`);
    }
  }
  console.log(`All ${generatedFiles.length} generated manifests are up to date.`);
} finally {
  rmSync(temporary, { recursive: true, force: true });
}
