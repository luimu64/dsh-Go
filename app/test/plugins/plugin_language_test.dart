// Plugin content follows 设置 → 语言: manifests, bundle metadata, market
// entries and the bridge's slot labels are language maps, and the app decides
// which language they are read in. The UI text language (AppLocale, or a
// Localizations override) wins; Chinese stays Chinese for a Chinese UI.

import 'dart:convert';

import 'package:dsh_app/l10n/l10n.dart';
import 'package:dsh_app/plugins/native/native_state.dart';
import 'package:dsh_app/plugins/plugin_text.dart';
import 'package:dsh_app/plugins/seams/seams.dart';
import 'package:dsh_app/state/locale_state.dart';
import 'package:dsh_app/state/plugins_state.dart';
import 'package:dsh_app/ui/plugins/plugin_detail_sheet.dart';
import 'package:dsh_app/ui/plugins/plugins_screen.dart';
import 'package:dsh_client/dsh_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../chat/support/harness.dart';
import 'native/support.dart' show FakeBridge, contributions;
import 'support/fake_plugin_host.dart';

void main() {
  setUpAll(loadTestFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => AppLocale.use(AppLocale.zhCN));

  testWidgets('pluginTextLocaleProvider follows the language setting', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(pluginTextLocaleProvider), 'zh');
    await container.read(appLanguageProvider.notifier).set(AppLanguage.en);
    expect(container.read(pluginTextLocaleProvider), 'en');
    await container.read(appLanguageProvider.notifier).set(AppLanguage.zh);
    expect(container.read(pluginTextLocaleProvider), 'zh');
  });

  test('a cached market entry reads its own languages', () {
    final index = parseMarketIndex({
      'format': 1,
      'title': {'zh': '目录', 'en': 'Directory'},
      'plugins': [
        {
          'name': 'localized-plugin',
          'title': {'zh': '本地化插件', 'en': 'Localized plugin'},
          'description': {'zh': '中文说明', 'en': 'English summary'},
          'versions': [
            {
              'version': '1.0.0',
              'publishTimestamp': 1789469760,
              'source': {'type': 'npm'},
            },
          ],
        },
      ],
    }, Uri.parse(dshfindIndexUrl));
    final entry = MarketCatalog(index).byName['localized-plugin']!;
    expect(entry.title(), '本地化插件');
    expect(entry.summary(), '中文说明');
    AppLocale.use(AppLocale.en);
    expect(entry.title(), 'Localized plugin');
    expect(entry.summary(), 'English summary');
  });

  test('slot labels are resolved in the language the inventory is built in', () {
    final inventory = ClientInventory(
      slots: {
        Slots.settingsSection: [
          ClientSlotOccupant(
            slot: Slots.settingsSection,
            package: 'probe',
            cell: 'probe',
            label: LocalizedText.fromJson({'zh': '探针设置', 'en': 'Probe settings'}),
          ),
        ],
      },
    );
    SeatInventory seats(String locale) => SeatInventory.from(inventory, locale: locale);
    expect(seats('zh').occupantsFor(Slots.settingsSection).single.label, '探针设置');
    expect(seats('en').occupantsFor(Slots.settingsSection).single.label, 'Probe settings');
  });

  testWidgets('installed rows show the bundle text in the language on screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final carrier = FakePluginCarrier()
      ..handlers['pluginManager/listBundles'] = (_) => [
        bundleJson(
          'memo-box',
          title: {'zh': '记忆盒', 'en': 'Memory Box'},
          description: {'zh': '保存有用的片段', 'en': 'Keep useful snippets'},
        ),
      ];
    final client = DshClient.withCarrier(carrier);
    addTearDown(client.close);
    final bridge = FakeBridge(contributions([]));
    usePhoneView(tester);

    Future<void> pump(Locale locale) async {
      AppLocale.use(locale);
      await tester.pumpWidget(
        testApp(
          const PluginsScreen(),
          overrides: [...pluginOverrides(fakeHost(client)), nativeBridgeProvider.overrideWithValue(bridge)],
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    await pump(AppLocale.zhCN);
    expect(find.text('记忆盒'), findsOneWidget);
    expect(find.textContaining('保存有用的片段'), findsOneWidget);

    final container = ProviderScope.containerOf(tester.element(find.byType(PluginsScreen)));
    await container.read(appLanguageProvider.notifier).set(AppLanguage.en);
    await tester.pumpAndSettle();
    expect(find.text('Memory Box'), findsOneWidget);
    expect(find.textContaining('Keep useful snippets'), findsOneWidget);
    expect(find.textContaining('保存有用的片段'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a market card and its sheet follow a Localizations override', (tester) async {
    final carrier = FakePluginCarrier()..handlers['pluginManager/listBundles'] = (_) => sampleBundles;
    final client = DshClient.withCarrier(carrier);
    addTearDown(client.close);
    usePhoneView(tester);
    final localizedIndex = jsonDecode(jsonEncode(sampleIndex)) as Map<String, Object?>;
    final entry = MarketCatalog(parseMarketIndex(localizedIndex, Uri.parse(dshfindIndexUrl))).byName['novel-writer']!;
    await tester.pumpWidget(
      testApp(
        Builder(
          builder: (context) => Localizations.override(
            context: context,
            locale: AppLocale.en,
            child: Scaffold(body: MarketPluginSheet(entry: entry)),
          ),
        ),
        overrides: pluginOverrides(fakeHost(client)),
      ),
    );
    await tester.pumpAndSettle();
    // A plain (untranslated) title stays as written; its Chinese description
    // is the only text there is and is not replaced by an empty English one.
    expect(find.text('novel-writer'), findsWidgets);
    expect(find.textContaining('小说创作模式'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
