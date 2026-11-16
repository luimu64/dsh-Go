---
# dsh-go:managed — the dsh-go app keeps this skill up to date; delete this line to keep your own edits.
name: dsh-go-guide
description: The dsh-go phone app's own user guide for HarmonyOS (English / 中文). Load it first when the person asks how to use the dsh-go app itself — where a feature is, what a setting does, what a deletion or reset removes — for example 「系统操作能做什么」「怎么接入自己的模型」「本机环境能卸载吗」「分享链接怎么删」「酒馆怎么导入角色卡」「子代理和智能体团队在哪」「终端怎么开」「全部功能里有什么」「创意工坊怎么投稿」「宠物不见了」. Covers chat, models, engine and remote hosts, system actions, web mode, pets, companion, workshop, sharing, plugins, tavern, subagents and agent teams, terminal, workspaces, automations and settings.
whenToUse: The person asks how to use the dsh-go app (手机 App) itself. Not for changing the app's layout (dsh-go-ui) or writing a plugin (dsh-go-plugin).
---

# dsh-go user guide (HarmonyOS)

The pages are in this skill folder: `README.md`, `zh/`, `en/`. Read them as needed.

1. Read `README.md` first: the supported version and what each page covers. Then read only the one or two pages relevant to the question: read `zh/` when the person speaks Chinese and `en/` otherwise, and answer in the person's language.
2. Answer only from the guide. Write paths and button names exactly as the pages do; when the guide does not cover something, say so plainly — do not guess, invent, or substitute the web version or another app's practice.
3. Lead with the conclusion, then the entry point and steps; keep it as short as possible.
4. When an entry line carries a `dshgo://open/…` link, include it verbatim in the answer, for example `[Open system actions](dshgo://open/system-actions)`, so the person can tap straight through. Use only links that appear in the guide.
5. For deletion, reset, uninstall, granting permissions or loosening confirmation, explain the consequences first: what is deleted, what is kept, and whether it can be undone.
6. Read only, never change: do not change settings, run commands, operate the phone, or install or uninstall anything for the person. If they ask you to make the change directly, tell them where to do it.
7. If the person's app version (under Settings → Version) differs from the version the README applies to, or a description does not match the interface, say the interface may have been updated and the app is authoritative.
8. This guide describes the HarmonyOS version. When the person asks about Android-only features such as phone control, accessibility, the floating bar or a pet outside the app, say plainly that HarmonyOS has no such feature and point to the replacement where one exists (system actions replace phone control); do not answer with Android's procedure.
