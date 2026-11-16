import assert from 'node:assert/strict';
import test from 'node:test';
import { createRecallContexts } from '../bridge/dsh-go-bridge/lib/companion/recall-context.js';
import { apply as applyFullContext } from '../bridge/dsh-go-bridge/lib/companion/full-context.js';

test('a late old disposer cannot remove a successor in the same actual scope', () => {
  const registry = createRecallContexts(), scope = {}, systemPrompt = {};
  const ctx = { fiber: { state: 2, uid: 1 }, get: () => systemPrompt };
  const current = (owner = systemPrompt) => registry.current([scope], () => scope, owner, (value) => value);
  const oldDispose = registry.registerContext(ctx), old = current();
  assert(old);
  oldDispose();
  const newDispose = registry.registerContext(ctx), next = current();
  assert(next && next !== old);
  oldDispose();
  assert.equal(current(), next);
  assert.equal(current({}), undefined, 'a different actual prompt service is not this mount');
  newDispose();
  assert.equal(current(), undefined);
});

test('registry retirement and a non-live fiber cannot authorize another mount', () => {
  const registry = createRecallContexts(), scope = {}, owner = {};
  const ctx = { fiber: { state: 1, uid: 7 }, get: () => owner };
  registry.registerContext(ctx);
  const current = () => registry.current([scope], () => scope, owner, (value) => value);
  assert.equal(current(), undefined);
  ctx.fiber.state = 2;
  assert(current());
  registry.dispose();
  registry.registerContext(ctx);
  assert.equal(current(), undefined);
});

test('the existing full context still mounts without an available recall service', () => {
  const sections = [], contexts = [];
  applyFullContext({
    get: () => undefined,
    systemPrompt: {
      section: (value) => sections.push(value), context: (value) => contexts.push(value),
      getSectionOrder: () => 100, getContextOrder: () => 100,
    },
  });
  assert.deepEqual(sections.map(section => section.name), [
    'deployment:persona-prefix', 'deployment:persona-suffix', 'app:web-surface',
  ]);
  const textOf = (section) => typeof section.text === 'function' ? section.text() : section.text;
  assert(textOf(sections[0]).includes('鲸鱼女孩'));
  assert(textOf(sections[1]).includes('应用固定规则'));
  assert.equal(contexts.length, 1);
  assert.equal(contexts[0].name, 'app:web-surface');
});

test('an English profile makes every app-owned section English', () => {
  const sections = [];
  const profile = { persona: '', name: '', callMe: '', moves: '', language: 'en' };
  applyFullContext({
    get: (name) => name === 'dshGoCompanionContext' ? { profile: () => profile } : undefined,
    systemPrompt: {
      section: (value) => sections.push(value), context: () => {},
      getSectionOrder: () => 100, getContextOrder: () => 100,
    },
  });
  const agent = {};
  const persona = sections[0].text({ agent });
  const rules = sections[1].text({ agent });
  const surface = sections[2].text({ agent });
  assert(persona.startsWith('You are Whale Girl'));
  assert(!persona.includes('鲸鱼娘'));
  assert(rules.includes('fixed rules'));
  assert(rules.includes('[emotion:happy]'));
  assert(surface.includes('companion room in the dsh-go phone app'));
  assert(!surface.includes('伙伴小屋'));
});
