// The Dart constants are the authoring source; keep the host's instructions exact.
// The Chinese constant ships as contract.txt and the English one as
// contract.en.txt; app/assets/skills/companion-adapt/manifest.json maps the
// English file over references/contract.txt when the app is in English.
import { readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const source = await readFile(path.join(root, 'app/lib/companion/companion_adapt_contract.dart'), 'utf8');

function literal(name) {
  const marker = `const ${name} = '''\n`;
  const start = source.indexOf(marker);
  const end = start < 0 ? -1 : source.indexOf("''';", start + marker.length);
  if (start < 0 || end < 0) {
    throw new Error(`Expected one literal ${name}; update the extractor if the Dart syntax changes`);
  }
  const text = source.slice(start + marker.length, end);
  if (text.includes('$') || text.includes('\\')) {
    throw new Error(`Unexpected interpolation or escape in ${name}`);
  }
  return text;
}

const files = [
  ['contract.txt', literal('companionAdaptSystem')],
  ['contract.en.txt', literal('companionAdaptSystemEn')],
];
const directory = path.join(root, 'app/assets/skills/companion-adapt');

if (process.argv.includes('--check')) {
  for (const [name, text] of files) {
    if (await readFile(path.join(directory, name), 'utf8') !== text) throw new Error(`companion-adapt ${name} is stale`);
  }
  console.log('companion-adapt prompts match the Dart constants');
} else {
  for (const [name, text] of files) await writeFile(path.join(directory, name), text, 'utf8');
  console.log(`Updated ${files.map(([name]) => `companion-adapt/${name}`).join(' and ')}`);
}
