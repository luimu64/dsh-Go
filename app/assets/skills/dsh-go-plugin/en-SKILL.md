---
# dsh-go:managed — the dsh-go app keeps this skill up to date; delete this line to keep your own edits.
name: dsh-go-plugin
description: Write a small local plugin for the dsh-go phone app that appears in the **phone's native interface** — a capsule above the composer, an action in the reply long-press menu, a status strip, a native panel or a tool-result card, with read-aloud, stop-on-speech and captions; check it with the bundled checker and install it on the current host. Load it first when the person wants to add something with logic or data to the dsh-go app, for example 「输入框上面加个按钮，把剪贴板译成英文」「长按消息加个『存到笔记』」「输入框上方显示今天用了多少」「做个面板看我的待办」「这个工具的结果画成卡片」「加个按钮把回复读出来」. Only for the dsh-go phone native UI; for Cordis plugins, the Harness Web UI or the desktop, use the official cordis-plugin-development skill instead, not this skill's directory or installation method.
whenToUse: The person wants to add something of their own to the dsh-go phone app (手机 App / 原生界面) that needs logic or data. For fixed buttons, layout, theme or hiding things use the dsh-go-ui skill (ui.json) instead. For Cordis plugins or the Harness Web UI / desktop, use the official cordis-plugin-development skill — different directory and install entry.
---

# Write a small local plugin for dsh-go

A plugin is an npm package directory on the host: the `dshGo` manifest in `package.json` declares what appears in the app, and `lib/index.js` handles taps and pushes data inside the engine. The app only draws the declaration and JSON views; it never executes plugin code.

## Division of labor with the official skills (decide the interface first)

This skill covers only the **dsh-go phone app's native interface**. Creative mode also loads the official `cordis-plugin-development`, which covers plugins for the **Harness Web UI / desktop**; the two have different directories, manifests and install entries. **Decide the interface first, then pick the skill**; do not pick by load order and never mix them:

| What the person wants | Use | Directory / install |
|---|---|---|
| Capsules, menu items, status strips, native panels, tool-result cards, read-aloud / captions in the phone app | This skill | `$DSH_HOME/dsh-go/plugins/<name>/`, `dsh plugin --profile web add <directory>` |
| Change the dsh-go app's own look (header buttons, theme, hidden elements) | `dsh-go-ui` (ui.json) | `$DSH_HOME/dsh-go/ui.json` |
| Cordis / Harness Web UI plugins, decorations, slots, MCP, pages | Official `cordis-plugin-development` | Create a package in the workspace + `plugin_manager` → `install_bundle` |
| Agent presets, Cordis compositions | Official composition skills | Official procedure |

- When the person does not name an interface: in this app the default target is the dsh-go phone native UI (`AGENTS.md` says the same); but when they explicitly want the web version or desktop, follow the official skill.
- The official skill's rules "do not create packages outside the workspace, do not create packages under `$DSH_HOME`, do not hand-write a profile's package.json / cordis.patch.yml" apply to **Cordis bundles**. A dsh-go native plugin is not a Cordis bundle: it is an npm package under `$DSH_HOME/dsh-go/plugins/`, installed with `dsh plugin --profile web add`. Each set of rules governs its own case; they do not conflict, and their directories and installation methods are not interchangeable.
- When the same "add a button" can be done both ways: build the native version first for dsh-go; if the person also wants the web version, let the official skill build a separate one.

## Decide which approach first

| What the person wants | How |
|---|---|
| A fixed-text button, header button, hidden element or theme | Do not write a plugin; use the dsh-go-ui skill to edit ui.json |
| A button that reads the clipboard / composer / a reply, or computes something | This skill: `composer.actions` / `message.actions` + `on(id)` |
| One line of numbers always visible | This skill: `composer.strip` + `strip(id)` |
| A whole page of information | This skill: `panels` + `panel(id)` |
| A rarely used but handy tool | This skill: `composer.tools` (plus panel; needs a newer app) |
| Act on a whole conversation: export, archive | This skill: `session.actions` (right sidebar "Info"; needs a newer app) |
| A number visible at a glance each turn | This skill: `turn.note` + `turnNote(id)` (turn footer; needs a newer app) |
| Draw a tool's result as a card | This skill: return `{ "dsh-go/view": view }` from the tool's `output.presentationMeta`; no manifest needed |
| Read replies aloud, stop on speech, follow captions | This skill: `capabilities` + `media` / `micro` / `overlays` (see "Sound and captions" below) |

Capsules, menus, status strips and panels appear only on hosts with the dsh-go bridge installed: the phone's local engine has it (if `/etc/dsh-app/runtime.json` exists); other hosts only get tool cards.

## Steps

1. **Create the directory** (under `$DSH_HOME/dsh-go/plugins/`, kept across engine resets; `DSH_HOME` defaults to `~/.dsh`):
   ```sh
   P="${DSH_HOME:-$HOME/.dsh}/dsh-go/plugins/local-quote"
   mkdir -p "$(dirname "$P")" && cp -r "${DSH_HOME:-$HOME/.dsh}/skills/dsh-go-plugin/template" "$P"
   ```
2. **Rename**: the `name` in `package.json`, in `cordis.patch.yml` and in `lib/index.js` must match; start with `local-` and use lowercase letters, digits and `-`.
3. **Write the manifest** (`package.json` → `dshGo`, see the table below); declare only what you use and list in `wants` only what you truly read.
4. **Write the handlers** (`lib/index.js`): always inside `ctx.inject(['dshGo'], (ctx) => { … })`.
5. **Check your work** until there are no "errors":
   ```sh
   node "${DSH_HOME:-$HOME/.dsh}/skills/dsh-go-plugin/kit/bin/check.mjs" "$P" --load
   ```
   `--load` loads your code in an isolated environment: it checks that handlers exist and that the views your view functions draw can be drawn by the app.
   `--json` for machine reading; `--lang zh` to choose the language; `--budget toolCard|panel|strip` checks the view budget for a tool card, panel or status strip; `--app <version>` judges `minApp` against the target app version (without it, the check assumes 999.0.0, so `minApp` never fails; always pass it when checking a target version); newer fields such as panel placement are not version-checked.
6. **Install** (effective as soon as it is installed, no restart):
   ```sh
   dsh plugin --profile web add "$P"
   ```
   The phone's local engine uses the `web` profile. What is installed is a link to this directory: do not delete the directory.
7. **After changing code**: a changed manifest (`package.json`) is re-read automatically; after changing code in `lib/`, the person must restart the engine on the app's Engine page.
8. **Tell the person** what changed and where to see it: capsules above the composer; menu items in the long-press menu on assistant messages, grouped by plugin; status strips above the composer; panels on the Plugins tab of chat details or under All features. The first time a button reads the clipboard / composer / a message, the app asks the person once.

Uninstall: `dsh plugin --profile web remove local-quote`, then delete the directory.

## Manifest (`package.json` → `dshGo`)

```json
{
  "v": 1,
  "title": { "zh": "引用", "en": "Quote" },
  "icon": "bolt",
  "wants": ["clipboard"],
  "contributes": {
    "composer.actions": [
      { "id": "summarize", "label": "Summarize", "effect": { "type": "insert", "text": "Summarize the conversation above in three points." } },
      { "id": "paste-quote", "label": { "zh": "引用剪贴板", "en": "Quote clip" }, "icon": "document" }
    ],
    "message.actions": [{ "id": "save", "label": "Save to notes", "icon": "note" }],
    "composer.strip":   [{ "id": "today", "icon": "chart", "panel": "stats" }],
    "panels":           [{ "id": "stats", "title": "Stats", "icon": "chart", "placement": ["session.tab", "features"] }]
  }
}
```

| Slot | Per plugin | Text limit | Fields | Tap behavior |
|---|---|---|---|---|
| `composer.actions` | 2 | `label` 10 characters | `id` `label` `icon?` `effect?` | With `effect`: the app runs it directly, no code needed; otherwise calls `on(id)` |
| `message.actions` | 2 | `label` 12 characters | Same as above | Same as above |
| `composer.strip` | 1 | `text` 24 characters | `id` `icon?` `text?` `panel?` | `panel` → opens that panel; otherwise `on(id)` |
| `panels` | 4 | `title` 16 characters | `id` `title` `icon?` `placement?` `presentation?` `view?` | Buttons / rows / options in the view → `actions` |
| `composer.tools` | 2 | `label` 8 characters | `id` `label` `icon?` `effect?` `panel?` `requires?` | `panel` / `effect` run directly in the app (write only one); otherwise `on(id)` |
| `session.actions` | 2 | `label` 12 characters | `id` `label` `icon?` `effect?` `requires?` | Same as capsules |
| `turn.note` | 1 | 16 characters per segment | `id` | Not tappable; in `turnNote(id, (scope, emit) => …)` call `emit({ turnNumber: { text, tone? } })` |

The app also has global limits: at most 8 capsules above the composer in total, 8 tools in the plus panel in total, 2 turn notes at once, and 8 note-feed entries; anything beyond is not shown. A panel button's pending label may be at most 16 characters.

- Write `title`, `label` and `text` as a string or as `{ "zh": "…", "en": "…" }`; neither language may exceed the limit. A plugin `title` is at most 24 characters.
- `id`: starts with a letter or digit, then letters, digits and `_ . -`, at most 40 characters; **unique within the whole plugin** (across slots too).
- `wants`: `clipboard` and `draft` (composer text) only go to capsules and `composer.tools`; `message` (the reply body being long-pressed) only goes to menu items.
- `placement`: `session.tab` (chat details page, scope carries sessionId; the default), `features` (All features), `chat.panel` (the sheet opened by the Plugins capsule above the chat composer; scope carries sessionId), `plugin` (a panel inside the plugin's own entry; newer apps). Write one string or an array; older apps ignore values they do not know, and a panel placed only in `plugin` falls back to `session.tab`.
- `presentation`: `page` (push a full page; the default) or `sheet` (a sheet); only newer apps understand it, older apps ignore it and open a page.
- View functions check `caps.surfaces` to see whether the app can draw something (`hasSurface(caps, 'chat.panel')` and so on), falling back to `session.tab` when unsure.
- A static `effect` may only be `insert` `command` `open` `link` `toast` `copy`.
- `icon`: bolt star sparkle heart flag bookmark pin bell clock alarm calendar todo note document folder search code terminal globe chart lightbulb book puzzle robot chat mail translate image camera mic link summary wrench bug travel school home play refresh archive team wallet palette coin money speaker read copy quote share edit write save paste add remove delete clear fork regenerate reply select-text qr download downloads external info warning check done success error question pending running tip list table panel sidebar menu more expand collapse file folder-open workspace storage pdf zip slides article text diff gallery audio music video video-file play-video pause stop replay generate-image generate-video diagram plugin bot agent skill model tool workflow goal plan job automation command trajectory web web-search browser history time today timezone schedule repeat reminder user account group chats mention invite announcement reaction poll notification send community forum feedback wechat qq telegram discord phone computer cloud server power restart retry theme color text-size pet featured badge favorite settings

An unknown icon is drawn as the default icon without an error. Do not use locks, keys or shields to convey security/privacy: the app does not guarantee those semantics and they mislead easily.
- `minApp`: optional minimum app version (such as `"1.0.16"`). On an older app the native parts are not shown and the person is told to update the app.
- `capabilities`: optional capability list. `files` means the plugin uses the system picker to choose files/images (see "Choosing files and images" below); ordinary panels still open on older apps and bridges that do not negotiate it.

## Handlers (`ctx.dshGo`)

```js
export const name = 'local-quote'
export function apply(ctx) {
  ctx.inject(['dshGo'], (ctx) => {
    // Capsule / menu item / status strip taps: (scope, event) → effect
    ctx.dshGo.on('paste-quote', (scope, event) => scope.clipboard ? { insert: `> ${scope.clipboard}` } : { toast: 'Clipboard has no text' })

    // Status strip: push { text ≤ 24, icon?, tone? }; return a cancel function
    ctx.dshGo.strip('today', (scope, emit, caps) => {
      const tick = () => emit({ text: caps.locale.startsWith('en') ? `Today ${count()}` : `今日 ${count()}` })
      tick()
      const timer = setInterval(tick, 60_000)
      return () => clearInterval(timer)
    })

    // Panel: view (structure) + data (push whole objects; the bridge diffs) + tap handlers in the view
    ctx.dshGo.panel('stats', {
      view: (scope, caps) => ({ type: 'stack', children: [
        { type: 'metric', label: 'Today', value: { $: 'data.today' } },
        { type: 'actions', items: [{ label: 'Reset', action: 'reset' }] },
      ] }),
      data: (scope, emit, caps) => { emit({ today: count() }); return () => {} },
      actions: { reset: (scope, event) => ({ toast: 'Reset', patch: { today: 0 } }) },
    })
  })
}
```

| Parameter | Contents |
|---|---|
| `scope` | `{ sessionId?, turnId?, messageId?, callId? }`; on a tap it also carries the declared `clipboard` / `draft` / `message` |
| `event` | `{ surface, id, action?, value?, locale }`; panel taps: `action` is the view's action id and `value` is the args (`options` → `{ value }`, `confirm` → `{ confirmed }`) |
| `caps` | View functions: `{ protocol, app, locale, surfaces, components }`; data functions: `{ protocol, locale }` |

**Returned effects** (at most 4 at once, and only returned within 3 seconds of the tap):

| Form | Effect |
|---|---|
| `{ insert: '…' }` | Puts it in the composer (at most 2000 characters); **never sends automatically** |
| `{ toast: '…' }` | A one-line message (at most 40 characters) |
| `{ copy: '…' }` | Copy (at most 8000 characters) |
| `{ link: 'https://…' }` | Opens the browser after the person confirms; https only |
| `{ open: 'panel:stats' }` / `{ open: 'page id' }` | Opens this plugin's panel or an app page |
| `{ command: 'compact' }` | Runs a slash command in the current chat |
| `{ refresh: true }` / `{ patch: {…} }` | Refetches the panel view / merges data |
| Several keys in one object | All run in order, for example `{ copy: md, toast: 'Copied' }` |

**Slow work (calling a model, network) uses a deferred effect**: return `pending` first and the app shows a wait state; the result must arrive within 60 seconds and may only be `insert` `copy` `toast` `patch`; at most 2 at once per plugin; `signal` fires on cancel / timeout / disconnect — stop when it arrives.

```js
ctx.dshGo.on('translate', (scope) => ({
  pending: { label: 'Translating', timeoutMs: 60_000 },
  result: async (signal) => ({ insert: await translate(scope.clipboard, signal) }),
}))
```

## Views (panels, tool cards)

A tree of JSON components. Any value may be a binding `{ "$": "data.a.b" }` that reads pushed data and shows "—" when unavailable; tool cards have no data, so write values directly.

**Choose the view version first**: a root node without `v`, or with `v: 1`, uses v1 components and the original styling; write `v: 2` on the root when you need new controls, structural components or bounded styling. The manifest `dshGo.v` stays `1`, separate from the view version.

The table below lists only v1's basic components. The complete v2 component and field list is in the bundled `kit/schema/view.schema.json`; `docs/plugins/components.md`, `styles.md` and `inputs.md` in the app repository describe new components, styles and forms. Do not refuse v2 just because a component is not in the table. To stay compatible with older apps, degrade through `caps.components` / the SDK's `adaptView`, keeping basic fields such as `text`.

```json
{"v":2,"type":"stack","accent":"teal","children":[
  {"type":"text","text":"Example","style":{"size":"title","weight":"bold"}},
  {"type":"emptyState","title":"Nothing here yet"}
]}
```

| Component | Fields |
|---|---|
| `stack` / `row` | `children` (rows wrap on narrow screens); the root may carry `title` |
| `text` | `text`, `tone?: muted` |
| `metric` | `label` `value` `tone?: good\|warn\|bad\|info` `caption?` |
| `chart` | `kind: bar\|hbar\|line\|donut` `categories` `series: [{ name?, values }]` `unit?` `caption?` |
| `compare` | `items: [{ title, badge?, rows: [[name, value]] }]` (2–4 items) |
| `steps` | `items: [{ label, status: done\|current\|todo\|failed, detail? }]` |
| `callout` | `text` `tone?: info\|good\|warn\|bad` |
| `list` | `items: [{ title, subtitle?, trailing?, icon?, tone?, action? }]` (at most 50) |
| `keyValue` | `items: [[name, value], …]` or `[{ label, value, tone? }]` or `{ name: value }` (at most 24) |
| `progress` | `value` `max?` (default 100) `label?` `caption?` `tone?` |
| `table` | `columns: [text \| { label, align? }]` (at most 8) `rows: [[…]]` (at most 50) |
| `actions` | `items: [{ label, action, icon?, style?: primary\|plain }]` (at most 4, at most one primary) |
| `options` | `id` `options: [{ label, value? }]` `multi?` `selected?` |
| `confirm` | `id` `confirmLabel?` `cancelLabel?` |
| `image` | `src`: a same-origin `/dsh-go/v1/…` path or a `data:image/…` of at most 64 KiB; `alt?` `aspect?` |

`action` is an action-id string, or `{ "id": "open", "args": { … } }` (args at most 1 KiB). Limits: a panel is 32 KiB / 120 components / 8 levels; a tool card is 8 KiB / 40 components / 6 levels and is not tappable in phase 0.

Tool card:

```js
presentationMeta: (args, value) => {
  try {   // Throwing or returning undefined / NaN fails the whole tool call
    const text = JSON.stringify({ type: 'stack', title: `${value.city} · Today`, children: [{ type: 'metric', label: 'Temperature', value: `${value.temp}°` }] })
    return text.length < 8000 ? { 'dsh-go/view': JSON.parse(text) } : {}
  } catch { return {} }
},
```

## Choosing files and images (NA v1.3, optional)

After the person taps, a plugin can open the system picker; the chosen content goes to the current host, and the plugin reads bytes through a one-time handle without receiving phone file paths.

- Add `"capabilities": ["files"]` to the manifest; add `"requires": ["files"]` to the button that triggers the picker; a pick button inside a panel is shown only when `caps.features?.includes('files')`, otherwise show ordinary explanatory text.
- Effects: `effects.pickFile('selected', { maxFiles: 2 })` or `effects.pickImage(...)`; without the SDK, return `{ type: 'pickFile', action: 'selected', maxFiles: 2 }`. `maxFiles` defaults to 1 and accepts only 1–4.
- The callback is the same panel's `actions[action]`, or falls back to `ctx.dshGo.on(contribution id, handler)`; `event.value` is `{ status: 'selected', files: [{ handle, name, bytes, mediaType, access }] }`, `cancelled` or `error`.
- Inside the callback, read bytes with `ctx.dshGo.readPickedFile(handle)` (an independent copy). A handle is valid only within this one pending callback: after the callback ends, times out, unloads or disconnects it can no longer be read; do not store handles or build paths from `name`.
- Older apps, older bridges and DSH Remote relaying do not negotiate this capability; panels open as usual. `dshGo.v` remains `1`; do not write `1.3`.
- The call that starts a picker must come from a user gesture (`userGesture`) and must not fire in the background.

## Sound and captions (v1.2, optional)

Add `"capabilities": ["audio", "voice", "micro", "overlay"]` to the manifest (only the ones used), and add `media: [{ id }]`, `micro: [{ id }]` and `overlays: [{ id, channel }]` to `contributes` (at most 2 each, ids unique among all contributions); add `"requires": ["audio"]` to buttons that need sound.

```js
ctx.dshGo.on('read', (scope) => [   // Same instance: the app treats it as one session
  { type: 'audio', op: 'play', instance: 'reading', src: 'media:speech', key: 'k1' },
  { type: 'voice', op: 'start', instance: 'reading' },
  { type: 'overlay', op: 'show', instance: 'reading', id: 'subtitle' },
])
ctx.dshGo.media('speech', async (scope, { key, signal }) => ({ body: wavBuffer, contentType: 'audio/wav' }))   // whole clip, at most 16 MiB, within 30 seconds
ctx.dshGo.micro('caption', { data: (scope, emit) => { emit({ text: 'Read to here', progress: 0.3 }); return () => {} } })   // only { text ≤ 240 characters, progress 0–1 }
ctx.dshGo.onCapability((scope, { event }) => {})   // audio.ended / voice.speechStart / …; the return value is not executed
```

Put slow work (TTS) in `media`, not in `on`. The app handles the rest: stop playback before speech and notify, ask the person whether they can hear it, run in the foreground only, and stop listening and close captions when the audio ends. Without TTS, synthesize a placeholder sound like `examples/plugins/dsh-go-example-readaloud`.

## Rules

- v1 keeps the original styling; v2 may use the colors, semantic type sizes, weights, spans and container styles listed in the docs. Do not write arbitrary CSS, font files, sizes, opacity, gradients or animation parameters; the app still decides actual geometry, readable colors and content bounds.
- Keep copy short. Error messages should sound human ("Clipboard has no text"), not like English exceptions.
- Do not put secrets or tokens in views, manifests or code; clipboard / message contents read for a tap are used only for that tap.
- Do nothing with side effects without a tap; `insert` never sends.
- Write fields according to the chosen view version's schema and component catalog, and verify with the bundled checker; do not invent unsupported fields. The complete documentation is in `docs/plugins/` in the app repository.
