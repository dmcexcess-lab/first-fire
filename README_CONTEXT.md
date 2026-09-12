# First Fire — Project Context

> **MANDATORY CONTEXT RULE FOR GPT:** At the start of every new user prompt that requests code or repository changes, fetch and reread both `README_SOPS.md` and this file from current `main`, then inspect the repo state relevant to that prompt. This happens once per coherent prompt/change request.

This file records durable product/design context. `README_SOPS.md` records process, `ARCHITECTURE.md` records module ownership, and `ROADMAP.md` records intended direction. Newest explicit user instruction plus current `main` wins over older context.

## Current game

**First Fire** is a mobile-first Godot 4 / GDScript zombie-apocalypse survivor settlement game combining camp management, extraction-style expeditions, persistent survivor consequences, and portrait turn-based tactical encounters.

Current milestone: **Beta Candidate — Feature Freeze**.

Live Web build: `https://dmcexcess-lab.github.io/first-fire/`

Core navigation: **CAMP | CRAFT | BUILD | SURVIVORS**.

Feature-freeze means deepen/unify existing systems rather than add new pillars.

## Design pillars

- **Simulation first.** Drama comes from interacting systems and persistent state.
- **Survivors are people.** Gear, health, fatigue, stress, relationships, history, wounds, deaths, and a small number of meaningful stats matter.
- **No conventional levels.** Capability comes from three use-based stats, equipment, condition, traits, tactical decisions, and camp infrastructure.
- **Persistent consequences.** Field outcomes feed back into camp/world state.
- **Extraction over extermination.** Survival, rescue, investigation, loot, and escape matter more than clearing every enemy.
- **Low content count, high implementation depth.**
- **Intentional management.** Eating, drinking, sleeping, fun, recovery, and social behavior are systemic where natural; productive chores, maintenance, crafting, building, pet care, and expeditions are deliberately player-assigned.
- **Phone/Web first.** Touch, portrait layout, browser lifecycle, storage, pause/resume, and mobile Safari are architectural inputs.
- **Original presentation.** Avoid third-party franchise identifiers unless explicitly requested and appropriate.

## Three-stat survivor model

The active survivor progression model contains exactly three stats:

- **Combat** — melee/firearm handling and combat output.
- **Agility** — movement, stealth, sprinting, avoidance, and physical escape.
- **Leadership** — camp influence, social decisions, candidate standing, and politics.

The former **Scavenging, Survival, Medical, Technical, and Social** stats are removed from the active survivor model. Do not recreate them as hidden parallel progression systems. Crafting, treatment, searching, scavenging, and technical interactions should instead use authored rules, tools, resources, traits, infrastructure, condition, and player choices where appropriate.

Backgrounds now seed the three current stats rather than six specialist skills. XP/progression is only valid for Combat, Agility, and Leadership.

## Tactical combat

Outside-world danger is tactical/physical. Camp social life/politics remains narrative/dialogue.

Tactical encounters use the actual expedition survivor. Current encounter types are **Rescue, Explore Location, and Ambush**. Rescue calls can now reveal either a stranded survivor or a stranded camp pet (dog/cat); pets use the same physical reach/contact/escort/extract structure. Wounds, deaths, fatigue, stress, ammunition use, and Combat XP return to camp state. Active encounters persist across reloads. Tactical play pauses normal settlement simulation.

The active combat layer is intentionally compact:

- **1H Melee** — faster/lighter one-handed melee profile.
- **2H Melee** — slower/heavier melee profile; the improvised spear retains extended straight-line reach.
- **1H Gun** — pistol class.
- **2H Gun** — shotgun class, including spread behavior.
- **Stealth** — Agility-driven quieter movement with positional stealth-attack opportunity; slower than normal movement.
- **Sprint** — Agility-driven faster movement, louder noise, and improved grab avoidance.
- **Forward** — dedicated touch movement action, now placed in the former Guard control slot for faster thumb access.
- **Shove** — spacing/stagger action; heavier infected resist it more.

**There is no armor mitigation.** Clothing must not cancel or reduce incoming physical damage. Clothing may remain as identity/weight/crafting/utility gear, but it is not an armor stat layer.

Combat and Agility are the only survivor stats that affect tactical fighting/movement. Leadership does not secretly improve attacks.

`FFThreeStatRules.gd` owns the three-stat catalog, weapon classes/profiles, and Agility movement/stealth/sprint math. `FFTacticalBalance.gd` owns tactical tuning using Combat/Agility only. `FFCombatThreeStat.gd` is the active tactical specialization over the established `FFCombat.gd` board/runtime foundation.

## Tactical world

`FFTacticalScenarios.gd` owns objectives/scenario selection. `FFTacticalEnvironments.gd` owns authored places/geometry/props/entries/exits. `FFTacticalLighting.gd` owns tactical lighting rules. `FFTacticalTiles.gd` owns atlas rendering. `FFTacticalTime.gd` owns low-level action-time/load/fatigue/condition timing. `FFTacticalSound.gd` owns labels/localization helpers. `FFTacticalVisuals.gd` owns survivor/infected/weapon rendering.

Authored environments include back alleys, gas stations, houses, apartments, stores, warehouse yards, and drainage washes. Every map now has far-side extraction rather than an exit beside the entry, plus authored physical loot containers (dumpsters, shelves, fridges, crates, vehicles, debris, etc.) whose contents are only retained after escape. Rescue civilians are protected from infected targeting until first contact, then become vulnerable escorts.

Tactical scene lighting uses the actual settlement clock at encounter creation with DAWN / DAY / DUSK / NIGHT phases plus independently powered/unpowered environments. Actual per-cell light now shapes the player's vision cone geometry as well as visibility thresholds: darkness contracts and narrows sight, while bright cells and portable/fixed lighting extend and widen it. Portable Secondary lights can be switched on/off and persist in tactical runtime. Off-screen audible events continue to appear as fuzzy **yellow/gold sound callouts** at approximate locations and disappear when the true source becomes directly visible.

## Expedition logistics

`FFExpeditionRules.gd` owns single-survivor travel/logistics, recruit protection, encounter mix, zone caps, and haul counts. Expeditions are permanently single-survivor; multi-survivor dispatch, companion AI, and vehicles are cut.

Agility is the active survivor stat used for expedition travel pace. Routine loot/searching no longer receives a Scavenging-stat bonus.

The SEND OUT selector uses touch-safe PREV/NEXT controls rather than popup `OptionButton` controls because of mobile Safari behavior. Its modal pauses camp simulation until SEND/CANCEL restores the previous pause state.

## Living camp and camp life

The persistent 2D tactical-style living camp is final camp presentation. `FFCampView.gd` is presentation-only.

The living camp now uses a layered authored presentation rather than a flat grid of isolated symbols: connected dirt paths organize the settlement around the First Fire, sleeping/work/service areas have distinct visual pads, the perimeter reads as a fenced camp with a gate, built structures have stronger purpose-specific silhouettes and shadows, and the fire has visible stonework, flames, smoke, sparks, resource-reflective wood stacking, and stronger clock-driven dusk/night glow. These graphics remain a direct reflection of authoritative `Game` state and do not create separate camp simulation or pathfinding.

`FFCampLifeRules.gd` owns six survivor needs plus pet needs, fire/maintenance tuning, autonomous idle recovery/downtime, and camp cadence. Productive work is player-directed: fire tending, cleaning, perimeter repair, crafting, building, garden work, pet care, and expeditions require assignment. Camp chores and pet care use short touch-first WORK interactions rather than completing as hidden autonomous behavior.

Treatment is physical-wound aware:
- **Hurt:** 1 Sterile Dressing; minor recovery capped to 30s.
- **Wounded:** 1 Sterile Dressing; timed wound care.
- **Critical:** 1 Medicine; timed emergency stabilization to Wounded, after which normal wound care applies.

Disease/illness is not currently part of the survivor condition model and should remain a separate future axis if added.

Treatment time does not depend on a removed Medical stat. Craft/build duration does not depend on a removed Technical stat.

`FFCampSocial.gd` owns relationships, chatter, candidate standing, and politics. **Leadership** is the active progression stat for social/political capability.

## Time / economy

For testing, one full in-game day is **2 real active minutes**.

Fire Pit conversions:
- **1 Raw Food → 2 Cooked Food**
- **1 Dirty Water → 2 Clean Water**

Routine scavenging stays constrained by zone caps/depletion, pack capacity, and authored loot distribution rather than a Scavenging stat.

## Saves

Current save schema remains **7**.

Current survivor-model marker is **`combat-agility-leadership-v1`**. A schema-7 save containing the previous six-skill survivor shape is deliberately invalidated and restarted rather than migrated. This is an intentional compatibility break for the combat/stat reset.

The filename remains `user://first_fire_alpha01.json` intentionally.

`FFSaveCodec.gd` owns JSON/file transport; active state specialization is in `GameThreeStat.gd`, which extends the established `Game.gd` orchestration foundation.

## Canonical technical reality

Canonical Godot source lives directly under `game/`; CI builds that directory directly. Current Web CI uses **Godot 4.7.1** and runs canonical validation, import/parse, architecture smoke, startup smoke, Web export, error-log rejection, Pages artifact upload, and Pages deployment.

The active project seams are:
- `project.godot` autoload → `GameThreeStat.gd`
- `main.tscn` → `MainThreeStat.gd`
- active tactical runtime → `FFCombatThreeStat.gd`
- active survivor inspector → `FFInspectorThreeStat.gd`

These specialize mature base scripts with a small blast radius. Legacy six-skill strings may remain inside inherited base/legacy event code for compatibility while the active runtime exposes only the three current stats. New gameplay must target the three-stat owners rather than revive the legacy model.

## Frozen scope

Pets and active camp work are now part of the approved scope. Vehicles, tactical companion expeditions, multi-survivor dispatch, and 3D camp remain cut. Final population ceiling is **18**. Mature settlement remains **15+ living survivors + every building + an elected leader**, after which the game continues indefinitely.

## Source-of-truth order

1. Newest explicit user instruction
2. Current `main`
3. `README_SOPS.md`
4. `README_CONTEXT.md`
5. `ARCHITECTURE.md`
6. `ROADMAP.md`
7. `CHANGELOG.md`
8. Conversation memory only as supporting context

## Required code-change response footer

At the end of every prompt in which code/repository behavior was changed, include:

- Changelog: `https://github.com/dmcexcess-lab/first-fire/blob/main/CHANGELOG.md`
- Play: `https://dmcexcess-lab.github.io/first-fire/`
