// iOS phone files are copied on their own, so this hub is deliberately
// standalone. It uses the same global Symbol key and shape as
// runtime/bridge/dsh-go-bridge/lib/app-language.js; whichever loads first owns
// the single process-local state, and every subscriber sees the same changes.
const KEY = Symbol.for('dsh.go.appLanguage');

export function normalizeLanguage(value) {
  return String(value ?? '').toLowerCase().startsWith('en') ? 'en' : 'zh';
}

export function appLanguageHub() {
  let hub = globalThis[KEY];
  if (hub !== undefined) return hub;
  const listeners = new Set();
  hub = {
    language: normalizeLanguage(process.env.DSH_APP_LANGUAGE),
    subscribe(listener) {
      listeners.add(listener);
      return () => listeners.delete(listener);
    },
    set(value) {
      const language = normalizeLanguage(value);
      const previous = hub.language;
      hub.language = language;
      process.env.DSH_APP_LANGUAGE = language;
      if (language === previous) return language;
      for (const listener of [...listeners]) {
        try { listener(language); }
        catch (error) { console.error('app language subscriber failed:', error?.message ?? error); }
      }
      return language;
    },
  };
  Object.defineProperty(globalThis, KEY, { value: hub, configurable: true });
  return hub;
}

/**
 * Keep every registered description in step with the app language. The
 * definition objects are mutated in place: re-registering would replace the
 * identity a step already admitted and could strand an in-flight call.
 */
export function followAppLanguage(entries, describe) {
  const apply = language => {
    for (const { name, definition } of entries) definition.description = describe(name, language);
  };
  const hub = appLanguageHub();
  apply(hub.language);
  return hub.subscribe(apply);
}
