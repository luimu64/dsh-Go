---
# dsh-go:managed — the dsh-go app keeps this skill up to date; delete this line to keep your own edits.
name: dsh-go-support
description: Troubleshooting and feedback for the dsh-go phone app — read the on-device diagnostics the app writes (the path is in the "Local diagnostics" section of AGENTS.md, usually $DSH_HOME/dsh-app/diagnostics.md), locate the symptom in this checklist, and produce a redacted environment summary and issue draft. Load it first when the person reports lag, heat, battery drain, connection failures, crashes, failed updates, plugins not working or phone-control failures, or asks to file a bug. 中文触发：卡顿、发热、耗电、连不上、闪退、更新装不上、插件不生效、手机操控失败、反馈 bug。
whenToUse: The person reports a problem with DSH Go (lag, heat, battery, connection, crash, update, plugin, phone control) or asks to file an issue. Not for changing the app's UI (dsh-go-ui) or writing a plugin (dsh-go-plugin).
---

# dsh-go troubleshooting and feedback

This skill does one thing: **get the facts first, then conclude.** The app writes its own local diagnostics; the path and handling rules are in the "Local diagnostics" section of the global instructions — read that first, then follow the checklist below. Do not prescribe anything based on "it might be…".

## 1. Read the diagnostics first

```sh
# Use an available file-reading tool on these paths (never send a whole diagnostics file elsewhere):
# $DSH_HOME/dsh-app/diagnostics.md        automatic environment snapshot
# $DSH_HOME/dsh-app/diagnostics-manual.md report the person published (check it first when present)
# With direct startup the path has a rootfs prefix; AGENTS.md is authoritative
```

This is a bounded snapshot the app collects from its own state, information Android makes available and runtime logs. It may include the version, device, runtime, connection, performance, recent errors the app caught, and the tail of engine/failure logs; sources that are unavailable or stale are missing. Markdown has a size budget and logs keep only a bounded tail, not the complete history.

The complete error text the app captures is still a bounded in-memory record inside this process; newer versions also persist error categories, a few of their own source locations, and content-free voice phases in a bounded way. On Android 11 and later, the system may provide the exit reason of this app's earlier processes where available; the app does not read exit descriptions or raw traces. These records are not complete crash stacks; a missing, unavailable or empty result is not evidence that everything is fine. The diagnostics bundle is not system logcat either: a normal app's access to other apps and system logs is limited by Android permissions and version, so never assume full-system logs or a permission bypass. If logcat is genuinely needed, explain the scope and privacy risk first and let the person choose a lawful collection method; content varies by Android version, device and permissions.

- First check whether the available report's generation time, app version and device match this report; a report from another device or an older time is not this incident. Prefer the manual report published this time, then fill in the environment from the automatic snapshot. Only when every available report is missing or too old, ask the person to publish from **Settings → Diagnostics → Let the AI read diagnostics**, then read it; do not keep asking for a refresh because the other file is missing. An older version with only the main snapshot is normal.
- When a newer version provides `mcp__phone__diagnostics`, you may call it yourself as soon as the person asks for troubleshooting: it defaults to `refresh:true`, and `section` selects `summary`, `evidence`, `appErrors`, `voice`, `engine` or `failure`, without reading the screen or turning on phone control first. Check `collectedAt`, `refreshed` and `code`; on failure do not present an old snapshot as this incident. `refresh:false` reads the cache only. Each section is bounded and may be marked `truncated`. The tool does not collect system input-method evidence, export arbitrary paths or send anything on the person's behalf. When the tool is missing or unavailable, read the existing snapshot; do not call it repeatedly to push the person into granting permissions.
- If more detail is needed, ask the person to export a diagnostics ZIP from the diagnostics feature: it is built from the same collection, with a summary, settings, and where available crash categories, engine/failure log tails and app errors; logs are still bounded and are not the full text or complete crash details. The person keeps or uploads it after checking it themselves; do not send it for them.

After the person taps **Let the AI read diagnostics**, the app atomically writes only the fixed manual report `diagnostics-manual.md` in the same directory, so the AI can read the system input-method evidence collected this time; automatic refreshes write only `diagnostics.md`, and the two never overwrite each other. Check generation time, device and version separately, and do not treat an old manual report as the current incident; when an older version has only the main snapshot, read the existing file and do not infer that no fault exists. In the same directory as the main snapshot, direct and safe modes locate it by the same AGENTS.md instructions.

**Look at the diagnostics yourself before asking the person a pile of questions**; ask only for what the diagnostics do not contain.

## 2. Look up the symptom

### Crashes / exits during a voice reply
- Read `evidence` and `voice` first: compare the error location, the voice phase and the process exit time, and distinguish a native crash, an abnormal exit and memory reclaim. A request to play is not playback; without a system stack, say plainly that it is unknown, and do not equate a wrong model reply with an app crash.
- **Automatic failure analysis** is off by default. Only after the person explicitly agrees does it send whitelisted structured facts to the on-device engine model (which may be billed); it never sends raw logs, recordings, message bodies, credentials or system input-method evidence. The analysis session has no tools, does not repair anything and does not file issues publicly; failures or unknown results are not retried automatically, no new request is sent after it is turned off or the host changes, and a request already sent cannot be recalled.
- If reading or writing the analysis record fails, automatic analysis pauses; the local recovery entry on the diagnostics page restores the record only and skips faults already stored, without resending old requests to the model. Do not work around it by deleting the person's settings, replaying prompts or clearing data on your own.

### Lag / dropped frames / input feels behind
First work out whether the "app interface" or the "engine/model" is slow:
- In the diagnostics, read `性能` (performance: tier, temperature), `环境` (environment: runtime status is one row, local vs remote) and `最近错误` (recent errors).
- The local engine plus a large task (npm install, many files) competes with the UI for CPU; a laggy interface is normal then. Suggest switching to a remote host or waiting for the task to finish.
- Lag during a long streaming reply: look at reply length and the number of code blocks; that is rendering cost, not the network.
- Ask the person to try **Settings → Performance → Light** once (turns off blur, animation and the desktop pet). If it improves immediately, the cost is effects, not the engine.
- On a high-refresh device, try **Settings → Performance → Refresh rate** at **Auto** or **System** and compare; **Max** makes dropped frames more likely on low-end phones.
- Still laggy: ask the person to note "which page, what action, how long" and export a diagnostics bundle.

### Heat / battery drain
- A resident local engine, phone control (accessibility/floating bar), the desktop pet and a high refresh rate are the main sources; check `环境` for whether it is running, and `设置` for auto-start local, visual replies and phone storage.
- When not needed, ask the person to **stop the local engine** (Settings → Local engine → Stop) or switch to a remote host; turn phone control off when it is not in use.
- Check the temperature tier under `性能`; long streaming replies do generate heat, and that is normal.
- Do not suggest changing system battery optimization or accessibility permissions to "speed things up" — explain such changes first and let the person decide.

### Cannot reach a remote host / stuck at "reconnecting"
- Confirm first: the host and the phone are signed in to the same account, and the host plugin is running (check `/remote status` on the host side).
- **Two TUIs or two dsh instances sharing one `DSH_HOME` on the host** displace each other's connection (the plugin pauses automatic reconnects) — this is the most common "the phone is online but cannot connect". Ask the person to keep one instance, or give the second one its own `DSH_HOME`.
- If LAN/P2P fails it falls back to TURN/Relay; latency is higher but it connects. Check `连接` in the diagnostics.
- If host logs are needed, ask the person to export or paste the relevant lines on the host; do not guess from the phone.

### The engine will not start / it entered safe mode
- In the diagnostics, read `环境` for phase, error, safeReason and strikes, and whether `内置运行时 / 已装` (bundled runtime / installed) agree.
- Common causes: the runtime is not installed correctly, storage is low, a plugin crashes startup (what safe mode is for), or direct startup failed and fell back to proot.
- First ask the person to tap **Retry** or **Start in Safe mode** on **Settings → Local engine**, and read the failure reason in **Logs** (only tap **Install runtime** when the runtime is not installed; do not confuse it with "Reset" — reset deletes chats, workspaces, plugins and settings, see `docs/guide/en/03-engine-hosts.md`); for a plugin problem, guide them to **Settings → Plugins** to disable the most recently installed one.
- For more clues, ask the person to export a diagnostics bundle; it still contains bounded logs, and a missing entry does not prove nothing happened.

### An update will not install
- First see whether the app can update directly: since 1.0.16 it supports installing updates through Shizuku or self-connected ADB, and can export the downloaded package for manual installation; the entries are in the update prompt and **Settings → General → Check for updates**.
- The system install confirmation does not appear or is treated as a cancel: common on Chinese ROMs (HyperOS, ColorOS and others). Ask the person to download `dsh-go-<version>-arm64.apk` manually from the GitHub release and install it, or allow this app to install unknown sources in system settings.
- The package fails to parse: usually an incomplete download; download again and compare with `SHA256SUMS`.

### The engine is killed by the system and restarts / the previous turn was interrupted
- Since 1.0.16 an abnormal engine exit triggers an automatic restart; a notification such as "restarted" means recovery already happened once, not a new fault.
- If the process is killed mid-generation, the reply may stop halfway; ask the person to resend or retry, and do not conclude that the model or network is broken.
- Repeated restarts: export a diagnostics bundle and read `最近错误` and the phase/strikes under `环境`; if it still will not start, follow "The engine will not start" above.
- To inspect the startup mode: Diagnostics › Developer options shows the direct/proot/tawcroot paths; tawcroot is an accelerated startup that falls back on failure, so do not treat it as the fault itself.

### A plugin does not work / its settings page is blank
- Ask the person to confirm the plugin is installed on the **current host** and current profile, and whether its state in the plugin market is enabled.
- Plugins on a remote host live on that host, not the phone; the app is only the entry point.
- A plugin that crashes the engine leads to safe mode; disable the plugin and start again.

### Input method / keyboard problems
- Read the existing snapshot and what the person already said; ask only for the missing reproduction steps, time or input method. Do not re-ask for environment details already given, and never request or send real chat content. Check whether the snapshot time matches the event.
- Distinguish the loss of focus, the keyboard hiding and the input connection closing that the person observed; keep the observations but do not merge them into one thing. An ordinary snapshot does not contain complete focus/keyboard events; the system evidence recorded this time covers known show/hide requests or connection closes, which does not directly prove the keyboard's actual visibility and does not prove that a Flutter input field was rebuilt.
- If basic information is missing and the current version supports it, you may propose a higher-privilege read-only diagnostic: explain its purpose, scope and privacy risk first, ask whether the person wants it, and let the person approve this collection in the native confirmation UI themselves. It only reuses an already configured and running high-privilege channel to read recent system input-method requests emitted by this app's process and return bounded structured events (show/hide request or input connection close, time, source and an identifiable reason); it never returns raw system log lines, and an existing channel authorization is not permission for this diagnostic. Do not trigger system permission prompts yourself; if the channel is unavailable, or the person refuses, cancels or collection fails, say so plainly, do not treat it as fault evidence, and do not bypass authorization.
- After one collection, have the person tap **Let the AI read diagnostics**, then read the system input-method evidence in the snapshot; export the ZIP if more bounded events are needed. Collection results stay in app memory only and are gone after clearing or a restart; files already exported are not recalled. Do not collect in a loop, run stress tests or install a test APK on your own.
- Events contain no input text; raw logs are read momentarily during collection and discarded. Other logs, screenshots and diagnostics bundles may still contain private data. Android 12 or some ROMs may produce no matching logs; `noEvents`, an unknown reason or a missing `fromUser` is not normal evidence, and unknown must not be treated as `false`. If evidence is insufficient, say so, and do not blame the input method, the app or the system from these events alone.

### Phone control fails
- Check phone control and accessibility status in the diagnostics; not ready or not collected does not mean turned off. Ask the person when information is insufficient; some ROMs turn the accessibility service off by themselves.
- A sensitive page (password/payment) cannot be read because of system policy, not a bug; ask the person to hand off.
- Floating bar misbehaves: ask the person to turn phone control off and on again.
- Several tasks at once: background tasks have a limit, and tasks submitted beyond it queue or are refused; ask the person to wait for the previous one or reduce parallelism.
- To check whether the link works: **Settings → Phone control** has a self-check; act on the item it flags and do not conclude from a different item.
- The live background preview looks frozen or black: confirm non-disruptive mode and the background limit first, then read the `手机操控（本机）` (phone control, local) section of the diagnostics; do not jump to "accessibility is broken".

## 3. Write the feedback (issue draft)

When the person wants to report, give them a draft they can **paste as is**; do not send it for them:

```md
## Environment
- App: <version> (<build number>)
- Device: <vendor model> · Android <version> (SDK <n>)
- Runtime: <bundled version> / <DSH version> / Node <version>, startup mode <proot|direct>
- Connection: <local | remote | not connected>

## What happens
<one or two sentences>

## Steps to reproduce
1. …
2. …

## Expected / actual
…

## Diagnostics
<the relevant sections of the diagnostics file: recent errors, performance, connection; the full bundle is attached>
```

- Copy the environment section from the diagnostics; do not make it up.
- Let the person attach the full diagnostics bundle (zip) to the GitHub issue or send it to the maintainer themselves; it contains engine logs, **never forward it yourself**.
- Remind the person to scan for paths, account names or device names they do not want to publish before pasting.

## 4. Privacy lines

- Diagnostics attempt redaction but cannot guarantee completeness; **paths, device model, account nickname, chat screenshots and logs** may still expose personal information. Before sharing, have the person review them and decide what to keep or cover.
- Never repeat, echo or write tokens, API keys, verification codes or chat bodies verbatim.
- Do not, without asking the person first: change system settings, install or uninstall apps, clear data, or restart the engine.

## 5. When to say "that is enough"

- Diagnostics plus three sentences from the person reproduce the problem → give the draft; do not ask for more logs.
- Only when the diagnostics are missing, the logs do not line up, or it happens only on a particular network/model → ask for the full diagnostics bundle.
- If unsure, say "the current data cannot pin this down" first, then list **one** thing you need next; never five at once.
