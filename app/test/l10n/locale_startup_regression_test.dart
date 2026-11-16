import 'package:dsh_app/l10n/l10n.dart';
import 'package:dsh_app/state/locale_state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  tearDown(() {
    AppLocale.use(AppLocale.zhCN);
    AppLanguageController.initial = AppLanguage.zh;
  });

  test('an unavailable system locale falls back to English', () {
    expect(AppLocale.resolve(null, const []), AppLocale.en);
    expect(AppLocale.resolve(null, null), AppLocale.en);
  });

  test('unsupported explicit locale cannot silently select Chinese', () {
    expect(AppLocale.resolve(const Locale('fi'), const [Locale('zh')]), AppLocale.en);
  });

  testWidgets('loading stored English applies it before background services start', (tester) async {
    SharedPreferences.setMockInitialValues({AppLanguageController.prefsKey: 'en'});
    await AppLanguageController.load();
    expect(AppLocale.current, AppLocale.en);
    expect(appL10n.commonCancel, 'Cancel');
  });

  testWidgets('changing the selection updates service text before another frame', (tester) async {
    SharedPreferences.setMockInitialValues({});
    AppLanguageController.initial = AppLanguage.zh;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(appLanguageProvider.notifier).set(AppLanguage.en);
    expect(AppLocale.current, AppLocale.en);
    expect(appL10n.commonCancel, 'Cancel');
  });
}
