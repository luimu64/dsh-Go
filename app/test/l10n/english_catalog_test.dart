// The English catalog must read as English. Two kinds of leftovers used to
// slip through: a Chinese word inside a sentence ("Indent paragraphs in 小说")
// and Chinese corner brackets around a product name (「ST」). Both render on an
// English device, so they are user-visible bugs, not source comments.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _cjk = RegExp(r'[\u3400-\u9fff\uf900-\ufaff]');
final _chinesePunctuation = RegExp(r'[，。；：！？「」『』（）【】]');

void main() {
  test('English ARB parts contain no Chinese text or punctuation', () {
    final dir = Directory('lib/l10n/parts');
    expect(dir.existsSync(), isTrue, reason: 'run from app/');
    final offenders = <String>[];
    for (final file in dir.listSync().whereType<File>()) {
      final name = file.uri.pathSegments.last;
      if (!name.endsWith('_en.arb') || name.startsWith('companion_')) continue;
      final catalog = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      for (final entry in catalog.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key.startsWith('@') || value is! String) continue;
        // The language's own name is Chinese in every catalog.
        if (key == 'localeZh') continue;
        final text = value;
        if (_cjk.hasMatch(text) || _chinesePunctuation.hasMatch(text)) {
          offenders.add('$name:$key = $text');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
