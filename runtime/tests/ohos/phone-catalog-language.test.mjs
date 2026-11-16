import test from 'node:test';
import assert from 'node:assert/strict';
import { phoneCatalog, phoneCatalogIn, phoneLanguage } from '../../ohos/phone/catalog.mjs';

test('the HarmonyOS catalog keeps one schema and ships Chinese and English wording', () => {
  assert.deepEqual(phoneCatalog, phoneCatalogIn('zh'));
  const zh = phoneCatalogIn('zh'), en = phoneCatalogIn('en');
  assert.deepEqual(en.map((tool) => tool.name), zh.map((tool) => tool.name));
  for (let i = 0; i < zh.length; i++) {
    assert.deepEqual(Object.keys(en[i].parameters.properties), Object.keys(zh[i].parameters.properties));
    assert.deepEqual(en[i].parameters.required, zh[i].parameters.required);
    assert.notEqual(en[i].description, zh[i].description);
    assert.doesNotMatch(en[i].description, /[\u3400-\u9fff]/);
    for (const [key, property] of Object.entries(en[i].parameters.properties)) {
      assert.equal(property.type, zh[i].parameters.properties[key].type, `${en[i].name}.${key} type`);
      assert.doesNotMatch(property.description ?? '', /[\u3400-\u9fff]/, `${en[i].name}.${key}`);
    }
  }
  assert.match(en[0].description, /HarmonyOS/);
  assert.match(en[4].description, /harmony|HarmonyOS|Continue/);
});

test('the HarmonyOS language comes from DSH_APP_LANGUAGE and defaults to Chinese', () => {
  assert.equal(phoneLanguage({ DSH_APP_LANGUAGE: 'en-US' }), 'en');
  assert.equal(phoneLanguage({ DSH_APP_LANGUAGE: 'zh-CN' }), 'zh');
  assert.equal(phoneLanguage({}), 'zh');
});
