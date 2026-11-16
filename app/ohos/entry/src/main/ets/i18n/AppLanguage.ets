import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import i18n from '@ohos.i18n';

const PREFS_NAME: string = 'flutter_shared_preferences';
const CHOICE_KEY: string = 'flutter.app_language';

/**
 * Native text in the language the app shows, not the system's.
 *
 * Dart stores `app_language` (`system` / `zh` / `en`) through
 * shared_preferences, which keeps `flutter.app_language` in the
 * `flutter_shared_preferences` store on HarmonyOS. The resolution matches
 * Dart's AppLocale.resolve: an explicit `zh` or `en` wins, otherwise the
 * first preferred Chinese or English language wins, and anything else,
 * including an empty list, is English.
 */
export class AppLanguage {
  private static context: common.Context | null = null;

  static init(context: common.Context): void {
    AppLanguage.context = context.getApplicationContext();
  }

  /** The pure rule behind [language], shared with Dart's AppLocale. */
  static resolve(choice: string | null, systemLanguages: string[]): string {
    if (choice === 'zh' || choice === 'en') return choice;
    for (let index: number = 0; index < systemLanguages.length; index++) {
      const tag: string = systemLanguages[index];
      const language: string = tag.toLowerCase().split('-')[0].split('_')[0];
      if (language === 'zh') return 'zh';
      if (language === 'en') return 'en';
    }
    return 'en';
  }

  static systemLanguages(): string[] {
    try {
      return i18n.System.getPreferredLanguageList();
    } catch (_) {
      return [];
    }
  }

  static language(): string {
    const context: common.Context | null = AppLanguage.context;
    if (context !== null) {
      try {
        const options: preferences.Options = { name: PREFS_NAME };
        const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
        const chosen: string = store.getSync(CHOICE_KEY, '') as string;
        if (chosen === 'zh' || chosen === 'en') return chosen;
      } catch (_) {
        // Unreadable preferences follow the system, like Dart's load().
      }
    }
    return AppLanguage.resolve(null, AppLanguage.systemLanguages());
  }

  static isEnglish(): boolean {
    return AppLanguage.language() === 'en';
  }

  /** The engine route's two values; the wording rule is the same as [pick]. */
  static wire(): string {
    return AppLanguage.isEnglish() ? 'en' : 'zh';
  }

  /** The native string for the app language. */
  static pick(zh: string, en: string): string {
    return AppLanguage.isEnglish() ? en : zh;
  }
}
