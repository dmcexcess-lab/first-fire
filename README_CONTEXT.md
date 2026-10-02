# First Fire — Project Context

> **MANDATORY CONTEXT RULE FOR GPT:** At the start of every new user prompt that requests code or repository changes, fetch and reread both `README_SOPS.md` and this file from current `main`, then inspect the repo state relevant to that prompt. This happens once per coherent prompt/change request.

This file records durable product/design context. `README_SOPS.md` records process, `ARCHITECTURE.md` records module ownership, and `ROADMAP.md` records intended direction. Newest explicit user instruction plus current `main` wins over older context.

## Current game

**First Fire** is a mobile-first Godot 4 / GDScript zombie-apocalypse survivor settlement game combining a living camp-management home screen, extraction-style expeditions, persistent survivor consequences, and portrait turn-based tactical encounters.

Current milestone: **Beta Candidate — Feature Freeze**.

Live Web build: `https://dmcexcess-lab.github.io/first-fire/`

The **living camp is the primary game/menu surface**. The old CAMP / CRAFT / BUILD / SURVIVORS tab bar is retired from active play rather than preserved as parallel navigation. The phone view is intentionally zoomed and pannable instead of shrinking the whole settlement into a minimap; normal management is reached by touching physical camp entities and opening contextual sheets/overlays from them.

Feature-freeze means deepen/unify existing systems rather than add new pillars.

## Design pillars

- **Simulation first.** Drama comes from interacting systems and persistent state.
- **The camp is the Tamagotchi.** The player watches a small settlement live, identifies what it needs, sends survivors out to bring resources home, and sees the camp physically grow and change.
- **Camp is interface.** Survivors, stations, plots, the communal stash, the fire, work board, buildings, and gate are touch targets in the living camp. Detailed panels are contextual views opened from that world, not top-level menu destinations.
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

`FFExpeditionRules.gd` owns single-survivor route hours, starting-route availability, future long-range unlock flags, zone caps, and expedition logistics. Expeditions remain permanently single-survivor; multi-survivor dispatch and tactical companion AI are cut.

**Every gate Send Out is now tactical.** A normal outing is most often exploration, sometimes a zombie ambush, rarely a stranded survivor, and very rarely a dog/cat rescue. Quiet exploration can contain no infected; all tactical outing families still use physical loot containers, and only loot physically recovered before extraction comes home.

Exactly two routes start unlocked: **Camp Perimeter = 3 in-game hours** and **Nearby Streets = 5 in-game hours**. Farther routes remain visible but locked behind explicit future long-range-travel unlock flags rather than automatically opening after repeated runs. Normal route duration is fixed authored time; Agility no longer shortens Send Out travel.

The camp gate owns expedition preparation end-to-end with touch-safe PREV/NEXT controls. Route time is paid once before the tactical board opens. The tactical board then hard-pauses settlement simulation, so tactical thinking/combat consumes no additional camp time. Previously discovered special sites also launch a tactical map rather than using a passive travel-only branch.

## Living camp and camp life

The persistent 2D tactical-style living camp is both the final camp presentation **and the primary menu/home screen**. `FFCampView.gd` remains the presentation foundation; active camp rendering and interaction route through `FFCampViewSleepVirus.gd` for authoritative sleep/treatment/quarantine placement plus camp touch targets.

The starter camp is intentionally sparse wilderness rather than a pre-laid settlement: grass/brush/trees around a single First Fire, bedroll, communal storage box, and starter Workbench. Future building locations remain code/data only until construction presentation is deliberately reintroduced; there are no visible empty plot placeholders. These graphics read authoritative `Game` state and do not create separate camp simulation or pathfinding.

The active screen no longer presents the legacy CAMP / CRAFT / BUILD / SURVIVORS tab bar. The camp stays touch-active even while a contextual sheet is open. Current in-world routes are:

- tap a **survivor** → full survivor stats/condition/equipment/inventory inspector;
- tap the **communal chest / Storage Crate** → communal resources, components and gear inventory;
- tap the **First Fire** → default Day-1 Fire Pit crafting;
- tap a built **Workbench** or **Sewing Table** → recipes for that station only;
- tap an **empty authored plot** → information/cost/prerequisites and BUILD for that one structure;
- tap a **built structure** → contextual structure information and any active interaction (for example Garden Plot tending);
- tap the **camp work board** → chores, maintenance and pet-care assignment;
- tap the **gate** → survivor/send-out chooser.

The First Fire, communal storage box, sleeping bag, and Workbench are guaranteed in a new game. The fire handles basic survival conversions while the Workbench provides the starter tool/gear crafting surface. Crafting remains physical camp interaction rather than a separate Craft screen.
Crafting cards show explicit owned/required shortages (for example `Raw Food 0/1`) when a recipe cannot be paid, so a disabled action explains itself without requiring a stash detour.

The top camp HUD is the authoritative clock/resource readout. The map title stays intentionally short (`FIRST FIRE CAMP • DAY N`), the idle `RUNNING` label is hidden, and the secondary status line only appears for meaningful states such as an away survivor, tactical encounter, active work, illness, or pause. Routine expedition returns are promoted from transient toast text into a persistent tap-to-dismiss camp return notice carrying the exact haul/empty-handed result.

Survivors carry floating at-a-glance state in the camp: existing need pips remain, while the focused camp adds a compact mood/priority-need/virus badge so hunger, thirst, sleep, fun, safety, hygiene pressure, stress, and infection are readable without opening a roster panel.

Sleep is a real availability state rather than a passive visual label. When autonomous sleep triggers, the survivor enters **Sleeping**, receives a timed sleep task, walks to a deterministic bed/sleep slot in the camp view, lies down visually, and is excluded from worker/expedition/equipment assignment until waking. Existing productive work, treatment, chores, pet care, crafting, building, garden work, expeditions, quarantine, and severe sickness likewise keep survivors unavailable through authoritative statuses/tasks.

`FFCampLifeRules.gd` owns six survivor needs plus pet affection/retention/reward rules, fire/maintenance tuning, idle recovery/downtime, and camp cadence. Pets do not consume camp food or water: Bond/Affection falls without attention, PLAY/LOVE restore it, neglected pets can leave camp, and each pet that stays brings back exactly one random material or Raw Food per in-game day. Productive work is player-directed: camp chores/maintenance, crafting/building, treatment or forced rest, pet care, training, and expeditions require assignment. Eating, drinking, normal sleep, fire-watching, washing, socializing, fun, wandering, and other ordinary camp life remain autonomous. Autonomous needs are real simulation actions rather than end-of-day abstractions: available survivors seek a midday water break, an evening meal, and a real overnight Sleeping task; those actions consume one Clean Water / Cooked Food when available and visibly restore Thirst / Hunger / Fatigue. Awake time builds fatigue instead of passively erasing it, so healthy survivors naturally become tired enough to sleep every night. Assigned work occupies settlement time and can crowd out water, meal, or sleep windows when the player overworks them.

Daily camp chores are intentionally sparse rather than one-per-survivor busywork. Each new settlement day persists exactly **1 or 2 randomly rolled required chores** from the fixed set **Poke Fire, Chop Wood, Clear Area, Stack Supplies**. The physical work board is the single active chore entry point: the player chooses an available survivor and completes a short touch-first interaction, while the assigned task still occupies authored settlement time. Poke Fire improves the First Fire without consuming Wood; Chop Wood produces a bounded +1 Wood; Clear Area and Stack Supplies restore authoritative camp condition. Unfinished required chores add a small condition loss at rollover. Survivors prefer duty to rotate across people who were actually eligible, so the runtime keeps a bounded five-day participation/eligibility seam for later social and political events without forcing everyone to work every day.

Camp condition is persistent settlement state using the existing authoritative `camp_maintenance` score. It degrades through `FFCampLifeRules`, existing cleaning/perimeter work restores it through the same owner, and its derived bands are **Well Kept +1**, **Acceptable 0**, **Neglected -1**, **Poor -2**, and **Severe -3**. The mood effect composes into survivor stress pressure rather than replacing needs. The work-board context exposes the band, modifier and score; Clear Area and Stack Supplies recover that same state, while missed daily chores apply conservative additional neglect. Later visual-degradation work can read the same state without creating a second camp-condition model.

Each living survivor also carries compact current-day activity accounting plus one bounded previous-day summary. The active runtime records assigned work, expeditions, care, autonomous life, and access to authored meal/sleep windows. Work that occupies at least 60% of the daily meal or sleep opportunity records a missed meal/sleep at rollover and applies consequences through the existing Hunger/Fatigue/Stress axes. Free survivors retain autonomous opportunities; tactical pause prevents these counters and camp degradation from advancing.

Camp events remain an important interaction layer, including later settlement politics. In addition to authored social/political choices, occasional physical camp emergencies can interrupt normal camp life with brief touch-first minigames (for example rapidly containing a spreading camp fire). These events should be uncommon enough to feel consequential rather than constant popup maintenance.

Unassigned survivors remain worth watching: their needs can drive sleep, checking food/water, washing, watching the treeline, wandering, watching the fire, fun, and autonomous social chatter.

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

Settlement time has one direct authoritative clock with **no secondary speed multiplier**. `DAY_SECONDS := 120.0` means **5 real active seconds = 1 in-game hour** and **120 real active seconds / 2 minutes per in-game day**. Needs, work/recovery, fire/maintenance, camp events, chatter, daily transitions, and expedition travel all use that same camp-time unit. Standard Send Out pays its fixed route cost before tactical launch: Camp Perimeter consumes 15 settlement seconds / 3 in-game hours and Nearby Streets consumes 25 settlement seconds / 5 in-game hours. Tactical turns are a separate frozen time scale. UI refresh and autosave remain real-time responsiveness concerns.

New games begin with three Cooked Food and three Clean Water so the founder has roughly three daily rations before shortages; scavenging still has to sustain the camp after that.

Fire Pit conversions:
- **1 Raw Food → 2 Cooked Food**
- **1 Dirty Water → 2 Clean Water**

Routine scavenging stays constrained by zone caps/depletion, pack capacity, and authored loot distribution rather than a Scavenging stat.

## Saves

Current save schema remains **7**.

Current survivor-model marker is **`combat-agility-leadership-v1`**. The zombie-virus state is additive survivor data normalized through `FFVirusRules.gd`; active saves receive a `zombie-virus-v1` flag without a schema reset. A schema-7 save containing the previous six-skill survivor shape is still deliberately invalidated and restarted rather than migrated.

The filename remains `user://first_fire_alpha01.json` intentionally.

`FFSaveCodec.gd` owns JSON/file transport. `GameThreeStat.gd` retains the three-stat compatibility layer; active runtime orchestration is `GameSleepVirus.gd`, which extends it with the direct five-real-seconds-per-hour camp clock, fixed expedition departure-time advancement, authoritative sleep/work availability, survivor training, zombie-virus state/treatment/quarantine, and tactical exposure integration.

## Canonical technical reality

Canonical Godot source lives directly under `game/`; CI builds that directory directly. Current Web CI uses **Godot 4.7.1** and runs canonical validation, import/parse, architecture smoke, startup smoke, Web export, error-log rejection, Pages artifact upload, and Pages deployment.

The active project seams are:
- `project.godot` autoload → `GameSleepVirus.gd` → `GameThreeStat.gd` → `Game.gd`
- `main.tscn` → `MainSleepVirus.gd` → `MainThreeStat.gd` → `Main.gd`
- active tactical runtime → `FFCombatVirus.gd` → `FFCombatThreeStat.gd` → `FFCombat.gd`
- active survivor inspector → `FFInspectorVirus.gd` → `FFInspectorThreeStat.gd`
- active living camp/menu renderer → `FFCampViewSleepVirus.gd` → `FFCampView.gd`
- zombie-virus pure rules → `FFVirusRules.gd`

`MainSleepVirus.gd` owns the current camp-only routing/layout. The legacy four-tab nav created by `Main.gd` is hidden by the active wrapper. `FFCampViewSleepVirus.gd` emits camp-object intent; `MainSleepVirus.gd` opens contextual station/build/work/gate sheets or existing inspector/inventory/expedition overlays. The renderer remains non-authoritative and `Game` remains the sole owner of simulation/resource mutation.

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