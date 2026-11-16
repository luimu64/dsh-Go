import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { iosToolDescription, phoneLanguage } from '../ios/phone/descriptions.mjs';

test('every shared phone schema has explicit iOS instructions', () => {
  const catalog = JSON.parse(readFileSync(new URL('../ios/phone/catalog.json', import.meta.url)));
  for (const tool of catalog) assert.match(iosToolDescription(tool.name), /iOS/);
  assert.throws(() => iosToolDescription('future-android-tool'), /Missing iOS description/);
});

test('iOS instructions distinguish OCR, unavailable input and native approvals', () => {
  assert.match(iosToolDescription('screen'), /OCR.*不是可交互元素树/);
  assert.match(iosToolDescription('screen'), /没有 background:true/);
  assert.match(iosToolDescription('tap'), /任务授权/);
  assert.match(iosToolDescription('screen'), /不再弹窗或拉回 DSH Go/);
  assert.match(iosToolDescription('tap'), /输入不可用.*增强已开启.*新的 XCTest 观察/);
  assert.match(iosToolDescription('tap'), /未开启时才请用户开启/);
  assert.match(iosToolDescription('collect'), /不是纯只读/);
  assert.match(iosToolDescription('intent'), /不支持 alarm、timer/);
  assert.match(iosToolDescription('handoff'), /恢复画中画.*不等于批准/);
});

test('English instructions ship for every tool and keep the same guarantees', () => {
  const catalog = JSON.parse(readFileSync(new URL('../ios/phone/catalog.json', import.meta.url)));
  for (const tool of catalog) {
    const text = iosToolDescription(tool.name, 'en');
    assert.match(text, /iOS/);
    assert.doesNotMatch(text, /[\u3400-\u9fff]/);
  }
  assert.match(iosToolDescription('screen', 'en'), /OCR/);
  assert.match(iosToolDescription('screen', 'en'), /untrusted data/);
  assert.match(iosToolDescription('tap', 'en'), /never reuse numbers across backends/);
  assert.match(iosToolDescription('intent', 'en'), /does not support alarm/i);
  assert.match(iosToolDescription('handoff', 'en'), /is not approval/);
  assert.throws(() => iosToolDescription('future-android-tool', 'en'), /Missing iOS description/);
});

test('the language comes from DSH_APP_LANGUAGE and defaults to Chinese', () => {
  assert.equal(phoneLanguage({ DSH_APP_LANGUAGE: 'en-US' }), 'en');
  assert.equal(phoneLanguage({ DSH_APP_LANGUAGE: 'en' }), 'en');
  assert.equal(phoneLanguage({ DSH_APP_LANGUAGE: 'zh-CN' }), 'zh');
  assert.equal(phoneLanguage({ DSH_APP_LANGUAGE: '' }), 'zh');
  assert.equal(phoneLanguage({}), 'zh');
});
