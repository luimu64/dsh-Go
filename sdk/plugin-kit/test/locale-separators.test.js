import { test } from 'node:test'
import assert from 'node:assert/strict'
import { localize } from '../lib/index.js'

for (const [name, text, locale, expected] of [
  ['underscore text keys', { zh_Hans_CN: '简体', zh_Hant_TW: '繁體' }, 'zh-Hant-TW', '繁體'],
  ['underscore request', { 'zh-Hans-CN': '简体', 'zh-Hant-TW': '繁體' }, 'zh_Hant_TW', '繁體'],
  ['mixed separators and case', { sr_Cyrl_RS: 'Cyrillic', 'sr_Latn-RS': 'Latin' }, 'SR-lAtN_rs', 'Latin'],
  ['several subtags', { en: 'Default', en_Latn_US_posix: 'Exact' }, 'en-Latn-US-posix', 'Exact'],
  ['single underscore', { en: 'Default', pt_BR: 'Brasil' }, 'pt-BR', 'Brasil'],
  ['language fallback', { zh: '中文', en: 'English' }, 'zh-HK', '中文'],
  ['English fallback', { zh: '中文', en: 'English' }, 'fr-FR', 'English'],
]) {
  test(`localize: ${name}`, () => {
    const before = JSON.stringify(text)
    assert.equal(localize(locale, text), expected)
    assert.equal(localize({ locale }, text), expected)
    assert.equal(JSON.stringify(text), before)
  })
}

test('localize: aliases follow the existing first matching key rule', () => {
  const text = { zh_Hant_TW: 'first', 'zh-Hant-TW': 'last' }
  assert.equal(localize('zh-Hant-TW', text), 'first')
})

test('localize: variants follow script and region, then key order', () => {
  const scripts = { 'zh-Hant': '繁體', 'zh-Hans': '简体' }
  assert.equal(localize('zh-TW', scripts), '繁體')
  assert.equal(localize('zh-HK', scripts), '繁體')
  assert.equal(localize('zh-CN', scripts), '简体')
  assert.equal(localize('zh-SG', scripts), '简体')
  assert.equal(localize('zh', scripts), '简体')
  const reversed = { 'zh-Hans': '简体', 'zh-Hant': '繁體' }
  assert.equal(localize('zh', reversed), localize('zh', scripts), 'key order does not change the pick')
  assert.equal(localize('en-US', { 'en-GB': 'Colour', 'en-US': 'Color' }), 'Color')
  assert.equal(localize('en-AU', { 'en-GB': 'Colour', 'en-US': 'Color' }), 'Colour')
  assert.equal(localize('fr', { 'en-GB': 'Colour' }), 'Colour', 'English variants are the fallback')
})
