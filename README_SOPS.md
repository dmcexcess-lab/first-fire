# GPT CODING / GITHUB SOP — FIRST FIRE

> **MANDATORY ENTRY CONDITION FOR GPT:** Before changing code in this repository, fetch and read this file first. Then inspect current `main`, the packaging/patch pipeline, the files that actually feed the build, and the active Pages workflow. Do not code from remembered repository state.

This file exists primarily for ChatGPT. It records the architecture, coding, GitHub, Godot, packaging, testing, and deployment rules learned while building First Fire and Arena with the user.

---

## 0. Core operating principles

1. **Current repo state beats memory.** Fetch first.
2. **Plan for the real platform before implementation.** First Fire is a Godot Web/mobile-first alpha; input, screen space, browser behavior, runtime cost, save shape, and packaging constraints are architectural inputs, not cleanup concerns.
3. **Modularity first.** Every durable system should have one clear owner and a narrow interface so future work changes the smallest possible part of the project.
4. **Small blast radius beats cleverness.** Prefer a local change in one subsystem over a cross-project rewrite, inheritance patch chain, or duplicated rule.
5. **Direct `main` is the normal workflow.** The user prefers fast live testing over PR ceremony.
6. **Batch coherent changes.** Avoid many tiny back-and-forth commits when one well-scoped system pass is safer.
7. **First Fire is not a normal flat Godot source repo.** The deployed project is reconstructed from a base ZIP plus `.deploy` patches/assets. Always inspect the pipeline before deciding what file to edit.
8. **Do not preserve vestigial alpha migrations unless requested.** During alpha, clean schema invalidation is usually preferable to permanent compatibility baggage.
9. **Never claim “compiled” because an export command returned 0.** Godot can package with script errors. Inspect logs and verify the exact final workflow run.
10. **If a change is meant for live testing, verify Pages deployment before saying it is live.**

The standing goal is to avoid future “razor” refactors by putting new code in its durable home the first time.

---

## 1. Required pre-code checklist

Before implementing a new piece:

1. Fetch/read **this file** (`README_SOPS.md`).
2. Fetch current `main` commit/head.
3. Fetch `.github/workflows/pages.yml`.
4. Inspect the relevant `.deploy` patch/source files and base ZIP reconstruction assumptions.
5. Determine where the desired behavior currently lives:
   - `first_fire_alpha01_web_ready.zip`,
   - a `.deploy/*.patch`,
   - an encoded/generated `.deploy` source payload,
   - or a normal tracked file.
6. Identify the subsystem that should **own** the new behavior permanently.
7. Identify its inputs, outputs, state ownership, and the smallest integration surface.
8. Fetch exact current blob SHAs for every persistent repo file to be changed.
9. Choose the GitHub write path before generating a large patch.
10. For risky work, record the last known-good immutable commit SHA before changing `main`.

Never edit a reconstructed `src/...` path as if it were persistent repository source; `src` exists inside CI after unpacking.

---

## 2. Architecture: platform-first and modular by default

### Design for the target platform

Before adding a system, ask:

- Is this primarily simulation, data, presentation, input, persistence, or deployment?
- Does it need to run every frame/tick, only on state change, or only on demand?
- Does mobile Safari/browser input impose a different interaction model than desktop?
- Does the feature need visible mobile controls rather than relying on keyboard-only affordances?
- Does the Web build have a cheaper event/state-driven solution than repeated broad scans?
- What is the save-schema consequence?
- Which persistent reconstruction input should own it?

Do not build a desktop-shaped system and bolt mobile/web support on afterward when the platform requirements are already known.

### One owner per system

A durable rule should have **one authoritative implementation**.

Examples:

- survivor needs/state -> survivor/state module;
- food/water economy -> resource/economy module;
- encounters -> encounter module;
- companion assignment/autonomy -> companion module;
- combat calculations -> combat module;
- save serialization/version -> save module;
- UI -> presentation/input only, not hidden simulation ownership.

Do not duplicate a rule in UI, combat, encounter, and save code just because each caller needs it. Expose one small API and call the owner.

### Dependency direction

Prefer this general direction:

**data/config -> simulation systems -> orchestration/game flow -> UI/input**

Avoid lower-level simulation depending on presentation code. UI should read state and request actions; it should not become the authoritative owner of game rules.

Use signals/events or explicit method calls for narrow communication when appropriate. Avoid giant shared dictionaries being mutated freely by unrelated systems when a smaller contract can do the job.

### Module boundaries

Prefer several durable, responsibility-based modules over:

- one giant god script;
- deep inheritance whose only purpose is patching individual functions;
- many one-off wrapper layers;
- duplicate catalogs/constants in multiple files;
- temporary branches of logic that never get consolidated.

A new module is justified when it owns a real long-lived responsibility. A one-function hotfix is **not** automatically a new architectural layer.

### Stable interfaces

Treat method names, signals, dictionary schemas, save keys, and shared data structures as APIs.

When refactoring internals:

- preserve public contracts when practical;
- change one contract intentionally rather than letting several callers silently diverge;
- use `.get()` fallbacks and explicit conversions for dynamic Dictionary data;
- document schema changes in the save/version logic;
- invalidate alpha saves cleanly when that is simpler than carrying permanent migration baggage.

### Data-driven variation

When many things differ only by values, prefer data tables/config definitions to copied functions.

Creature/item/survivor/encounter differences should usually be data until behavior truly differs. This makes balance changes local and avoids scattering constants across logic.

### Small-blast-radius rule

Before editing, state internally:

1. What subsystem owns the behavior?
2. What is the smallest file/module set that can implement it correctly?
3. Can existing callers stay unchanged?
4. Can the feature be tested at the module boundary?

If a “small feature” requires touching many unrelated systems, stop and inspect the architecture before spreading the change.

---

## 3. Efficiency rules

Efficiency means **simple runtime work + simple maintenance**, not premature micro-optimization.

- Prefer event/state-change work over repeatedly recalculating unchanged state.
- Avoid repeated full-array/full-map scans inside hot loops when a maintained index/count/cache is simpler and reliable.
- Keep simulation deterministic where useful; do not add hidden RNG to benchmark or state-transition logic unless randomness is intended.
- Avoid duplicate derived state. If a value is cheap to derive safely, derive it; if expensive and frequently read, cache it with one clear invalidation path.
- Reuse common helpers instead of cloning similar loops/calculations.
- Keep data definitions separate from execution logic where doing so makes balancing/local changes easier.
- Optimize after identifying an actual hot path; do not make code opaque to save irrelevant instructions.
- Browser/mobile memory and responsiveness matter. Do not accumulate dead objects, unbounded histories, permanent temporary arrays, or needless per-frame allocations.
- Prefer bounded queues/history buffers for transient simulation memory.

Maintainability is part of performance: code that can be changed in one module is cheaper and safer than code requiring project-wide surgery.

---

## 4. Behavior-preserving refactors

Large cleanup passes are **exceptional**, not the normal development strategy.

When cleanup is necessary:

1. Delete code only after proving it is unreachable, fully superseded, or no longer consumed by reconstruction.
2. Preserve public method names, schemas, and state contracts while pruning internals.
3. Do not mix cleanup with balance/design changes unless explicitly requested.
4. Prepare replacements before removing old implementations.
5. Keep the last known-good SHA available as the rollback point.
6. Add/strengthen regression coverage before or with risky structural work.
7. Stop when further cleanup crosses from “proven dead” into “rewrite working behavior.”

Git already stores history. Do not keep obsolete implementations in the runtime merely as historical reference.

---

## 5. First Fire packaging reality

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

**Implication:** a change is only real if it is represented in the persistent inputs this pipeline consumes.

Do not make a beautiful edit to a file/path that CI later overwrites from the ZIP or a patch.

### Modular direction for future First Fire work

Do **not** keep growing giant patches forever.

For a new durable subsystem, prefer this shape when practical:

1. a standalone source module stored as a clear persistent `.deploy` input;
2. one deterministic reconstruction/copy step;
3. one small integration patch in the existing game/orchestration code;
4. assertions that prove the module was reconstructed and connected.

This lets future changes replace one module payload instead of regenerating a huge unrelated patch.

Do not reorganize the entire existing pipeline just to satisfy this ideal. Apply it incrementally to new systems and consolidate old patch fragments only when a normal feature change already touches them safely.

---

## 6. Godot / GDScript best practices

- Be conservative with local `:=` inference on dynamic Variant/Dictionary expressions; prefer explicit types or `=`.
- Prefer explicit `float` / `clampf` where inference is fragile.
- Treat Dictionary schemas as APIs; use stable keys, sensible `.get()` fallbacks, and explicit conversions.
- Keep `_ready()` side effects small and understandable. Initialization-order coupling is fragile.
- Avoid hidden cross-module mutation when an explicit method/event can communicate the change.
- Before adding inheritance, ask whether composition/module ownership fits better.
- Use `super` deliberately and know which implementation it reaches.
- Avoid adding an inheritance layer solely to patch one behavior unless it is a temporary emergency fix with a clear consolidation path.
- Benchmark systems should avoid hidden RNG unless randomness itself is under test.
- If touch/browser behavior changes, inspect project settings and the authoritative mobile-web input path before patching symptoms.

---

## 7. First Fire project rules to preserve unless explicitly changed

- Simulation-first zombie survival/extraction feel.
- No AI director spawning threats to manufacture drama.
- Existing zombies/systems react to physical stimuli and state.
- Persistent consequences matter.
- No player levels as the source of power.
- Survivor capability comes from skills/gear/condition/camp systems.
- Field encounters can pause camp progression when appropriate.
- Companion/survivor systems should be real systems, not alpha fakery, once introduced.
- Low encounter/content count with fully implemented mechanics is preferred over many placeholder events.
- Old save compatibility is not sacred during alpha; schema/system changes may invalidate saves instead of growing vestigial migration logic.
- Idle survivors/rest behavior should be systemic/autonomous rather than needless micromanagement when that is the current design.

---

## 8. Patch-pipeline SOP

When changing gameplay code that originates in the base ZIP:

1. Identify the target reconstructed file (`Game.gd`, `Main.gd`, `FFData.gd`, `FFCombat.gd`, etc.).
2. Determine which persistent `.deploy` patch/payload currently owns that target behavior.
3. Ask whether the new behavior belongs in that owner or deserves a durable standalone module.
4. Modify the persistent patch/payload input, **not** a hypothetical unpacked output.
5. Keep patch order in mind: later patches can overwrite earlier changes.
6. Check the workflow’s existing `grep` assertions; update them intentionally when expected final source changes.
7. Add an assertion for a critical new system when it cheaply proves the reconstructed source contains the intended connection.
8. Avoid accumulating obsolete patch layers. If a new implementation supersedes an old workaround, simplify/remove the old one when safe and already in scope.
9. Reconstruct mentally in workflow order before committing.

For encoded source payloads, prefer reproducible deterministic content. Do not hand-edit base64 unless unavoidable; treat decoded source as the meaningful artifact and verify decoded output.

---

## 9. Large-change implementation order

For a coherent First Fire system pass:

1. Define the behavior enough that implementation is not inventing foundational rules midway through.
2. Choose the permanent owner/module and interface.
3. Update data/constants/config first.
4. Update the owning simulation module second.
5. Update orchestration/integration third.
6. Update encounter/combat exposure only if needed.
7. Update UI/input exposure last; UI should not own the underlying rule.
8. Update save schema/invalidation only as needed; no gratuitous migration framework.
9. Update reconstruction assertions/tests.
10. Remove only obsolete code directly superseded by this same change.
11. Verify persistent repo inputs.
12. Verify exact final-head build and Pages deploy.

Avoid shipping a partial fake pathway just to show a UI button.

---

## 10. GitHub write-path decision tree

### Path A — small/simple change: Contents API

Use `fetch_file` + `update_file` / `create_file` when only one/few modest text files change.

Rules:

1. Fetch current file first.
2. Use returned blob SHA.
3. Update once.
4. If updating the same file again, use the returned `content_sha` or refetch.
5. Never parallel-write the same path.

### Path B — large/coordinated change: Git Data API

For coordinated multi-file work:

1. Fetch current `main` commit/tree.
2. Prepare **all** replacement blobs before moving `main`.
3. Create one tree based on current base tree.
4. Create one commit.
5. Fast-forward `main` once.

Preflight the whole file set before committing so `main` never contains a half-migrated architecture.

Attempt this route once. If a known connector restriction blocks the commit/ref operation, change strategy once rather than retrying equivalent payloads.

### Path C — one-shot Actions installer: fallback only

Use only when normal connector routes are structurally blocked.

Pattern:

1. Prepare final persistent content first.
2. Create one temporary installer workflow.
3. Installer checks out current main and writes only the intended persistent repo inputs.
4. Remove staging artifacts and the installer itself as part of cleanup.
5. Commit once and push.
6. Verify resulting commit/tree.
7. Remember a `GITHUB_TOKEN` push normally does **not** trigger another push workflow.
8. Use one legitimate normal connector-authored persistent follow-up update only if a final Pages trigger is required.
9. Verify the exact final head.

### Stop-thrashing rule

A known structural failure gets **one strategy change**, not repeated equivalent retries.

- payload too large -> stop retrying Contents API;
- Git Data safety/permission block -> switch once;
- stale SHA/409 -> refetch SHA;
- workflow token lacks workflow permission -> do not ask that workflow to rewrite workflows.

Never distort game architecture to satisfy GitHub transport limitations.

### Git hygiene

- Keep the last known-good immutable SHA handy for risky work.
- Prefer coherent commits over many half-complete migrations.
- Never delete the old implementation until its replacement is prepared in the same coherent change.
- Do not leave temporary workflows, encoded staging junk, marker files, or orphaned debug scaffolding.
- Verify the final tree contains only intended persistent files.

---

## 11. Build/deploy verification

First Fire currently does **not** have Arena’s full headless smoke gate/export-log guard. Until it does, be stricter manually.

A First Fire deployment may be called good only when:

1. Fetch final current `main` SHA after all cleanup/docs commits.
2. Find the workflow run for that exact SHA.
3. Build job succeeds.
4. `Unpack and patch First Fire` succeeds, including all reconstruction assertions.
5. `Export Web build` succeeds.
6. For meaningful GDScript changes, inspect export logs and explicitly search for `SCRIPT ERROR`, `Parse Error`, and `Failed to load script` rather than trusting exit code alone.
7. Pages artifact upload succeeds.
8. Deploy job succeeds.
9. No temporary installer/staging files remain in the final tree.

**Recommended hardening:** when next touching CI substantially, add Arena-style export-log rejection and a small First Fire state/startup smoke test before publication. Do it as an intentional CI improvement, not as unrelated churn during a gameplay change.

---

## 12. Regression mindset

Every important bug should teach the project something permanent.

- When practical, add a cheap assertion/test for the failure mode that was just fixed.
- Test module contracts, not only final UI appearance.
- Critical reconstruction steps should have deterministic assertions.
- Manual browser/mobile checks remain necessary for input/layout behavior CI cannot prove.
- A green older commit does not prove a newer cleanup/doc head deployed correctly.

The goal is to make small changes safer over time, reducing the need for giant audits.

---

## 13. GitHub/Actions traps already learned

### Stale file SHA -> 409
Refetch the file and use current SHA. Do not retry stale data.

### Contents API blocks a large write
Change transport; do not repeatedly rename/split arbitrary files just to probe limits.

### Git Data commit/ref is blocked
One structural failure is enough. Use the defined fallback rather than rebuilding the same tree repeatedly.

### Installer push does not trigger Pages
Expected because of `GITHUB_TOKEN` anti-recursion behavior. Trigger once with a legitimate connector-authored persistent update if required.

### Workflow token cannot modify workflow files
Do not include workflow rewrites in an Actions-installer commit unless the token explicitly has the required workflow permission. Update workflow files through the normal connector path.

### Cleanup creates a newer head than the deployed commit
The older successful deployment is not proof of the newer head. Verify the actual final SHA.

### Green Godot export but broken browser
Inspect logs for script parse/load errors before blaming browser cache.

---

## 14. Communication SOP with this user

- Implementation-first, not process-first.
- Keep progress updates short and useful.
- Surface discovered bugs early.
- Avoid unnecessary clarification when current repo/game design resolves the ambiguity.
- Batch related changes rather than ping-ponging tiny commits.
- If the user says “don’t program yet,” do not touch GitHub.
- When design is requested first, produce a concrete enough spec that implementation follows it directly.
- Be transparent about mistakes and connector limits without dumping every low-level operation into chat.

---

## 15. Final self-check before saying “done”

- Did I read this SOP first?
- Did I inspect the actual ZIP/patch reconstruction path?
- Did I identify the permanent subsystem owner before coding?
- Is the change as local/modular as reasonably possible?
- Did I avoid duplicating an existing rule/source of truth?
- Did I fetch current file SHAs?
- Did I choose one GitHub write method and at most one structural fallback?
- Did I avoid leaving temporary workflows/base64/staging junk?
- Did I account for patch ordering?
- Did reconstruction assertions pass?
- Did I inspect Godot output for script errors on meaningful code changes?
- Did the exact final `main` SHA build?
- Did Pages deploy that exact final SHA when live deployment was part of the request?

If any required answer is no, the task is not finished.
