import 'package:dsh_app/l10n/l10n.dart';
import 'package:dsh_app/share_code/plugin_share.dart';
import 'package:dsh_app/state/engine_settings_state.dart';
import 'package:dsh_client/dsh_client.dart';
import 'package:flutter_test/flutter_test.dart';

import '../plugins/support/fake_plugin_host.dart' show bundleJson;

void main() {
  tearDown(() => AppLocale.use(AppLocale.zhCN));

  final bundle = PluginBundle.fromJson({
    'source': 'language-probe@1.0.0',
    ...bundleJson(
      'language-probe',
      title: {'zh': '语言探针', 'en': 'Language probe'},
      description: {'zh': '中文说明', 'en': 'English description'},
    ),
  });

  test('shared plugin cards capture the active display language', () {
    expect(sharedPluginFromBundle(bundle)!.title, '语言探针');
    AppLocale.use(AppLocale.en);
    final shared = sharedPluginFromBundle(bundle)!;
    expect(shared.title, 'Language probe');
    expect(shared.summary, 'English description');
    AppLocale.use(AppLocale.zhCN);
    expect(sharedPluginFromBundle(bundle)!.title, '语言探针');
    expect(shared.title, 'Language probe', reason: 'an exported artifact is a snapshot');
  });

  test('engine inventory resolves titles, descriptions and bundle sources globally', () {
    final inventory = PluginInventory.fromJson({
      'managementAvailable': true,
      'entries': [
        {
          'entryId': 'include:language-probe',
          'moduleName': 'language-probe',
          'enabled': true,
          'meta': {
            'title': {'zh': '探针设置', 'en': 'Probe settings'},
            'description': {'zh': '探针说明', 'en': 'Probe description'},
          },
        },
      ],
      'presets': [],
    });
    var item = inventoryItems(inventory, [bundle]).global.single;
    expect(item.title, '探针设置');
    expect(item.description, '探针说明');
    expect(item.source, '语言探针');
    AppLocale.use(AppLocale.en);
    item = inventoryItems(inventory, [bundle]).global.single;
    expect(item.title, 'Probe settings');
    expect(item.description, 'Probe description');
    expect(item.source, 'Language probe');
  });
}
