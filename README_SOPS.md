# GPT CODING / GITHUB SOP — FIRST FIRE

> **MANDATORY ENTRY CONDITION FOR GPT:** Before changing code in this repository, fetch and read this file first. Then inspect current `main`, the packaging/patch pipeline, the files that actually feed the build, and the active Pages workflow. Do not code from remembered repository state.

This file exists primarily for ChatGPT. It records the working habits, GitHub connector behavior, Godot pitfalls, First Fire packaging rules, and deployment SOP learned while building First Fire and Arena with the user.

---

## 0. Operating principles

1. **Current repo state beats memory.** Fetch first.
2. **Direct `main` is the normal workflow.** The user prefers fast live testing over PR ceremony.
3. **Batch coherent changes.** Avoid many tiny back-and-forth commits when a system can be changed in one pass.
4. **First Fire is not a normal flat Godot source repo.** The deployed project is reconstructed from a base ZIP plus `.deploy` patches/assets. Always inspect the pipeline before deciding what file to edit.
5. **Do not preserve vestigial alpha migrations unless requested.** The user explicitly prefers invalidating old saves/systems over accumulating legacy bloat during alpha.
6. **Never claim “compiled” just because an export command returned 0.** Godot can package with script errors. Inspect logs and the exact final workflow run.
7. **If a change is meant for live testing, verify Pages deployment before saying it is live.**

---

## 1. Required pre-code checklist

Before implementing a new piece:

1. Fetch/read **this file** (`README_SOPS.md`).
2. Fetch current `main` commit/head.
3. Fetch `.github/workflows/pages.yml`.
4. Inspect the relevant `.deploy` patch/source files and the base ZIP reconstruction assumptions.
5. Determine whether the desired code currently lives:
   - in `first_fire_alpha01_web_ready.zip`,
   - in a `.deploy/*.patch`,
   - in a `.deploy/*.b64` generated source payload,
   - or as a normal top-level tracked file.
6. Fetch exact current blob SHAs for every file to be changed.
7. Decide the GitHub write path before generating a giant patch.

Never edit a reconstructed `src/...` path as if it were persistent repository source; `src` exists inside CI after unpacking.

---

## 2. First Fire packaging reality

Current Pages workflow is `.github/workflows/pages.yml`.

It currently:

1. Checks out the repo.
2. Requires `first_fire_alpha01_web_ready.zip`.
3. Unpacks it into `src/first_fire_alpha01_web_ready`.
4. Concatenates and applies multiple `.deploy` patch fragments.
5. Reconstructs combat integration from encoded/gzipped payloads.
6. Copies reconstructed `FFCombat.gd` into the unpacked project.
7. Runs multiple `grep` assertions to verify expected game state.
8. Forces `vram_texture_compression/for_mobile=false`.
9. Installs Godot 4.7.1.
10. Exports the reconstructed project to `build/web/index.html`.
11. Uploads and deploys Pages.

**Implication:** a change is only real if it is represented in the inputs that this pipeline consumes.

Do not make a beautiful edit to a file/path that CI later overwrites from the ZIP or a patch.

---

## 3. GitHub write-path decision tree

### Path A — small/simple change: Contents API

Use `fetch_file` + `update_file` / `create_file` when:

- only one/few modest text files change;
- payload size is comfortable;
- a patch fragment or workflow file can be replaced cleanly.

Rules:

1. Fetch current file first.
2. Use returned blob SHA.
3. Update once.
4. If updating the same file again, use the newly returned `content_sha` or refetch.
5. Never parallel-write the same path.

### Path B — large/multi-file change: Git Data API

If a coordinated change touches large patch/source payloads:

1. Fetch current `main` commit/tree.
2. Create blobs.
3. Create a tree based on current base tree.
4. Create one commit.
5. Update `main` ref.

Attempt this route once. If the connector blocks the commit/ref operation, **do not keep retrying near-identical variants**. Switch once to Path C.

### Path C — one-shot Actions installer: fallback only

Use when connector write limits block the intended patch.

Pattern:

1. Prepare final content/blob(s).
2. Create one temporary installer workflow.
3. Installer checks out main, writes/reconstructs the intended persistent repo inputs, removes staging files and removes itself, commits once, pushes to main.
4. Verify installer success and resulting commit.
5. Remember: a workflow push using `GITHUB_TOKEN` normally does **not** trigger another push workflow.
6. Therefore use one normal connector-authored persistent follow-up update to trigger Pages (prefer a legitimate changelog/version/SOP/doc update already part of the change; avoid disposable markers).
7. Verify final exact-head deployment.

### Stop-thrashing rule

A known structural failure gets **one strategy change**, not a dozen retries.

- Payload too large -> stop retrying Contents API.
- `create_commit` safety block -> stop rebuilding the same tree; move to installer.
- stale SHA/409 -> refetch SHA; do not retry stale data.

Do not redesign game architecture solely because a connector transport method failed.

---

## 4. Build/deploy verification

First Fire currently does **not** have Arena’s explicit grep guard that rejects `SCRIPT ERROR`, `Parse Error`, and `Failed to load script` from the Godot export log.

Until that workflow is hardened, be stricter manually.

A First Fire deployment may be called good only when:

1. Fetch final current `main` SHA after all cleanup/docs commits.
2. Find the workflow run for that exact SHA.
3. Build job is successful.
4. `Unpack and patch First Fire` succeeded, including all existing grep assertions.
5. `Export Web build` succeeded.
6. Inspect export logs when making non-trivial GDScript changes; explicitly search for script/parse/load errors rather than trusting exit code alone.
7. Pages artifact upload succeeded.
8. Deploy job succeeded.
9. No temporary installer/staging files remain in final tree.

**Recommended future hardening:** mirror Arena’s export-log guard in First Fire. Until done, manual log inspection is mandatory for meaningful script changes.

---

## 5. Godot/GDScript lessons shared with Arena

1. Godot 4.7.1 can be stricter about local type inference than expected.
2. Avoid fragile `:=` inference on dynamic Variant/dictionary expressions; use explicit type or `=`.
3. Prefer `clampf` / explicit float typing for float clamp work.
4. Export success alone does not prove scripts parsed.
5. Deep dynamic dictionaries need defensive `.get(...)` use and explicit conversions.
6. If touch/browser behavior changes, inspect both project settings and the actual mobile-web input path before patching symptoms.

---

## 6. First Fire project rules to preserve unless explicitly changed

- Simulation-first zombie survival/extraction feel.
- No AI director spawning threats to manufacture drama.
- Existing zombies/systems should react to physical stimuli and state.
- Persistent consequences matter.
- No player levels as the source of power.
- Survivor capability comes from skills/gear/condition/camp systems.
- Field encounters can pause camp progression when appropriate.
- Companion/survivor systems should be real systems, not alpha fakery, once introduced.
- User prefers low encounter/content count with fully implemented mechanics over many placeholder events.
- Old save compatibility is not sacred during alpha; when schema/system direction changes, invalidation is often preferred to vestigial migration logic.
- Idle survivors/rest behavior should be systemic/autonomous rather than requiring needless micromanagement when that is the current design.

---

## 7. Patch-pipeline SOP

When changing gameplay code that originates in the base ZIP:

1. Identify the target file after reconstruction (`Game.gd`, `Main.gd`, `FFData.gd`, `FFCombat.gd`, etc.).
2. Determine which current `.deploy` patch/payload is responsible for that target.
3. Modify the persistent patch/payload input, **not** a hypothetical unpacked output.
4. Keep patch order in mind: later patches can overwrite earlier changes.
5. Check the workflow’s existing `grep` assertions; update them intentionally if the expected final source changes.
6. Add a new assertion for a critical new system when it cheaply proves the reconstructed source contains the intended change.
7. Avoid accumulating obsolete patch layers. If a new patch supersedes an old alpha workaround, simplify/remove the old one when safe.
8. Reconstruct mentally in workflow order before committing.

For encoded source payloads, prefer reproducible, deterministic content. Do not hand-edit base64 unless unavoidable; treat the decoded source as the meaningful artifact and verify decoded output.

---

## 8. Large-change packaging SOP

For a coherent First Fire pass:

1. Define the system behavior completely enough that coding is not inventing core rules halfway through.
2. Update data/constants first.
3. Update simulation/game-state logic second.
4. Update encounter/combat layer third.
5. Update UI/control exposure fourth.
6. Update save schema/invalidation only as needed; no gratuitous migration framework.
7. Update reconstruction assertions.
8. Check for dead/obsolete patch fragments.
9. Verify final persistent inputs in repo.
10. Verify exact final-head build and Pages deploy.

Avoid shipping a partial fake pathway just to show a UI button.

---

## 9. GitHub/Actions traps already learned

### Stale file SHA -> 409

Refetch the file and use current SHA. Do not retry with stale SHA.

### Contents API blocks a large write

Switch paths; do not repeatedly rename/split arbitrary files only to probe limits.

### Git Data commit/ref is blocked

One failure is enough. Use the one-shot installer fallback.

### Installer push does not trigger Pages

Expected because of `GITHUB_TOKEN` anti-recursion behavior. Trigger Pages once with a normal connector-authored persistent update.

### Cleanup creates a newer head than the deployed commit

The older successful deployment is not proof of the newer head. Trigger/verify final head again or explicitly disclose the mismatch.

### Green Godot export but broken browser

Inspect logs for script parse/load errors before blaming browser cache.

---

## 10. Communication SOP with this user

- Implementation-first, not process-first.
- Keep progress updates short and useful.
- Surface discovered bugs early.
- Avoid unnecessary clarification when current repo/game design resolves the ambiguity.
- Batch related changes rather than ping-ponging tiny commits.
- If the user says “don’t program yet,” do not touch GitHub.
- When design is requested first, produce a concrete enough spec that implementation can follow it directly.
- Be transparent about mistakes and connector limits without dumping every low-level operation into chat.

---

## 11. Final self-check before saying “done”

- Did I read this SOP first?
- Did I inspect the actual ZIP/patch reconstruction path?
- Did I fetch current file SHAs?
- Did I choose one GitHub write method and at most one fallback?
- Did I avoid leaving temporary workflows/base64/staging junk?
- Did I account for patch ordering?
- Did all reconstruction assertions pass?
- Did I inspect Godot output for script errors on meaningful code changes?
- Did the exact final `main` SHA build?
- Did Pages deploy that exact final SHA?

If any answer is no, the task is not finished.
