import test from 'node:test';
import assert from 'node:assert/strict';
import { Readable } from 'node:stream';
import { createRequire, registerHooks } from 'node:module';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

// The Host's packages live in the runtime prefix, not in this checkout, and the
// device modules below import them by bare name the way the engine runs them.
const runtimePrefix = process.env.DSH_PREFIX || process.env.DSH_TEST_PREFIX || process.env.OHOS_TEST_PROCESS_PREFIX;
assert.ok(runtimePrefix, 'Set DSH_PREFIX to a patched runtime prefix');
const requirePrefix = createRequire(join(resolve(runtimePrefix), 'package.json'));

registerHooks({
  resolve(specifier, context, next) {
    if (!specifier.startsWith('@deepseek-ai/')) return next(specifier, context);
    try {
      return next(specifier, context);
    } catch {
      return { url: pathToFileURL(requirePrefix.resolve(specifier)).href, shortCircuit: true };
    }
  },
});

const load = name => import(pathToFileURL(requirePrefix.resolve(name)));

const { Context } = await load('@deepseek-ai/cordis');
const { SystemPrompt } = await load('@deepseek-ai/dsh-system-prompt');
const { ToolRuntime } = await load('@deepseek-ai/dsh-tools');
const { NativeToolExecutor } = await load('@deepseek-ai/dsh-tool-executor-native');
const { createMcpToolDefinition } = await load('@deepseek-ai/dsh-mcp-client');
const {
  appLanguageHub, createAppLanguageRoute, normalizeAppLanguage,
} = await import('../bridge/dsh-go-bridge/lib/app-language.js');
const { phoneCatalogIn } = await import('../ohos/phone/catalog.mjs');
const { registerPhoneTools } = await import('../ohos/phone/tools.mjs');
const { iosToolDescription } = await import('../ios/phone/descriptions.mjs');
const { followAppLanguage, appLanguageHub: iosLanguageHub } = await import('../ios/phone/language.mjs');

const hub = appLanguageHub();
const CJK = /[\u3400-\u9fff]/;
const okResult = { status: 'succeeded', effect: 'notification_published', evidence: 'user_confirmed',
  dispatched: true, code: 'ok', message: 'posted' };

function readBody(req, limit = 4096) {
  return new Promise((resolve, reject) => {
    const chunks = []; let size = 0;
    req.on('data', (chunk) => { size += chunk.length; if (size > limit) reject(Object.assign(new Error('too large'), { status: 413 })); else chunks.push(chunk); });
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

function routeRequest(body, { method = 'POST', type = 'application/json' } = {}) {
  const req = Readable.from([Buffer.from(body)]);
  req.method = method; req.headers = { 'content-type': type };
  return req;
}

let response;
function send(_res, status, body) { response = { status, body }; }

test('the language rule matches the native prefix rule', () => {
  for (const value of ['en', 'EN-gb', 'en-US']) assert.equal(normalizeAppLanguage(value), 'en');
  for (const value of ['zh', 'zh-CN', '', undefined, 'fr-FR']) assert.equal(normalizeAppLanguage(value), 'zh');
  // The iOS phone tree ships without the bridge, so both sides meet on one Symbol.
  assert.equal(iosLanguageHub(), hub);
});

test('the bridge route changes only this process language and rejects other shapes', async () => {
  hub.set('zh');
  const route = createAppLanguageRoute({ readBody, send });
  const req = routeRequest(JSON.stringify({ language: 'en' }));
  assert.equal(await route.handle(req, {}, '/dsh-go/v1/app-language'), true);
  assert.deepEqual(response, { status: 200, body: { v: 1, language: 'en' } });
  assert.equal(hub.language, 'en');
  assert.equal(process.env.DSH_APP_LANGUAGE, 'en');

  const bad = [
    routeRequest(JSON.stringify({ language: 'fr' })),
    routeRequest(JSON.stringify({ language: 'en', extra: true })),
    routeRequest('not json'),
    routeRequest(JSON.stringify({ language: 'zh' }), { type: 'text/plain' }),
    routeRequest(JSON.stringify({ language: 'zh' }), { method: 'GET' }),
  ];
  const expected = [400, 400, 400, 415, 405];
  for (let index = 0; index < bad.length; index++) {
    assert.equal(await route.handle(bad[index], {}, '/dsh-go/v1/app-language'), true);
    assert.equal(response.status, expected[index]);
  }
  assert.equal(hub.language, 'en');
  hub.set('zh');
});

function stripDescription(value) {
  return JSON.parse(JSON.stringify(value, (key, item) => key === 'description' ? undefined : item));
}

function queueFixture() {
  const pending = [];
  return {
    pending,
    canRun: () => true,
    enqueue(request) {
      return new Promise((resolve) => pending.push({ request, resolve }));
    },
    settle(result) {
      assert.ok(pending.length > 0, 'a tool is waiting on the native queue');
      pending.shift().resolve(result);
    },
  };
}

async function registryFixture(t) {
  const queue = queueFixture();
  const ctx = new Context();
  await ctx.plugin(SystemPrompt, {});
  await ctx.plugin(ToolRuntime, {});
  ctx.tools.setExecutor(new NativeToolExecutor(ctx));
  const dispose = registerPhoneTools(ctx, queue);
  t.after(async () => { dispose(); await ctx.fiber.dispose(); });
  let calls = 0;
  return {
    ctx, queue,
    run: async (name, args, signal = new AbortController().signal) => (await ctx.tools.execute({
      calls: [{ id: `language-call-${++calls}`, name: `mcp__phone__${name}`, arguments: JSON.stringify(args) }],
      agent: { id: 'language-session', ctx }, signal,
    })).results[0].result,
  };
}

test('a live switch rewrites HarmonyOS descriptions but keeps ids, schemas and running calls', async (t) => {
  hub.set('zh');
  const f = await registryFixture(t);
  const names = phoneCatalogIn('zh').map((tool) => tool.name);
  assert.deepEqual(f.ctx.tools.definitions().map((tool) => tool.name), names);
  const open = f.ctx.tools.get('mcp__phone__open');
  const zhDescription = open.description;
  assert.match(zhDescription, CJK);
  const shapes = stripDescription(f.ctx.tools.definitions());

  // Start a call, then switch language while it is still waiting for the phone.
  const running = f.run('notify', { title: 'Build', text: 'Ready' });
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(f.queue.pending.length, 1);
  const identity = f.ctx.tools.get('mcp__phone__open');

  hub.set('en');
  assert.equal(f.ctx.tools.get('mcp__phone__open'), identity, 'the registered definition object is not replaced');
  for (const tool of f.ctx.tools.definitions()) {
    assert.doesNotMatch(tool.description, CJK, tool.name);
    assert.doesNotMatch(JSON.stringify(tool.parameters), CJK, tool.name);
  }
  const visible = f.ctx.tools.schemas();
  for (const tool of visible) {
    assert.doesNotMatch(tool.description, CJK, tool.name);
    assert.doesNotMatch(JSON.stringify(tool.parameters), CJK, tool.name);
  }
  assert.match(f.ctx.tools.get('mcp__phone__open').description, /HarmonyOS/);
  assert.deepEqual(stripDescription(f.ctx.tools.definitions()), shapes, 'tool ids and schemas stay identical');
  assert.deepEqual(f.ctx.tools.schemas().map((tool) => tool.name), names);

  f.queue.settle(okResult);
  const result = await running;
  assert.equal(result.isError, false, JSON.stringify(result));

  hub.set('zh');
  for (const tool of f.ctx.tools.definitions()) assert.match(tool.description, CJK, tool.name);
  assert.equal(f.ctx.tools.get('mcp__phone__open').description, zhDescription);
});

test('the iOS descriptions follow the hub on an already-registered definition', (t) => {
  hub.set('zh');
  const definition = createMcpToolDefinition({}, {
    name: 'mcp__phone__open', rawName: 'open', description: iosToolDescription('open', 'zh'),
    inputSchema: { type: 'object', properties: {}, additionalProperties: false },
    call: async () => ({ content: [] }),
  });
  const entries = [{ name: 'open', definition }];
  const stop = followAppLanguage(entries, iosToolDescription);
  t.after(stop);
  hub.set('en');
  assert.doesNotMatch(definition.description, CJK);
  assert.match(definition.description, /iOS/);
  hub.set('zh');
  assert.match(definition.description, CJK);
  assert.equal(definition.name, 'mcp__phone__open');
  assert.deepEqual(definition.parameters, { type: 'object', properties: {}, additionalProperties: false });
});
