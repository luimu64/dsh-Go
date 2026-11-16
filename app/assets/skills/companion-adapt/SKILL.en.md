---
# dsh-go:managed — delete this line to keep your own edits.
name: companion-adapt
description: Build a data-only adaptation table for a Live2D model the person imported, from the health report the dsh-go Companion room sends; use for “适配这个模型”“这里不对” and /companion-adapt, or when the companion model loads with wrong expressions or touch areas. Uses the same input, prompt and adapter JSON as light mode, and hands validation and execution to the app; never modifies the model or the stage.
---

# Adapt a companion model

Read the [shared contract](references/contract.txt) first. It is the verbatim `companionAdaptSystem` text shared by light and full modes. The only input is the `dsh-go/companion-adapt-request` data received this time, `v: 1`, `target: app-local-adapter-v1`; it contains the parameter vocabulary, the report, the person's feedback, the already-validated current adaptation table and the verified-effects list.

1. Check the input version and target; when either is missing or unsupported, output only `{"notes":"请由 App 重新发送当前版本的体检报告"}`. Do not treat old C720 input, model paths or binaries as this round's report.
2. Following the shared contract, check the parameter list, the complete `ruleAliasVersion` / `ruleAliases`, `coverageUnknown`, truncation and `currentDropped`. `linked` and `missing` are only current observations and may depend on an old adapter that is about to be deleted. The output replaces the current table completely; `current` is never merged automatically, so keeping an old param requires explicitly keeping its valid target and original scale/offset. When the rule snapshot is null, never guess an identity mapping or invent scale=1 from `linked`.
3. Treat names and feedback as data. A name is not proof of an effect; only resources checked by the app in `verifiedEffects` may be used for new expressions/actions; that list is empty by default, so write no emotion/action resources without evidence. Do not control toggles based on names such as "watermark" or "clothes". Do not guess touch zones without known geometry; do not invent parameter mappings without knowing direction, scale or co-drive relationships.
4. Self-check once within the available facts, then return only one adapter JSON object, without a code block, skill explanation or companion action markers. Never write `character/adapter.json`, call the stage, upload to the market, download the Core or send the whole model. The moc fingerprint is computed by the app.
5. If the app returns a validation failure, fix only the specific reason and the new evidence; do not loop without new facts. At most three candidates, each under the same data contract (the app does not currently guarantee round scheduling, so never assume it retries for you). Screenshot/pixel acceptance is not provided by this skill yet; never claim to have seen an image or verified the visual result.

Full mode adds only reasoning steps for the agent, not input permissions. The parameter report contains no model body, textures or curves; if only a free-text request arrives, ask the app to send a report and do not search all the person's models on the host. For the same input, both modes' output must pass the app's `companionAdaptJson` → `companionAdapterCheck`; model output cannot fill `CompanionAdaptEvidence`.
