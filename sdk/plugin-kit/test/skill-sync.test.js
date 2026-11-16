import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { render, SKILL_DIR } from '../scripts/sync-skill.mjs';

test('the bundled plugin skill ships a Chinese default and an English variant', () => {
  const files = render();
  const manifest = JSON.parse(files['manifest.json']);
  assert.equal(manifest.name, 'dsh-go-plugin');
  assert.deepEqual(manifest.locales, { en: { 'en-SKILL.md': 'SKILL.md' } });
  assert.match(files['SKILL.md'], /^---\n/);
  assert.match(files['en-SKILL.md'], /^---\n/);
  assert.match(files['en-SKILL.md'], /name: dsh-go-plugin\n/);
  assert.notEqual(files['SKILL.md'], files['en-SKILL.md']);
  // Every asset the manifest maps must be generated, and the checked-in copy matches.
  for (const [name, target] of Object.entries({ ...manifest.files, ...manifest.locales.en })) {
    assert.equal(typeof files[name], 'string', name);
    assert.equal(readFileSync(join(SKILL_DIR, name), 'utf8'), files[name], `${name} (${target})`);
  }
});
