---
# dsh-go:managed — the dsh-go app keeps this skill up to date; delete this line to keep your own edits.
name: dsh-go-ui
description: Configure the dsh-go phone app's native screens through $DSH_HOME/dsh-go/ui.json — header buttons, quick action capsules above the composer, new-chat suggestion cards, drawer groups and sorting, density, hidden elements, theme and accent color, tablet shortcuts, and plugin seats. Only changes the dsh-go phone app's native UI. For the Harness Web UI or desktop, or for Cordis or web plugins, use the official skills instead. Load this when the person wants to change how the app itself looks, for example 「把顶栏的 XX 换成 YY」「输入框上面加个总结按钮」「新对话页放几个常用问题」「抽屉按创建时间排」「把回合脚注藏掉」「换成暗色 / 黛青」「加个 ctrl+k 打开搜索」. The Harness Web UI and Cordis plugins are the official skills' business.
whenToUse: The person asks to change the dsh-go app (手机 App / 原生界面) itself. Not for the Harness Web UI, Cordis plugins or DSH settings; anything that needs logic or data is a plugin (dsh-go-plugin).
---

# dsh-go interface configuration (ui.json)

The dsh-go app reads `$DSH_HOME/dsh-go/ui.json` (`DSH_HOME` defaults to `~/.dsh`) and changes its native screens according to what the file declares. Save it and the wired keys take effect within a second or two, with no restart.

**Only some keys are wired today; see the "Effect status" table below.** The app still parses and validates unwired keys, but the interface will not change — never promise the person that writing a key makes it take effect.

The file can only declare; it cannot execute. There are no scripts, no network requests and no installs. A button can only perform the four actions below, and only when the person taps it.

## Division of labor with the official skills

- **This skill**: change the dsh-go phone app's native screens (ui.json).
- **dsh-go-plugin**: add capsules, menu items, status strips, native panels and tool cards to the phone app; use it when logic or data is needed, not ui.json.
- **Official `cordis-plugin-development` and friends**: plugins, decorations, slots, pages and MCP for the Harness Web UI or desktop; packages live in the workspace and install through `plugin_manager → install_bundle`.
- When the person has not named an interface: on the phone the default is the dsh-go native UI. Decide the interface first, then pick the skill; do not pick by load order. Never mix the two configuration worlds (ui.json and Cordis bundles), and never apply official web-plugin practice to the app.

## How to change it

1. Read the existing file first: `cat "$DSH_HOME/dsh-go/ui.json"` (create it if absent; `mkdir -p` the directory if needed).
2. Change only what the person asked for and keep every other key as it is. Do not delete their earlier configuration.
3. Write it back as strict JSON, UTF-8, with no comments and no trailing commas, at most 64 KiB. Prefer writing a temporary file and then moving it into place.
4. Check your work: `node "$DSH_HOME/skills/dsh-go-ui/scripts/check.mjs"`. Its output is the app parser's judgment, **not the number of effects that reached the screen**; only the wired keys in the "Effect status" table change the interface:
   - `错误 /composer/quickActions/2/action/url：只支持 https 链接`: this item has no effect, everything else proceeds;
   - `忽略`: the app does not understand this part or it exceeds a limit;
   - `提示`: corrected automatically (for example, long text was truncated) and still effective;
   - `ui.json 没有生效：…`: the whole file was not read (syntax error, wrong version) and the app keeps the last valid configuration.
   Fix every `错误`. Add `--json` for a machine-readable result. The checker's "已应用 N 项" only counts declarations the parser accepted; never repeat it as "N changes took effect".
5. A local engine on the phone also writes `$DSH_HOME/dsh-go/ui.status.json`, which holds what the app actually read; use it to cross-check.
6. Tell the person what changed. To undo one item, delete that key; for wired items (`theme.mode`, `plugins.seats`) the app's settings also offer "来自 ui.json" → "恢复默认", which only makes the app ignore that item and does not edit the file.

The complete field definitions are in `schema.json` next to this skill; examples are in `examples/`.

## Effect status

| Key | Status |
|---|---|
| `theme.mode` | Wired: light/dark switching takes effect |
| `composer.quickActions` | Wired: capsules above the composer take effect |
| `hide.pluginCapsule` | Wired: hides the app's plugin hub entry |
| `plugins.seats` | Wired: plugin seats take effect |
| `header.actions` | Validated only, not wired yet |
| `emptyState.suggestions` | Validated only, not wired yet |
| `drawer.groups` / `drawer.sort` / `drawer.filter` | Validated only, not wired yet |
| `density` | Validated only, not wired yet |
| `theme.accent` / `theme.accentPreset` | Validated only, not wired yet |
| `pet` | Validated only, not wired yet |
| `shortcuts` | Validated only, not wired yet |
| The remaining `hide` items | Validated only, not wired yet |

For an unwired key, tell the person plainly that "this item is not applied to the interface yet"; do not invent an effect.

## Fields

```json
{
  "version": 1,
  "header": { "actions": ["schedule", "detail", "newChat",
    { "id": "daily", "icon": "bolt", "label": "Daily", "action": { "type": "send", "text": "Write today's report from the template" } }] },
  "composer": { "quickActions": [
    { "label": "Summarize", "action": { "type": "send", "text": "Summarize the conversation above in three points" } },
    { "label": "Compact", "action": { "type": "command", "name": "compact" } } ] },
  "emptyState": { "suggestions": [
    { "title": "See today's tasks", "subtitle": "Read TODO.md in the workspace", "action": { "type": "send", "text": "Read TODO.md and tell me what to do first today" } } ] },
  "drawer": { "groups": ["pinned", "folders", "today", "yesterday", "thisWeek", "earlier"], "sort": "activity", "filter": "all" },
  "density": "compact",
  "hide": ["turnFooter", "tokenCount"],
  "theme": { "mode": "system", "accentPreset": "daiqing" },
  "shortcuts": [ { "keys": "ctrl+k", "action": { "type": "open", "page": "search" } } ],
  "plugins": { "seats": { "conversation.input.dock": { "dsh-cost-meter": "hidden" } } }
}
```

| Key | Format |
|---|---|
| `version` | Required, `1` |
| `header.actions` | Buttons on the right of the chat header, shown in order. Built-ins: `newChat` (new chat), `detail` (chat details), `schedule` (automation clock), `agents` (subagent capsule), `model` (model capsule). Built-ins not listed are hidden; `[]` hides all. At most 3 custom buttons: `id` (starts with a lowercase letter, letters, digits and -), `icon` (see below), `label` (at most 8 characters) and `action` |
| `composer.quickActions` | Capsules above the composer, at most 8; a `label` of at most 10 characters plus `action`. They collapse while a reply is generating |
| `emptyState.suggestions` | Suggestion cards on a new chat, at most 6; `title` at most 20 characters, optional `subtitle` at most 40 characters, and `action` |
| `drawer.groups` | Order and visibility of chat-list groups: `pinned`, `folders`, `today`, `yesterday`, `thisWeek`, `earlier`; groups not listed are hidden |
| `drawer.sort` | `activity` (recent activity) or `created` (creation time) |
| `drawer.filter` | Filter when the drawer opens: `all`, `running`, `pending`, `unread` |
| `density` | `compact` or `comfortable` |
| `hide` | Elements to hide: `turnFooter` (turn footer), `tokenCount` (token count), `reasoningDetails` (reasoning), `activityStrip` (activity strip while generating), `whaleTail` (whale-tail animation), `todoPill` (todo pill), `goalBar` (goal bar), `pluginCapsule` (the app-drawn Plugins entry above the chat composer) |
| `theme.mode` | `system`, `light`, `dark` |
| `theme.accentPreset` | `mist` mist blue, `daiqing` daiqing, `dusk` dusk purple, `turquoise` turquoise, `amber` amber, `graphite` graphite |
| `theme.accent` | Custom accent color `#RRGGBB` (the app adjusts it until contrast passes); use either this or `accentPreset` |
| `pet` | `id`, `position` (`top-left` / `top-right` / `bottom-left` / `bottom-right`), `quiet` (boolean). Currently validated only and does not change the interface |
| `shortcuts` | Tablet hardware-keyboard shortcuts, at most 20: `keys` such as `ctrl+k`, `ctrl+shift+n`, `alt+1`, `f5` (must include ctrl or alt except for F keys; meta/cmd/win are not allowed; `ctrl+a/c/v/x/y/z`, `ctrl+shift+v/z` and `alt+f4` are taken) plus `action` |
| `plugins.seats` | How plugins appear in native UI: `{ "<slot>": { "<npm package name>": "native" \| "island" \| "web" \| "hidden" } }` (native rendering / embedded web / open in Web mode / hidden). Slot names are in `schema.json` under `x-dsh-go.slots.known`; entries in `unseatable` are the app's own UI and take no plugins |

Icons (`icon`): bolt star sparkle heart flag bookmark pin bell clock alarm calendar todo note document folder search code terminal globe chart lightbulb book puzzle robot chat mail translate image camera mic link summary wrench bug travel school home play refresh archive team wallet palette

To hide the chat page's Plugins entry, add `pluginCapsule` to the existing `hide` array, for example `{"version":1,"hide":["pluginCapsule"]}`. It hides only the app's hub entry; it does not disable plugins, hide plugins' own quick capsules, or change the entries in All features or Chat details. Delete the item, or restore defaults on the UI configuration page, to show it again. `plugins.seats` configures plugin slots, not this app entry; do not substitute a `chat.panel` or `dsh-go.panel` seat setting.

## Actions

| `type` | Fields | What happens when the person taps |
|---|---|---|
| `send` | `text` (at most 2000 characters) | Puts the text in the composer; the person taps send. Never sends automatically |
| `open` | `page` | Opens an app page: `new-chat`, `settings`, `search`, `files`, `terminal`, `jobs`, `skills`, `schedules`, `models`, `plugins`, `cordis`, `engine`, `web`, `session-detail`, `workspaces`, `account`, `remote`, `phone`, `notifications`, `diagnostics` and so on; see `$defs.page` in `schema.json` for all of them |
| `command` | `name` (without `/`), optional `args` (one line) | Runs `/name args` in the current chat |
| `link` | `url` (accepts `https://` only) | Asks for confirmation, then opens the browser |

## Notes

- Each host has its own ui.json; the app uses the file of the host it is connected to.
- A mistake in one item affects only that item; when the whole file has a syntax error the app keeps the last valid configuration.
- Do not put secrets, tokens or other sensitive data in the file.
- Do not invent fields or values; anything not in the tables above is unknown to the app.
