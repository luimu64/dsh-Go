// The app language for model-facing runtime text. The host sets DSH_APP_LANGUAGE
// before the engine starts; this process-local hub lets the running engine adopt a
// later Settings → Language choice without a restart.
//
// A language change only rewrites text. Tool names, schemas and execution stay the
// same, and nothing is written to a host preference or the guest filesystem.
//
// Plugins in other runtime trees (iOS phone files are copied on their own) use the
// same Symbol.for key and object shape instead of importing this file, so the
// bridge stays a standalone package while every subscriber sees one hub.
export const APP_LANGUAGE_HUB = Symbol.for("dsh.go.appLanguage");
export const APP_LANGUAGE_PATH = "/dsh-go/v1/app-language";
const MAX_BODY = 4096;

/** `en*` is English, everything else (including unset/zh-*) is Chinese. */
export function normalizeAppLanguage(value) {
  return String(value ?? "").toLowerCase().startsWith("en") ? "en" : "zh";
}

/** The one process-local hub, created by whichever plugin loads first. */
export function appLanguageHub() {
  let hub = globalThis[APP_LANGUAGE_HUB];
  if (hub !== undefined) return hub;
  const listeners = new Set();
  hub = {
    language: normalizeAppLanguage(process.env.DSH_APP_LANGUAGE),
    /**
     * Subscribe a text rebuilder. Returns the disposer. A throwing subscriber is
     * logged and skipped: one catalog must not block the others or the response.
     */
    subscribe(listener) {
      listeners.add(listener);
      return () => listeners.delete(listener);
    },
    set(value) {
      const language = normalizeAppLanguage(value);
      const previous = hub.language;
      hub.language = language;
      // Keep the documented startup variable truthful for any later reader.
      process.env.DSH_APP_LANGUAGE = language;
      if (language === previous) return language;
      for (const listener of [...listeners]) {
        try { listener(language); }
        catch (error) { console.error("app language subscriber failed:", error?.message ?? error); }
      }
      return language;
    },
  };
  Object.defineProperty(globalThis, APP_LANGUAGE_HUB, { value: hub, configurable: true });
  return hub;
}

export const appLanguage = () => appLanguageHub().language;

/**
 * POST /dsh-go/v1/app-language with `{ "language": "en" | "zh" }`.
 * The bridge mounts it behind its existing connection guard; this module never
 * authenticates or touches a remote host's settings.
 */
export function createAppLanguageRoute({ readBody, send }) {
  return {
    async handle(req, res, path) {
      if (path !== APP_LANGUAGE_PATH) return false;
      if (req.method !== "POST") {
        req.resume();
        send(res, 405, { error: { code: "method-not-allowed", message: "method not allowed" } });
        return true;
      }
      const type = String(req.headers["content-type"]).split(";", 1)[0].trim().toLowerCase();
      if (type !== "application/json") {
        req.resume();
        send(res, 415, { error: { code: "unsupported-media-type", message: "content-type must be application/json" } });
        return true;
      }
      let body;
      try {
        body = JSON.parse((await readBody(req, MAX_BODY)).toString("utf8"));
      } catch (error) {
        send(res, error?.status === 413 ? 413 : 400,
          { error: { code: error?.status === 413 ? "too-large" : "bad-request", message: "body is not JSON" } });
        return true;
      }
      if (typeof body !== "object" || body === null || Array.isArray(body) ||
          Object.keys(body).some((key) => key !== "language") ||
          (body.language !== "en" && body.language !== "zh")) {
        send(res, 400, { error: { code: "bad-request", message: "language must be en or zh" } });
        return true;
      }
      const language = appLanguageHub().set(body.language);
      send(res, 200, { v: 1, language });
      return true;
    },
  };
}
