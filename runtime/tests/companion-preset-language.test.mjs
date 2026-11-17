import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { resolve } from 'node:path';
import { runInNewContext } from 'node:vm';

const prefix = process.env.DSH_PREFIX || process.env.DSH_TEST_PREFIX;

test('companion presets keep literal labels and resolve their instructions in the launch language',
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
    }
    // A preset row is a loader entry group, and the loader never evaluates `!!js` in a
    // group's own config: it keeps expressions for the child plugins. An expression in
    // `name` therefore reaches the preset schema as an object, the row fails
    // "expected string" and the whole preset silently drops out of the roster. Labels
    // stay literal; the app supplies the English copy by preset id.
    for (const config of [legacy, full]) {
      for (const field of ['id', 'name', 'description']) {
        assert.equal(typeof config[field], 'string',
          `${config.id}: ${field} must be a literal, group config is not interpolated`);
      }
      assert.equal(typeof config.order, 'number', `${config.id}: order must be a literal`);
    }
    assert.equal(legacy.name, '伙伴');
    assert.equal(legacy.description, '伙伴小屋的对话：只有角色人设，没有工具。');
    assert.equal(full.name, '伙伴·完整');
    assert.equal(full.description, '保留伙伴人设，使用当前主机的标准工具与已连接的手机工具。');
  });
