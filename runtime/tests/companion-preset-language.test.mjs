import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { resolve } from 'node:path';
import { runInNewContext } from 'node:vm';

const prefix = process.env.DSH_PREFIX || process.env.DSH_TEST_PREFIX;

test('legacy companion preset resolves its complete instructions and labels in the launch language',
  { skip: !prefix && 'requires the runtime YAML parser in DSH_PREFIX' }, () => {
    const require = createRequire(resolve(prefix, 'package.json'));
    const { parse } = require('yaml');
    const source = readFileSync(new URL('../bridge/dsh-go-bridge/cordis.patch.yml', import.meta.url), 'utf8');
    const rows = parse(source, { customTags: [{
      tag: 'tag:yaml.org,2002:js',
      resolve: expression => ({ expression }),
    }] })[0].insert;
    const legacy = rows.find(row => row.id === 'preset-dsh-go-companion').config;
    const full = rows.find(row => row.id === 'preset-dsh-go-companion-full').config;
    const expression = legacy.plugins.find(row => row.id === 'persona').config.prefix;
    const evaluate = (node, language) => runInNewContext(node.expression, {
      process: { env: { DSH_APP_LANGUAGE: language } },
    });
    const english = evaluate(expression, 'en-US');
    assert.match(english, /^You are Whale Girl/);
    assert.match(english, /currently have no tools/);
    assert.match(english, /self-harm or suicide/);
    assert.match(english, /\[emotion:happy\]/);
    assert.match(english, /\[action:nod\]/);
    assert.doesNotMatch(english, /[\u3400-\u9fff]/u);
    for (const language of ['zh-CN', 'zh', '']) {
      const chinese = evaluate(expression, language);
      assert.match(chinese, /^你是鲸鱼娘/);
      assert.match(chinese, /你现在没有工具/);
      assert.match(chinese, /\[表情:开心\]/);
      assert.match(chinese, /自伤、自杀/);
      assert.equal(evaluate(legacy.name, language), '伙伴');
      assert.equal(evaluate(full.name, language), '伙伴·完整');
    }
    assert.equal(evaluate(legacy.name, 'en'), 'Companion');
    assert.equal(evaluate(full.name, 'en'), 'Companion · Full');
    assert.match(evaluate(legacy.description, 'en'), /without tools/);
    assert.match(evaluate(full.description, 'en'), /connected phone tools/);
  });
