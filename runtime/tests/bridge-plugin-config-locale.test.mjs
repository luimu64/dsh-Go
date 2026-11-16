// Plugin-config display text follows each request's language: Chinese stays the
// default, English is selected explicitly, and one host can serve both at once.
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { pluginConfigLocale, pluginConfigMessage, pluginConfigUnavailable } from '../bridge/dsh-go-bridge/lib/plugin-config.js';

const BASE = '/dsh-go/v1/plugin-config';
const zh = { conflict: '配置已发生变化，请刷新后重试。', host: '主机配置服务暂不可用，请稍后重试。' };

test('Chinese stays the default for an unstated or non-English request', () => {
  assert.equal(pluginConfigLocale({ url: BASE }), 'zh');
  assert.equal(pluginConfigLocale({ url: BASE + '?locale=fr-FR' }), 'zh');
  assert.equal(pluginConfigLocale({ url: BASE, headers: { 'accept-language': 'fr-FR,fr;q=0.9' } }), 'zh');
  assert.equal(pluginConfigMessage('conflict', 'zh'), zh.conflict);
  assert.equal(pluginConfigMessage('conflict', undefined), zh.conflict);
});

test('an explicit locale query selects English, with Accept-Language as fallback', () => {
  assert.equal(pluginConfigLocale({ url: BASE + '?locale=en' }), 'en');
  assert.equal(pluginConfigLocale({ url: BASE + '?locale=en-US' }), 'en');
  assert.equal(pluginConfigLocale({ url: BASE, headers: { 'accept-language': 'en-US,en;q=0.9' } }), 'en');
  assert.match(pluginConfigMessage('conflict', 'en'), /configuration changed/i);
  assert.match(pluginConfigMessage('recovery-failed', 'en'), /restored state could not be confirmed/i);
});

test('the explicit query wins over the header and over the Chinese default', () => {
  assert.equal(pluginConfigLocale({ url: BASE + '?locale=zh-CN', headers: { 'accept-language': 'en-US' } }), 'zh');
  assert.equal(pluginConfigLocale({ url: BASE + '?locale=en', headers: { 'accept-language': 'zh-CN' } }), 'en');
  // A malformed explicit tag falls through to the header rather than choosing English by accident.
  assert.equal(pluginConfigLocale({ url: BASE + '?locale=not a tag', headers: { 'accept-language': 'en' } }), 'en');
});

test('the unavailable response follows the same request language', () => {
  assert.equal(pluginConfigUnavailable({ url: BASE }).error.message, zh.host);
  assert.match(pluginConfigUnavailable({ url: BASE + '?locale=en' }).error.message, /configuration service is unavailable/i);
  assert.equal(pluginConfigUnavailable({ url: BASE + '-other' }), undefined);
});

test('concurrent requests on one shared host never share a language', async () => {
  const requests = Array.from({ length: 40 }, (_, i) => ({
    url: `${BASE}?locale=${i % 2 === 0 ? 'en-US' : 'zh-CN'}`,
    headers: { 'accept-language': i % 2 === 0 ? 'zh-CN' : 'en-US' },
  }));
  const seen = await Promise.all(requests.map(async (req, i) => {
    await new Promise((resolve) => setImmediate(resolve));
    return { i, locale: pluginConfigLocale(req), message: pluginConfigMessage('conflict', pluginConfigLocale(req)) };
  }));
  for (const { i, locale, message } of seen) {
    assert.equal(locale, i % 2 === 0 ? 'en' : 'zh', `request ${i}`);
    if (i % 2 === 0) assert.match(message, /configuration changed/i);
    else assert.equal(message, zh.conflict);
  }
  // Interleaving afterwards still starts from the request, never from the last one.
  assert.equal(pluginConfigMessage('conflict', pluginConfigLocale({ url: BASE })), zh.conflict);
});
