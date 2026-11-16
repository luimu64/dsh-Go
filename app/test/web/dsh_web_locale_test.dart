// Language belongs to this page, never the host's shared settings.
// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';
import 'dart:io';

import 'package:dsh_app/ui/web/dsh_web_locale.dart';
import 'package:dsh_app/ui/web/web_view_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import '../chat/support/harness.dart' show testApp;
import 'support/fake_webview.dart';

void main() {
  test('only Chinese maps to zh; every other language is en', () {
    expect(dshWebLocaleId(const Locale('zh')), 'zh');
    expect(dshWebLocaleId(const Locale('zh', 'TW')), 'zh');
    expect(dshWebLocaleId(const Locale('en', 'US')), 'en');
    expect(dshWebLocaleId(const Locale('ja')), 'en');
  });

  test('executed language scripts isolate pages without any storage or network writes', () async {
    final result = await Process.run('node', [
      '-e',
      r'''
const vm = require('node:vm');
const scripts = JSON.parse(process.argv[1]);
function page() {
  const events = [];
  const context = vm.createContext({
    CustomEvent: class { constructor(type, options) { this.type = type; this.detail = options.detail; } },
    dispatchEvent: event => events.push([event.type, event.detail]),
  });
  Object.defineProperty(context, 'localStorage', {get() { throw Error('shared persistence accessed'); }});
  Object.defineProperty(context, 'fetch', {get() { throw Error('host network accessed'); }});
  return {context, events};
}
const a = page(), b = page();
vm.runInContext(scripts.en, a.context);
vm.runInContext(scripts.zh, b.context);
const before = [a.context.__DSH_APP_LOCALE__, b.context.__DSH_APP_LOCALE__];
vm.runInContext(scripts.zh, a.context);
console.log(JSON.stringify({before, after: [a.context.__DSH_APP_LOCALE__, b.context.__DSH_APP_LOCALE__], a: a.events, b: b.events}));
''',
      jsonEncode({
        'en': dshWebLocaleBridgeScript(const Locale('en')),
        'zh': dshWebLocaleBridgeScript(const Locale('zh', 'TW')),
      }),
    ]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(jsonDecode('${result.stdout}'), {
      'before': ['en', 'zh'],
      'after': ['zh', 'zh'],
      'a': [
        ['dsh-go:locale', 'en'],
        ['dsh-go:locale', 'zh'],
      ],
      'b': [
        ['dsh-go:locale', 'zh'],
      ],
    });
  });

  testWidgets('replay after page load and live changes preserve the controller and navigation', (tester) async {
    final platform = FakeWebViewPlatform();
    WebViewPlatform.instance = platform;
    final url = Uri.parse('http://127.0.0.1:3080');
    Widget page(Locale locale) =>
        testApp(WebViewPage(url: url, dshWeb: true, title: 'DSH', startScript: dshWebLocaleBridgeScript(locale)));
    await tester.pumpWidget(page(const Locale('en')));
    final controller = platform.controller;
    for (var i = 0; i < 20 && controller.loads.isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    controller.start();
    controller.finish();
    await tester.pumpAndSettle();
    final en = dshWebLocaleBridgeScript(const Locale('en'));
    expect(controller.scripts.where((s) => s == en).length, 2);
    controller.history = 4;

    await tester.pumpWidget(page(const Locale('zh')));
    await tester.pumpAndSettle();
    expect(platform.controllers, hasLength(1));
    expect(controller.loads, [url]);
    expect(controller.reloads, 0);
    expect(controller.history, 4);
    expect(controller.scripts, contains(dshWebLocaleBridgeScript(const Locale('zh'))));
  });
}
