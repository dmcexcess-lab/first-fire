# First Fire — Project Context

> **MANDATORY CONTEXT RULE FOR GPT:** At the start of every new user prompt that requests code or repository changes, fetch and reread both `README_SOPS.md` and this file from current `main`, then inspect the repo state relevant to that prompt. This happens once per coherent prompt/change request.

This file records durable product/design context. `README_SOPS.md` records process, `ARCHITECTURE.md` records module ownership, and `ROADMAP.md` records intended direction. Newest explicit user instruction plus current `main` wins over older context.

## Current game

**First Fire** is a mobile-first Godot 4 / GDScript zombie-apocalypse survivor settlement game combining a living camp-management home screen, extraction-style expeditions, persistent survivor consequences, and portrait turn-based tactical encounters.

Current milestone: **Beta Candidate — Feature Freeze**.

Live Web build: `https://dmcexcess-lab.github.io/first-fire/`

The **living camp is the primary game/menu surface**. The CAMP / CRAFT / BUILD / SURVIVORS controls remain as shortcuts and detail screens, but normal play should begin from the camp itself rather than from disconnected menu pages.

Feature-freeze means deepen/unify existing systems rather than add new pillars.

## Design pillars

- **Simulation first.** Drama comes from interacting systems and persistent state.
- **The camp is the Tamagotchi.** The player watches a small settlement live, identifies what it needs, sends survivors out to bring resources home, and sees the camp physically grow and change.
- **Camp is interface.** Survivors, stations, plots, the communal stash, the fire, and the gate are touch targets in the living camp. Detailed panels are contextual views opened from that world.
- **Survivors are people.** Gear, health, fatigue, stress, relationships, history, wounds, infection, deaths, and a small number of meaningful stats matter.
- **No conventional levels.** Capability comes from three use-based stats, equipment, condition, traits, tactical decisions, and camp infrastructure.
- **Persistent consequences.** Field outcomes feed back into camp/world state.
- **Extraction over extermination.** Survival, rescue, investigation, loot, and escape matter more than clearing every enemy.
- **Low content count, high implementation depth.**
- **Intentional management.** Eating, drinking, sleeping, fun, recovery, and social behavior are systemic where natural; productive chores, maintenance, crafting, building, pet care, treatment choices, quarantine, and expeditions are deliberate assignments/decisions.
- **Phone/Web first.** Touch, portrait layout, browser lifecycle, storage, pause/resume, and mobile Safari are architectural inputs.
- **Original presentation.** Avoid third-party franchise identifiers unless explicitly requested and appropriate.

## Three-stat survivor model

The active survivor progression model contains exactly three stats:

- **Combat** — melee/firearm handling and combat output.
- **Agility** — movement, stealth, sprinting, avoidance, and physical escape.
- **Leadership** — camp influence, social decisions, candidate standing, and politics.

The former **Scavenging, Survival, Medical, Technical, and Social** stats are removed from the active survivor model. Do not recreate them as hidden parallel progression systems. Crafting, treatment, searching, scavenging, and technical interactions should instead use authored rules, tools, resources, traits, infrastructure, condition, and player choices where appropriate.

Backgrounds seed the three current stats rather than six specialist skills. XP/progression is only valid for Combat, Agility, and Leadership.

## Tactical combat

Outside-world danger is tactical/physical. Camp social life/politics remains narrative/dialogue.

Tactical encounters use the actual expedition survivor. Current encounter types are **Rescue, Explore Location, and Ambush**. Rescue calls can reveal either a stranded survivor or a stranded camp pet (dog/cat); pets use the same physical reach/contact/escort/extract structure. Wounds, zombie-virus exposure, deaths, fatigue, stress, ammunition use, and Combat XP return to camp state. Active encounters persist across reloads. Tactical play pauses normal settlement simulation.

The active combat layer is intentionally compact:

- **1H Melee** — faster/lighter one-handed melee profile.
- **2H Melee** — slower/heavier melee profile; the improvised spear retains extended straight-line reach.
- **1H Gun** — pistol class.
- **2H Gun** — shotgun class, including spread behavior.
- **Stealth** — Agility-driven quieter crouched movement with positional stealth-attack opportunity; its tactical action cost is deliberately and materially slower than walking.
- **Sprint** — Agility-driven movement with a deliberately and materially lower action cost than walking, louder noise, and improved grab avoidance.
- **Forward** — dedicated touch movement action in the former Guard control slot.
- **Shove** — spacing/stagger action; heavier infected resist it more.

**There is no armor mitigation.** Clothing must not cancel or reduce incoming physical damage. Clothing may remain as identity/weight/crafting/utility gear, but it is not an armor stat layer.

Combat and Agility are the only survivor stats that affect tactical fighting/movement. Leadership does not secretly improve attacks.

`FFThreeStatRules.gd` owns the three-stat catalog, weapon classes/profiles, and Agility movement/stealth/sprint math. `FFTacticalBalance.gd` owns tactical tuning using Combat/Agility only. `FFCombatThreeStat.gd` remains the combat-model specialization over the established `FFCombat.gd` board/runtime foundation; active play routes through `FFCombatVirus.gd`, which adds direct infected-contact tracking for virus exposure without changing physical damage rules.

## Tactical world

`FFTacticalScenarios.gd` owns objectives/scenario selection. `FFTacticalEnvironments.gd` owns authored places/geometry/props/entries/exits. `FFTacticalLighting.gd` owns tactical lighting rules. `FFTacticalTiles.gd` owns atlas rendering. `FFTacticalTime.gd` owns low-level action-time/load/fatigue/condition timing. `FFTacticalSound.gd` owns labels/localization helpers. `FFTacticalVisuals.gd` owns survivor/infected/weapon rendering.

Authored environments include back alleys, gas stations, houses, apartments, stores, warehouse yards, and drainage washes. Every map has far-side extraction rather than an exit beside the entry, plus authored physical loot containers whose contents are only retained after escape. Rescue civilians are protected from infected targeting until first contact, then become vulnerable escorts. On extraction, a contacted living rescue may catch up to a player holding the exit instead of being abandoned solely because the player reached the exit one tactical step first.

Tactical scene lighting uses the actual settlement clock at encounter creation with DAWN / DAY / DUSK / NIGHT phases plus independently powered/unpowered environments. Actual per-cell light shapes the player's vision cone geometry as well as visibility thresholds: darkness contracts and narrows sight, while bright cells and portable/fixed lighting extend and widen it. Portable Secondary lights can be switched on/off and persist in tactical runtime. Off-screen audible events continue to appear as fuzzy **yellow/gold sound callouts** at approximate locations and disappear when the true source becomes directly visible.

## Expedition logistics

`FFExpeditionRules.gd` owns single-survivor travel/logistics, recruit protection, encounter mix, zone caps, and haul counts. Expeditions are permanently single-survivor; multi-survivor dispatch, companion AI, and vehicles are cut.

Agility is the active survivor stat used for expedition travel pace. Routine loot/searching no longer receives a Scavenging-stat bonus.

The SEND OUT selector uses touch-safe PREV/NEXT controls rather than popup `OptionButton` controls because of mobile Safari behavior. Its modal pauses camp simulation until SEND/CANCEL restores the previous pause state.

The camp gate and survivor inspector are the intended in-world routes into expedition preparation; the Survivors shortcut remains available for direct roster access.

## Living camp and camp life

The persistent 2D tactical-style living camp is both the final camp presentation **and the primary menu/home screen**. `FFCampView.gd` remains the presentation foundation; active camp rendering and interaction route through `FFCampViewSleepVirus.gd` for authoritative sleep/treatment/quarantine placement plus camp touch targets.

The living camp uses connected dirt paths, distinct sleeping/work/service areas, a fenced perimeter and gate, purpose-specific structures, and a resource-reflective First Fire. These graphics read authoritative `Game` state and do not create separate camp simulation or pathfinding.

On the focused CAMP screen, the living camp expands to occupy the main play area. The player can tap a survivor to open the detailed survivor/inventory inspector; tap the communal chest to open communal inventory; tap built crafting stations to open crafting; tap an empty authored building plot to open BUILD; tap the First Fire to open camp duties; and tap the gate to move into survivor/send-out flow. The old tab screens remain supporting detail/shortcut surfaces rather than the conceptual center of the game.

Survivors carry floating at-a-glance state in the camp: existing need pips remain, while the focused camp adds a compact mood/priority-need/virus badge so hunger, thirst, sleep, fun, safety, hygiene pressure, stress, and infection are readable without opening a roster panel.

Sleep is a real availability state rather than a passive visual label. When autonomous sleep triggers, the survivor enters **Sleeping**, receives a timed sleep task, walks to a deterministic bed/sleep slot in the camp view, lies down visually, and is excluded from worker/expedition/equipment assignment until waking. Existing productive work, treatment, chores, pet care, crafting, building, garden work, expeditions, quarantine, and severe sickness likewise keep survivors unavailable through authoritative statuses/tasks.

`FFCampLifeRules.gd` owns six survivor needs plus pet affection/retention/reward rules, fire/maintenance tuning, idle recovery/downtime, and camp cadence. Pets do not consume camp food or water: Bond/Affection falls without attention, PLAY/LOVE restore it, neglected pets can leave camp, and each pet that stays brings back exactly one random material or Raw Food per in-game day. Productive work is player-directed: fire tending, cleaning, perimeter repair, crafting, building, garden work, pet care, and expeditions require assignment. Camp chores and pet care use short touch-first WORK interactions.

Physical trauma and zombie virus are separate health axes.

Physical wound treatment:
- **Hurt:** 1 Sterile Dressing; minor recovery capped to 30s.
- **Wounded:** 1 Sterile Dressing; timed wound care.
- **Critical:** 1 Medicine; timed emergency stabilization to Wounded, after which normal wound care applies.

Zombie virus:
- Only successful direct infected contact can create field exposure; generic damage does not.
- Exposure chance rises with repeated direct infected hits during the encounter.
- **Exposed:** can be decontaminated with 1 Clean Water + 1 Sterile Dressing; untreated exposure gets one 30% natural-clear chance, otherwise becomes Infected at the next daily transition.
- **Infected:** 1 Medicine starts a timed treatment course; untreated infection becomes Feverish at the next daily transition.
- **Feverish:** survivor is automatically unavailable; emergency treatment requires a built Infirmary + 2 Medicine. An untreated feverish case can become terminal at the next daily transition.
- **Quarantine:** available for any active virus stage when the survivor is otherwise free; it makes the survivor unavailable and prevents close-contact camp spread. Unquarantined Infected/Feverish survivors can expose campmates.

Virus treatment is timed and visible in the survivor inspector/camp view. Completing a virus course clears the virus axis without rewriting the physical wound condition ladder. Medicine therefore has distinct roles in Critical trauma stabilization and established/severe viral treatment.

Treatment time does not depend on a removed Medical stat. Craft/build duration does not depend on a removed Technical stat.

`FFCampSocial.gd` owns relationships, chatter, candidate standing, and politics. **Leadership** is the active progression stat for social/political capability. Sleeping, quarantined, sick, and otherwise busy survivors are not selected for normal available-survivor chatter.

## Time / economy

Settlement simulation runs at **half the previous real-time speed** through the active orchestration layer. The base day remains 120 simulation seconds, but a full in-game day takes about **4 real active minutes** instead of 2. Camp needs, work/recovery, expeditions, fire/maintenance decay, camp events, and daily transitions all use the slowed simulation delta. UI refresh and autosave cadence remain real-time responsiveness concerns rather than simulation balance.

Fire Pit conversions:
- **1 Raw Food → 2 Cooked Food**
- **1 Dirty Water → 2 Clean Water**

Routine scavenging stays constrained by zone caps/depletion, pack capacity, and authored loot distribution rather than a Scavenging stat.

## Saves

Current save schema remains **7**.

Current survivor-model marker is **`combat-agility-leadership-v1`**. The zombie-virus state is additive survivor data normalized through `FFVirusRules.gd`; active saves receive a `zombie-virus-v1` flag without a schema reset. A schema-7 save containing the previous six-skill survivor shape is still deliberately invalidated and restarted rather than migrated.

The filename remains `user://first_fire_alpha01.json` intentionally.

`FFSaveCodec.gd` owns JSON/file transport. `GameThreeStat.gd` retains the three-stat compatibility layer; active runtime orchestration is `GameSleepVirus.gd`, which extends it with half-speed camp simulation, authoritative sleep availability, zombie-virus state/treatment/quarantine, and tactical exposure integration.

## Canonical technical reality

Canonical Godot source lives directly under `game/`; CI builds that directory directly. Current Web CI uses **Godot 4.7.1** and runs canonical validation, import/parse, architecture smoke, startup smoke, Web export, error-log rejection, Pages artifact upload, and Pages deployment.

The active project seams are:
- `project.godot` autoload → `GameSleepVirus.gd` → `GameThreeStat.gd` → `Game.gd`
- `main.tscn` → `MainSleepVirus.gd` → `MainThreeStat.gd` → `Main.gd`
- active tactical runtime → `FFCombatVirus.gd` → `FFCombatThreeStat.gd` → `FFCombat.gd`
- active survivor inspector → `FFInspectorVirus.gd` → `FFInspectorThreeStat.gd`
- active living camp/menu renderer → `FFCampViewSleepVirus.gd` → `FFCampView.gd`
- zombie-virus pure rules → `FFVirusRules.gd`

`MainSleepVirus.gd` owns the current camp-as-menu routing/layout: the focused CAMP view expands and consumes touch signals emitted by `FFCampViewSleepVirus.gd`, then opens existing inspector/inventory/craft/build/survivor flows. The renderer remains non-authoritative; it emits intent only.

These wrappers keep the blast radius small while preserving the mature three-stat/camp/tactical foundations. Legacy six-skill strings may remain inside inherited base/legacy event code for compatibility while active runtime exposes only the three current stats. New gameplay must target the active wrapper seam or the correct underlying owner rather than revive the legacy model.

## Frozen scope

Pets, active camp work, authoritative sleep, zombie-virus consequences/treatment, and the living camp as the primary menu surface are part of the approved final-system depth. Vehicles, tactical companion expeditions, multi-survivor dispatch, and 3D camp remain cut. Final population ceiling is **18**. Mature settlement remains **15+ living survivors + every building + an elected leader**, after which play continues indefinitely.

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