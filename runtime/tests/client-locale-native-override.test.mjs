import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import vm from 'node:vm';

// The native app owns the UI language and injects it into the web client.
// These tests run the real patched bundle in a browser-shaped sandbox: the
// shared settings document must never be written by the override.
const runtimePrefix = process.env.DSH_PREFIX || process.env.DSH_TEST_PREFIX || process.env.OHOS_TEST_PROCESS_PREFIX;
assert.ok(runtimePrefix, 'Set DSH_PREFIX to an Android- or OHOS-patched runtime prefix');
const prefix = resolve(runtimePrefix);
const bundlePath = join(prefix, 'node_modules/@deepseek-ai/dsh-client-locale/lib/client.js');
const source = readFileSync(bundlePath, 'utf8');

const STUBS = {
  'react/jsx-runtime': { jsx() {}, jsxs() {}, Fragment: {} },
  react: { useState: () => [undefined, () => {}], useMemo: fn => fn(), createElement() {}, Fragment: {} },
  '@deepseek-ai/dsh-client-store': { defineStore: () => ({ sync() {}, subscribe() {} }) },
};

function sandbox({ browserLanguage = 'zh-CN' } = {}) {
  const events = new EventTarget();
  const context = {
    console,
    navigator: { languages: [browserLanguage], language: browserLanguage },
    addEventListener: events.addEventListener.bind(events),
    removeEventListener: events.removeEventListener.bind(events),
    dispatchEvent: events.dispatchEvent.bind(events),
  };
  context.window = context;
  context.__ModuleLoader__ = { load(value) { context.__module = value; } };
  vm.createContext(context);
  vm.runInContext(source, context, { filename: bundlePath });
  const module = context.__module.factory(id => STUBS[id] ?? new Proxy({}, { get: () => () => {} }));
  return { context, events, module };
}

function hostScope(preference) {
  return {
    value: { preference },
    writes: [],
    listeners: [],
    getSnapshot() { return { value: this.value }; },
    subscribe(fn) { this.listeners.push(fn); return () => {}; },
    set(key, value) { this.writes.push([key, value]); this.value = { ...this.value, [key]: value }; },
  };
}

function appContext(host) {
  assert.ok(host, 'host scope is required for the fixture');
  const effects = [];
  const subscribers = [];
  const state = { locale: undefined, effects };
  const ctx = {
    fiber: { uid: 'locale-fixture' },
    configForms: { get: () => host },
    effect(fn) { const dispose = fn(); effects.push(dispose); return () => dispose?.(); },
    provide(name, value) { if (name === 'locale') state.locale = value; },
    on() {},
    emit() {},
    subscribe(fn) { subscribers.push(fn); return () => {}; },
    slots: { installLocale() {}, inject(_name, create) { create(); }, register() { return () => {}; } },
  };
  return { ctx, state, subscribers };
}

function changeHost(host, preference) {
  host.value = { preference };
  for (const listener of [...host.listeners]) listener();
}

test('the native language set before apply wins over the host preference and browser', async () => {
  const { context, module } = sandbox({ browserLanguage: 'zh-CN' });
  const host = hostScope('zh');
  const { ctx, state } = appContext(host);
  context.__DSH_APP_LOCALE__ = 'en';
  await module.apply(ctx);

  assert.equal(state.locale.getSnapshot().active, 'en');
  assert.deepEqual(host.writes, []);
  assert.deepEqual(host.value, { preference: 'zh' }, 'the shared settings document is untouched');

  // A host adoption that resolves after the override must not win.
  changeHost(host, 'zh');
  assert.equal(state.locale.getSnapshot().active, 'en');
  assert.deepEqual(host.writes, []);

  // Live changes arrive as an event and republish without persisting.
  const seen = [];
  state.locale.subscribe(() => seen.push(state.locale.getSnapshot().active));
  context.dispatchEvent(new CustomEvent('dsh-go:locale', { detail: 'zh' }));
  assert.equal(state.locale.getSnapshot().active, 'zh');
  assert.deepEqual(seen, ['zh']);
  assert.deepEqual(host.writes, []);
});

test('a live event after apply switches the language and leaves the host alone', async () => {
  const { context, module } = sandbox({ browserLanguage: 'zh-CN' });
  const host = hostScope('zh');
  const { ctx, state } = appContext(host);
  await module.apply(ctx);
  assert.equal(state.locale.getSnapshot().active, 'zh');

  context.__DSH_APP_LOCALE__ = 'en';
  context.dispatchEvent(new CustomEvent('dsh-go:locale', { detail: 'en-US' }));
  assert.equal(state.locale.getSnapshot().active, 'en');

  context.dispatchEvent(new CustomEvent('dsh-go:locale', { detail: 'zh' }));
  assert.equal(state.locale.getSnapshot().active, 'zh');
  assert.deepEqual(host.writes, []);
  assert.deepEqual(host.value, { preference: 'zh' });
});

test('clients without a native override keep the upstream preference order', async () => {
  const { context, module } = sandbox({ browserLanguage: 'zh-CN' });
  const host = hostScope('en');
  const { ctx, state } = appContext(host);
  await module.apply(ctx);

  assert.equal(state.locale.getSnapshot().active, 'en');
  assert.deepEqual(host.writes, []);
  assert.deepEqual(host.value, { preference: 'en' });
});
