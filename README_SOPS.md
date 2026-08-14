# GPT CODING / GITHUB SOP — FIRST FIRE

> **MANDATORY ENTRY CONDITION FOR GPT:** At the start of every new user prompt that requests code or repository changes, fetch and reread this file and `README_CONTEXT.md` from current `main`, then inspect the repository state relevant to that prompt. This refresh happens **once per prompt/change request**, not before every individual edit, write, or commit within the same coherent batch.

This file records how to work on First Fire safely. `README_CONTEXT.md` records durable product/design context. `ARCHITECTURE.md` records current module ownership. `ROADMAP.md` records intended development.

## 0. Core operating principles

1. **Current repo beats memory.** Fetch first.
2. **Canonical source is `game/`.** Do not reconstruct from historical ZIP/patch/Base64 artifacts; those are gone from the active tree.
3. **Modularity first.** Durable behavior gets one clear owner and narrow interface.
4. **Small blast radius beats cleverness.** Prefer local feature-driven changes over broad rewrites.
5. **Direct `main` is normal.** The user prefers fast live testing over PR ceremony.
6. **Batch coherent changes.** One prompt should normally become one coherent implementation pass, not many tiny ping-pong commits.
7. **Alpha migrations are disposable.** Invalidate incompatible saves rather than carrying vestigial migration code unless preservation is explicitly requested.
8. **Never call a build good from exit code alone.** Verify the permanent CI gates and inspect meaningful Godot logs.
9. **If live testing is part of the request, verify Pages deployed the exact final `main` SHA before saying it is live.**
10. **The project-wide source razor was one-time.** Future refactors are local and feature-driven unless the user explicitly authorizes another structural pass.

## 1. Required pre-code checklist — once per prompt

Before implementing a new code/repo change prompt:

1. Fetch/read `README_SOPS.md`.
2. Fetch/read `README_CONTEXT.md`.
3. Fetch current `main` SHA.
4. Inspect `ARCHITECTURE.md` and `ROADMAP.md` when ownership/direction matters.
5. Inspect `.github/workflows/pages.yml` when build/deployment behavior matters.
6. Inspect the actual canonical `game/` files relevant to the change.
7. Identify the permanent subsystem owner and smallest integration surface.
8. Identify save-schema/platform implications.
9. Fetch current blob SHAs for persistent files to be changed.
10. Choose a GitHub write path before generating large replacements.
11. For risky work, record the last known-good immutable commit SHA.

Do not repeat this checklist between individual edits inside the same prompt unless `main` changes unexpectedly from another actor in a way that affects the work.

## 2. Canonical project reality

The live Godot project is ordinary tracked source:

```text
game/
  project.godot
  export_presets.cfg
  main.tscn
  assets/
  scripts/
```

The historical `first_fire_alpha01_web_ready.zip`, `.deploy` patches, encoded combat payloads, and temporary razor staging are no longer active build inputs. Git history preserves them if archaeology is ever necessary.

A gameplay/code change is real when it is represented directly in canonical `game/` source (plus any intentional repo docs/workflow changes).

## 3. Architecture rules

Read `ARCHITECTURE.md` for the authoritative ownership map.

Preferred dependency direction:

**data/config → simulation/rule modules → Game orchestration/state → UI/input**

Important current owners:

- `FFCombat.gd` — tactical runtime mechanics.
- `FFTacticalVisuals.gd` — tactical character appearance, zombie variation, weapon silhouettes, and character drawing; presentation only.
- `FFTacticalLighting.gd` — tactical day/night/power light profiles, Secondary light-item math, window daylight, and light-dependent sight thresholds.
- `FFTacticalTiles.gd` — tactical sprite/tile atlas-region rendering; physical geometry remains outside presentation.
- `FFTacticalTime.gd` — pure derived tactical action timing from gear load, survivor state, and infected pace/mass.
- `FFTacticalSound.gd` — pure tactical sound labeling/localization helpers; combat owns propagation and reactions.
- `FFTacticalScenarios.gd` — tactical scenario/location/layout selection and future physical field-event definitions.
- `FFExpeditionRules.gd` — travel/logistics/recruit protection/haul rules; vehicle integration seam.
- `FFCampLifeRules.gd` — camp-life cadence/recovery/general camp-state tuning.
- `FFCampSocial.gd` — relationships and future autonomous survivor social behavior.
- `FFSaveCodec.gd` — persistence file/JSON mechanics.
- `FFFieldEventsLegacy.gd` — temporary outside-world text-event selector pending Alpha 0.3 conversion.
- `Game.gd` — persistent state/orchestration facade and fluid Alpha save-state schema.
- `Main.gd` — UI/input/presentation.
- `FFCampView.gd` — living 2D camp presentation using the tactical atlas; survivor positions are visual reflections of authoritative status/task state, never a second simulation.

### One owner per rule

Do not duplicate a durable rule because several callers need it. Expose one API from the owner.

### Data-driven variation

When content differs mostly by values, use catalogs/data rather than copied branches. New tactical locations, encounter variants, pets, vehicles, equipment, etc. should be data-driven until behavior truly differs.

### Compatibility facades

A small forwarding method in `Game.gd` may remain if deleting it would require unrelated caller churn. Label temporary compatibility paths clearly and remove them when the feature touching them naturally makes that safe.

## 4. Roadmap-oriented ownership

Use roadmap seams rather than inventing new architecture ad hoc:

- Alpha 0.3/0.4 outside-world tactical conversion and variety → `FFTacticalScenarios` + `FFCombat`.
- Alpha 0.5 autonomous survivor interaction → `FFCampSocial`, consuming camp/survivor state.
- Camp recovery/vibe/cadence → `FFCampLifeRules`.
- Living camp/menu visualization → `FFCampView`, reading `Game` state only.
- Alpha 0.6 pets → create a real `FFPets` owner only when implementing actual pet behavior; do not add empty placeholder modules.
- Alpha 0.7 vehicles → create a real `FFVehicles` owner for vehicle state when implementing vehicles, feed derived effects into `FFExpeditionRules`, and represent vehicles physically through tactical scenario/runtime state.
- Beta 3D camp → presentation reads simulation state; it does not own it.

The remaining field text-event selector is deliberately legacy. Do not deepen that path; convert events into tactical scenarios instead.

## 5. Platform-first rules

First Fire is phone/Web first.

Before implementation ask:

- Does touch/mobile Safari need a different interaction path?
- Is the UI comfortable at narrow portrait width?
- Does the feature need visible touch controls rather than keyboard-only affordances?
- Does browser lifecycle/storage affect state?
- Can work be event/state-driven rather than a broad per-frame scan?
- Does the feature alter save shape?
- Will the tactical pause boundary still hold?

Do not build desktop-only behavior and bolt mobile support on afterward when requirements are already known.

## 6. Godot / GDScript rules

- Be conservative with `:=` when the right-hand side can be `Variant`/Dictionary data. Prefer explicit types/conversions.
- Prefer typed helpers such as `maxi`, `maxf`, `clampi`, `clampf` when inference could be ambiguous.
- Treat Dictionary schemas, signal names, method names, save keys, and shared state shapes as APIs.
- Keep `_ready()` side effects simple and initialization order understandable.
- Avoid hidden cross-module mutation when an explicit call/event fits.
- Prefer composition/module ownership over inheritance used only to patch one function.
- Keep benchmark/smoke logic deterministic unless randomness is the subject of the test.
- Touch/input changes require checking the authoritative project settings and mobile interaction path.

## 7. Tactical pause boundary

Tactical field encounters pause normal settlement simulation. Tactical turn time and settlement time are separate scales.

While a tactical encounter is active, do not advance unrelated food consumption, construction, survivor recovery, or camp events. Keep this boundary explicit in Game orchestration rather than relying on UI behavior.

## 8. Save policy

Current schema: **6**.

Alpha policy:

- meaningful incompatible structure change → increment schema and invalidate old saves cleanly;
- do not create a general migration framework;
- do not preserve vestigial old fields merely because they existed;
- preserve a current save when a refactor is genuinely behavior/schema-neutral.

The filename `user://first_fire_alpha01.json` is intentionally retained for compatibility even though the project has moved beyond Alpha 0.1. Do not rename it solely for cosmetics.

`FFSaveCodec.gd` owns I/O mechanics; `Game.gd` owns the state dictionary/schema during Alpha.

## 9. Behavior-preserving refactors after the razor

The broad source razor is complete. Do not repeat it by default.

When cleanup is needed:

1. Delete code only when proven unreachable/superseded or when the same feature replaces it.
2. Preserve external contracts when practical.
3. Do not mix unrelated design/balance changes into cleanup.
4. Keep the last known-good SHA for risky work.
5. Add a cheap regression assertion when a bug reveals a reusable invariant.
6. Stop when cleanup crosses from local simplification into rewriting working systems.

Git stores history; runtime source should not keep dead implementations as an archive.

## 10. GitHub write-path decision tree

### Small/modest text changes — Contents API

Use `fetch_file` + `update_file` / `create_file` / `delete_file`.

- Fetch current SHA first.
- Do not parallel-write the same path.
- If writing the same path again, use the returned content SHA or refetch.

### Coordinated multi-file change — Git Data API

Prefer:

1. fetch current `main` commit/tree;
2. prepare all blobs;
3. create one tree based on current tree;
4. create one commit;
5. fast-forward `main` once.

Preflight the set before moving `main`.

### Actions-based repository mutation — emergency fallback only

The one-time razor used a temporary workflow because it had to materialize historical binary/package inputs. That is **not** normal workflow anymore.

Use an Actions writer only if connector limitations make a necessary transformation structurally impossible. Remove it immediately afterward and verify the final tree contains no staging/migration junk.

### Stop-thrashing rule

A structural failure gets one strategy change, not repeated equivalent retries.

## 11. Permanent CI / deploy gate

Current Pages workflow builds canonical `game/` directly.

A change may be called CI-good only when the exact target SHA passes:

1. canonical source validation;
2. Godot 4.7.1 install/templates;
3. **Import and parse Godot project**;
4. **Architecture smoke test** (`FIRST_FIRE_ARCHITECTURE_SMOKE_OK`);
5. **Startup smoke test** of the real main project;
6. **Web export**;
7. log rejection for `SCRIPT ERROR`, `Parse Error`, or `Failed to load script`;
8. Pages artifact upload;
9. Pages deployment.

For meaningful GDScript changes, inspect the build log even when CI is green. A green older SHA does not prove a newer docs/cleanup head is deployed.

Browser/touch/layout behavior still needs human/mobile playtesting; headless CI cannot prove visual usability.

## 12. Regression mindset

Important bugs should leave behind a cheaper future check when practical.

- Add module contract checks to `game/scripts/ci/FFArchitectureSmoke.gd` when appropriate.
- Use deterministic assertions for critical invariants.
- Keep CI fast enough that it remains useful.
- Do not over-test UI appearance through brittle text assertions when a module contract is the real invariant.

## 13. Product rules to preserve unless explicitly changed

- simulation-first zombie survival/extraction feel;
- no AI director spawning threats simply to manufacture drama;
- persistent consequences;
- no conventional player-level power ladder;
- use-based skills, equipment, condition, camp infrastructure;
- outside-world physical events are moving entirely to tactical encounters;
- camp story/politics events remain narrative/dialogue;
- tactical encounters pause settlement simulation;
- survivor social behavior should become autonomous rather than conversation micromanagement;
- pet care should be systemic/autonomous where possible;
- vehicles are expedition/logistics tools and tactical entry/exit anchors, not a driving game;
- low encounter count with deep mechanics beats many fake choices;
- Alpha save compatibility is not sacred;
- no exploitative monetization systems.

## 14. Communication SOP

- Implementation-first, not process-first.
- Keep progress updates short and useful.
- Surface discovered bugs early.
- Avoid unnecessary clarification when current repo/context resolves ambiguity.
- Batch related changes.
- If the user says not to program yet, do not touch GitHub.
- Be transparent about errors and connector limits without narrating every low-level operation.
- Never claim browser gameplay was visually tested unless it actually was.

### Required footer after code-change prompts

At the end of every response completing a prompt in which code/repository behavior was changed, include these links:

**Changelog:** `https://github.com/dmcexcess-lab/first-fire/blob/main/CHANGELOG.md`

**Play:** `https://dmcexcess-lab.github.io/first-fire/`

Keep them at the end of the response.

## 15. Final self-check before saying done

- Did I perform the once-per-prompt SOP/context refresh?
- Did I inspect actual canonical `game/` source?
- Did I choose the correct owner and avoid duplicating a rule?
- Did I account for mobile/Web and save implications?
- Did I use a coherent write path?
- Did I leave no temporary/staging artifacts?
- Did relevant architecture/startup/export gates pass?
- Did I inspect logs for meaningful GDScript changes?
- Did the exact final `main` SHA deploy when live publication was part of the task?
- Did I include changelog + gameplay links at the end of the final response?

If a required answer is no, the task is not finished.
