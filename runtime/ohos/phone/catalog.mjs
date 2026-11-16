// Parameter schemas match PhoneToolCatalog.kt; permissions never change this list.
// Descriptions are model-facing text and follow the app language, selected by
// DSH_APP_LANGUAGE at start and updated live through /dsh-go/v1/app-language
// (defaults to Chinese so an unwired host behaves exactly as before). Schemas
// are shared: only the wording changes.
const field = (type, description) => ({ type, description });
const str = description => field('string', description);
const integer = description => field('integer', description);
const number = description => field('number', description);
const boolean = description => field('boolean', description);
const enumeration = (values, description) => ({ type: 'string', enum: values, description });
const schema = (properties, required = []) => ({ type: 'object', properties,
  ...(required.length ? { required } : {}), additionalProperties: false });

export function phoneLanguage(env = process.env) {
  return String(env.DSH_APP_LANGUAGE ?? '').toLowerCase().startsWith('en') ? 'en' : 'zh';
}

const text = {
  zh: {
    open: '打开应用或链接（app 或 url 二选一）。鸿蒙仅支持前台公开系统能力，不支持后台屏或屏幕快照；无法解析的应用明确报错。',
    app: '包名或应用名', url: '网址或深链', background: '在后台屏打开',
    intent: '用系统公开能力办事（打开界面的事务仍需用户在对方界面确认），能办就别点界面。字段按 kind：' +
      'alarm(hour,minute,days?,message?)、timer(seconds,message?)、calendar(title,begin,end?,all_day?,location?,description?)、' +
      'dial(number)、sms_draft(number?,text)、share(text,app?)、navigate(destination|lat+lng,mode?,map?)、settings(page,app?)。' +
      '鸿蒙只用已实现的公开系统映射；闹钟和计时器由系统代理提醒，不承诺唤醒或运行引擎；不支持的事务明确报错，打开界面不代表事务已完成。',
    kind: '事务类型', hour: '时 0–23', minute: '分 0–59',
    days: '重复的星期，1=周一 … 7=周日；省略只响一次',
    seconds: '秒 1–86400', message: '闹钟 / 计时器标签', title: '日程标题',
    begin: '开始，如 2026-10-24T19:00（手机时区）；全天写 2026-10-24',
    end: '结束，省略 = 开始后 1 小时；全天事件省略 = 只占当天', all_day: '全天', location: '地点',
    description: '备注', number: '电话号码', body: '文字内容',
    shareApp: '分享目标应用（省略弹分享面板）；settings:app_notifications 用哪个应用',
    destination: '目的地名称或地址', lat: '纬度 GCJ-02', lng: '经度 GCJ-02',
    mode: '出行方式，默认 drive', map: '地图，默认先高德再百度',
    page: '设置页；app_notifications 还需 app',
    notify: '给用户发一条手机通知。鸿蒙要求本次执行时DSH在前台；发布成功不代表用户已看到。',
    notifyTitle: '标题', notifyText: '正文',
    clipboard: '读写剪贴板：set 写入文字；get:true 读取（系统只允许前台应用读，DSH 不在前台时读不到）。鸿蒙仅支持set写入；get:true明确不支持。',
    set: '要写入的文字', get: '读取剪贴板',
    handoff: '把手机交给用户完成登录、验证码、支付或没把握的步骤；等用户点「继续」或「停止」，最长 10 分钟。鸿蒙不返回屏幕快照，继续仅证明本次点击，不证明第三方操作完成。',
    reason: '要用户做什么，一句话',
  },
  en: {
    open: 'Open an app or a link (app or url, one of them). HarmonyOS supports only public foreground system capabilities; there is no background screen or screenshot, and an app that cannot be resolved reports an explicit error.',
    app: 'Package name or app name', url: 'URL or deep link', background: 'Open on the background screen',
    intent: 'Use public system capabilities (a transaction that opens another UI still needs the user to confirm there); prefer this over tapping the UI. Fields depend on kind: ' +
      'alarm(hour,minute,days?,message?), timer(seconds,message?), calendar(title,begin,end?,all_day?,location?,description?), ' +
      'dial(number), sms_draft(number?,text), share(text,app?), navigate(destination|lat+lng,mode?,map?), settings(page,app?). ' +
      'HarmonyOS uses only implemented public system mappings; alarms and timers are reminders delegated to the system, with no promise of waking or running the engine; an unsupported transaction reports an explicit error, and opening a UI does not mean the transaction completed.',
    kind: 'Transaction type', hour: 'Hour 0–23', minute: 'Minute 0–59',
    days: 'Repeating weekdays, 1=Monday … 7=Sunday; omit to ring once',
    seconds: 'Seconds 1–86400', message: 'Alarm / timer label', title: 'Event title',
    begin: 'Start, such as 2026-10-24T19:00 (phone time zone); for an all-day event write 2026-10-24',
    end: 'End; omit for one hour after the start, or for an all-day event to cover only that day', all_day: 'All day', location: 'Location',
    description: 'Notes', number: 'Phone number', body: 'Text',
    shareApp: 'Share target app (omit to show the share sheet); for settings:app_notifications, which app',
    destination: 'Destination name or address', lat: 'Latitude GCJ-02', lng: 'Longitude GCJ-02',
    mode: 'Travel mode, drive by default', map: 'Map, Amap then Baidu by default',
    page: 'Settings page; app_notifications also needs app',
    notify: 'Send the user a phone notification. HarmonyOS requires DSH to be in the foreground when this runs; a successful post does not mean the user saw it.',
    notifyTitle: 'Title', notifyText: 'Body',
    clipboard: 'Read or write the text clipboard: set writes text; get:true reads it (the system only lets a foreground app read, so it fails when DSH is not in the foreground). HarmonyOS supports only set; get:true is explicitly unsupported.',
    set: 'Text to write', get: 'Read the clipboard',
    handoff: 'Hand the phone to the user for sign-in, verification codes, payment or steps you are unsure about; wait for the user to tap Continue or Stop, for up to 10 minutes. HarmonyOS returns no screenshot; Continue proves only this tap, not that the third-party action completed.',
    reason: 'What the user should do, in one sentence',
  },
};

/** The tool list for a language; the default Chinese export stays for older callers. */
export function phoneCatalogIn(language = phoneLanguage()) {
  const t = text[language === 'en' ? 'en' : 'zh'];
  return Object.freeze([
    { name: 'mcp__phone__open', description: t.open,
      parameters: schema({ app: str(t.app), url: str(t.url), background: boolean(t.background) }) },
    { name: 'mcp__phone__intent', description: t.intent,
      parameters: schema({
        kind: enumeration(['alarm', 'timer', 'calendar', 'dial', 'sms_draft', 'share', 'navigate', 'settings'], t.kind),
        hour: integer(t.hour), minute: integer(t.minute),
        days: { type: 'array', items: { type: 'integer' }, description: t.days },
        seconds: integer(t.seconds), message: str(t.message), title: str(t.title),
        begin: str(t.begin), end: str(t.end), all_day: boolean(t.all_day), location: str(t.location),
        description: str(t.description), number: str(t.number), text: str(t.body),
        app: str(t.shareApp), destination: str(t.destination), lat: number(t.lat), lng: number(t.lng),
        mode: enumeration(['drive', 'transit', 'walk', 'ride'], t.mode),
        map: enumeration(['amap', 'baidu'], t.map),
        page: enumeration(['home', 'wifi', 'bluetooth', 'mobile_network', 'airplane', 'display', 'sound', 'battery',
          'location', 'date', 'language', 'storage', 'nfc', 'app_notifications'], t.page),
      }, ['kind']) },
    { name: 'mcp__phone__notify', description: t.notify,
      parameters: schema({ title: str(t.notifyTitle), text: str(t.notifyText) }, ['title', 'text']) },
    { name: 'mcp__phone__clipboard', description: t.clipboard,
      parameters: schema({ set: str(t.set), get: boolean(t.get) }) },
    { name: 'mcp__phone__handoff', description: t.handoff,
      parameters: schema({ reason: str(t.reason) }, ['reason']) },
  ]);
}

export const phoneCatalog = phoneCatalogIn('zh');

export const phoneResultSchema = {
  type: 'object', additionalProperties: false,
  properties: {
    status: { type: 'string', enum: ['succeeded', 'failed', 'cancelled', 'timed_out', 'unknown'] },
    effect: { type: 'string', enum: ['none', 'opened_ui', 'notification_published', 'clipboard_written', 'reminder_scheduled'] },
    evidence: { type: 'string', enum: ['opened_ui', 'user_confirmed', 'unknown'] },
    dispatched: { type: 'boolean' }, code: { type: 'string' }, message: { type: 'string' },
  },
  required: ['status', 'effect', 'evidence', 'dispatched', 'code', 'message'],
};
