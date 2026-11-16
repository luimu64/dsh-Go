import 'package:dsh_app/l10n/l10n.dart';
import 'package:dsh_app/state/locale_state.dart';
import 'package:dsh_app/ui/settings/language_tile.dart';
import 'package:dsh_app/ui/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  tearDown(() => AppLocale.use(AppLocale.zhCN));

  group('AppLocale.resolve', () {
    test('a fixed choice wins over the system', () {
      expect(AppLocale.resolve(AppLocale.en, const [Locale('zh', 'CN')]), AppLocale.en);
      expect(AppLocale.resolve(AppLocale.zhCN, const [Locale('en', 'US')]), AppLocale.zhCN);
    });

    test('any Chinese system language is Chinese', () {
      for (final l in const [
        Locale('zh'),
        Locale('zh', 'TW'),
        Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      ]) {
        expect(AppLocale.resolve(null, [l]), AppLocale.zhCN, reason: '$l');
      }
    });

    test('the first Chinese or English system language decides; others are English', () {
      expect(AppLocale.resolve(null, const [Locale('ja'), Locale('zh')]), AppLocale.zhCN);
      expect(AppLocale.resolve(null, const [Locale('fr'), Locale('en')]), AppLocale.en);
      expect(AppLocale.resolve(null, const [Locale('ja')]), AppLocale.en);
      expect(AppLocale.resolve(null, const []), AppLocale.en);
      expect(AppLocale.resolve(null, null), AppLocale.en);
      expect(AppLocale.resolve(const Locale('fi'), const [Locale('zh')]), AppLocale.en);
    });
  });

  test('content listeners follow normalized locale changes exactly once', () {
    final seen = <Locale>[];
    void changed() => seen.add(AppLocale.changes.value);
    AppLocale.changes.addListener(changed);
    addTearDown(() => AppLocale.changes.removeListener(changed));
    AppLocale.use(const Locale('en', 'GB'));
    AppLocale.use(const Locale('en', 'US'));
    AppLocale.use(const Locale('zh', 'TW'));
    expect(seen, [AppLocale.en, AppLocale.zhCN]);
  });

  testWidgets('stored language is effective before services start', (tester) async {
    SharedPreferences.setMockInitialValues({AppLanguageController.prefsKey: 'en'});
    await AppLanguageController.load();
    addTearDown(() => AppLanguageController.initial = AppLanguage.system);
    expect(AppLanguageController.initial, AppLanguage.en);
    expect(AppLocale.current, AppLocale.en);
    expect(appL10n.commonCancel, 'Cancel');
  });

  test('content providers react to selection without a widget rebuild', () async {
    SharedPreferences.setMockInitialValues({});
    AppLanguageController.initial = AppLanguage.zh;
    addTearDown(() => AppLanguageController.initial = AppLanguage.system);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final subscription = container.listen(effectiveAppLocaleProvider, (_, _) {});
    addTearDown(subscription.close);
    expect(container.read(effectiveAppLocaleProvider), AppLocale.zhCN);
    await container.read(appLanguageProvider.notifier).set(AppLanguage.en);
    expect(container.read(effectiveAppLocaleProvider), AppLocale.en);
    expect(AppLocale.current, AppLocale.en);
    expect(appL10n.commonCancel, 'Cancel');
  });

  test('appL10n follows AppLocale.use', () {
    expect(appL10n.commonCancel, '取消');
    AppLocale.use(AppLocale.en);
    expect(appL10n.commonCancel, 'Cancel');
    expect(appL10n.commonItemCount(1), '1 item');
    expect(appL10n.commonItemCount(3), '3 items');
    expect(appL10n.monthDay(DateTime(2026, 3, 5)), 'Mar 5');
    AppLocale.use(const Locale('zh'));
    expect(AppLocale.current, AppLocale.zhCN);
    expect(appL10n.monthDay(DateTime(2026, 3, 5)), '3月5日');
  });

  testWidgets('context.l10n falls back to appL10n without the delegate', (tester) async {
    late String text;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            text = context.l10n.commonCancel;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(text, '取消');
  });

  testWidgets('the language row stores the choice', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildLightTheme(),
          home: const Scaffold(body: LanguageSettingsTile()),
        ),
      ),
    );
    expect(find.text('语言'), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppLanguageController.prefsKey), 'en');
  });
}
