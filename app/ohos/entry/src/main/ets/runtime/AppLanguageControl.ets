// Pushes Settings → Language into the running HarmonyOS engine (SDK 26 HTTP,
// same loopback/cookie pattern as LinuxControl). Only model-facing text changes;
// no host preference is written and no job or tool registration is replaced.
import http from '@ohos.net.http';

class StopRedirect implements http.HttpInterceptor {
  interceptorType: http.InterceptorType = http.InterceptorType.REDIRECTION;
  async interceptorHandle(_request: http.HttpRequestContext, _response: http.HttpResponse): Promise<boolean> {
    return false;
  }
}

interface LanguageSession {
  origin: string;
  token: string;
  cookie: string | null;
  login: Promise<string> | null;
}

export class AppLanguageControl {
  private session: LanguageSession | null = null;

  private host(baseUrl: string, token: string): LanguageSession {
    const match = /^http:\/\/127\.0\.0\.1:([0-9]{1,5})\/?$/.exec(baseUrl);
    if (match === null || Number(match[1]) < 1 || Number(match[1]) > 65535 || token.length === 0) {
      throw new Error('ohos_language_endpoint');
    }
    const origin: string = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    if (this.session === null || this.session.origin !== origin || this.session.token !== token) {
      this.session = { origin: origin, token: token, cookie: null, login: null };
    }
    return this.session;
  }

  private async request(url: string, options: http.HttpRequestOptions): Promise<http.HttpResponse> {
    const request = http.createHttp();
    try {
      const chain = new http.HttpInterceptorChain();
      if (!chain.addChain([new StopRedirect()]) || !chain.apply(request)) throw new Error('ohos_language_redirect_guard');
      return await request.request(url, options);
    } finally {
      request.destroy();
    }
  }

  private async login(session: LanguageSession): Promise<string> {
    if (session.cookie !== null) return session.cookie;
    if (session.login !== null) return session.login;
    const pending: Promise<string> = (async (): Promise<string> => {
      const response = await this.request(session.origin + '/?token=' + encodeURIComponent(session.token), {
        method: http.RequestMethod.GET, expectDataType: http.HttpDataType.STRING,
        usingCache: false, usingProxy: false, connectTimeout: 1000, readTimeout: 3000, maxLimit: 65536
      });
      const headers = response.header as Record<string, string | string[]>;
      let cookies: string[] = [];
      Object.keys(headers).forEach((key: string): void => {
        if (key.toLowerCase() !== 'set-cookie') return;
        const value = headers[key];
        cookies = typeof value === 'string' ? [value] : value;
      });
      const matches = cookies.map((value: string): string => value.split(';')[0])
        .filter((value: string): boolean => /^dsh-auth-[A-Za-z0-9_-]+=[A-Za-z0-9_.-]+$/.test(value));
      if (response.responseCode !== 303 || matches.length !== 1) throw new Error('ohos_language_auth');
      session.cookie = matches[0];
      return matches[0];
    })();
    session.login = pending;
    try {
      return await pending;
    } finally {
      session.login = null;
    }
  }

  /** True only when the running engine acknowledged the new language. */
  async send(baseUrl: string, token: string, language: string): Promise<boolean> {
    try {
      const session = this.host(baseUrl, token);
      const cookie = await this.login(session);
      const response = await this.request(session.origin + '/dsh-go/v1/app-language', {
        method: http.RequestMethod.POST, expectDataType: http.HttpDataType.STRING,
        header: { 'cookie': cookie, 'content-type': 'application/json' },
        extraData: JSON.stringify({ language: language }),
        usingCache: false, usingProxy: false, connectTimeout: 1000, readTimeout: 3000, maxLimit: 65536
      });
      if (session !== this.session) return false;
      if (response.responseCode === 401) session.cookie = null;
      return response.responseCode === 200;
    } catch (_) {
      return false;
    }
  }
}
