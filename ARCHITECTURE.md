# First Fire — Architecture

This document records the canonical module boundaries and where feature-freeze work belongs.

## Canonical source

The Godot project is ordinary source under `game/`. There is no active ZIP/patch/Base64 reconstruction chain. Preferred dependency direction is:

**data/catalogs → simulation/rule modules → Game orchestration/state → Main UI/input**

UI may request actions and render state; it should not become authoritative simulation.

## Active runtime layers

First Fire has exactly three survivor progression stats:

- **Combat** — melee/firearm handling, attack reliability, and combat output.
- **Agility** — movement pace, stealth, sprinting, avoidance, and physical escape capability.
- **Leadership** — camp influence, social checks, political standing, and voting strength.

The former Scavenging, Survival, Medical, Technical, and Social stats are no longer player-facing survivor stats. Crafting, treatment, searching, and other noncombat work use tools, resources, traits, infrastructure, state, and authored rules instead of hidden substitute skill trees.

`FFThreeStatRules.gd` owns the canonical stat catalog, weapon-hand classes, class combat profiles, and Agility movement/stealth/sprint math. Active tactical movement preserves a strong crouch > walk > sprint action-cost separation across the full Agility range.

`GameThreeStat.gd` remains the three-stat compatibility/specialization layer over `Game.gd`. It owns survivor generation, progression, three-stat expedition checks, treatment specialization, abstract danger, loot hooks, politics specialization, and the `combat-agility-leadership-v1` compatibility marker.

`GameSleepVirus.gd` is the **active Game autoload**. It extends `GameThreeStat.gd` with the direct five-real-seconds-per-game-hour settlement clock, fixed expedition departure-time advancement, authoritative sleep/work availability, timed survivor training/chores, a separate zombie-virus survivor axis, quarantine/treatment, camp spread, and tactical infected-contact integration. Save schema remains 7.

`MainThreeStat.gd` remains the three-stat UI specialization over `Main.gd`. `MainSleepVirus.gd` is the **active main-scene script** and routes the living camp, inspector, and tactical runtime to their sleep/virus-aware wrappers.

`FFCombatThreeStat.gd` remains the active combat-model specialization over `FFCombat.gd`; `FFCombatVirus.gd` is the final active tactical wrapper and adds direct infected-contact counting plus rescue-extraction ordering protection.

`FFInspectorThreeStat.gd` remains the three-stat survivor/item presentation foundation; `FFInspectorVirus.gd` is the active inspector wrapper and adds zombie-virus status, treatment, quarantine, and medical-item explanations.

`FFCampView.gd` remains the living-camp drawing/motion foundation. `FFCampViewSleepVirus.gd` is the active camp/menu surface: it maps authoritative sleep/treatment/quarantine state, draws at-a-glance mood/need information, provides the zoomed/pannable phone viewport plus problem-state cues, performs touch hit-testing against visible camp entities, and emits navigation/selection intent without mutating simulation state.

## Core owners

### `FFData.gd`
Shared declarative catalogs. Item names, recipes, zones, buildings, backgrounds, and gear data live here. Legacy `protect`, old background skill-bonus fields, or other stale catalog metadata are not authoritative when contradicted by active rules; remove them when a focused cleanup safely owns that data.

### `Game.gd`
Persistent state/orchestration foundation: camp ticks, survivor work assignment, camp-maintenance and pet state, expedition sequencing, event/tactical transitions, and schema-7 state transport shape.

### `GameThreeStat.gd`
Three-stat specialization and compatibility boundary. It keeps the base orchestration usable while ensuring the live survivor model contains only Combat, Agility, and Leadership.

### `GameSleepVirus.gd`
Active settlement orchestration layer. Owns the single direct settlement clock, fixed expedition departure-time advancement through the same camp simulation, authoritative Sleeping status/tasks, centralized assignment availability, zombie-virus state progression, quarantine, timed virus treatment, camp spread, and handoff of tactical infected-contact results into persistent survivor state.

### `Main.gd`
Top-level UI/input foundation: legacy navigation shells, overlays, work board primitives, expedition modal, and shared interaction flow. The active runtime may reuse these mature UI functions without exposing their old standalone tab navigation.

### `MainThreeStat.gd`
Three-stat UI specialization, including the three-stat worker picker and routing foundations.

### `MainSleepVirus.gd`
Active main-scene wrapper and current camp-as-menu controller. It hides the legacy CAMP / CRAFT / BUILD / SURVIVORS tab bar in active play and keeps `current_tab` as an internal compatibility detail only. The living camp remains touch-active at all times outside modal overlays. Physical camp objects open narrow contextual sheets: First Fire → survival crafting, starter Workbench → tool/gear crafting, built structures → contextual details/actions, gate → survivor + destination + LEAVE CAMP, survivor → inspector plus deliberate work assignments, communal storage → communal inventory. Future construction anchors are not rendered as empty placeholders. Those sheets return to the camp rather than becoming parallel top-level menus.

### `FFCampView.gd`
Living 2D camp presentation foundation. Reads authoritative state and maps it to visual stations/cosmetic survivor motion only. It must not own work timing, resources, survivor rules, or pathfinding gameplay.

### `FFCampViewSleepVirus.gd`
Active camp/menu renderer and touch hit-test layer. Owns deterministic visual sleep-slot selection and presentation for Sleeping, training, treatment, chores, pet care, quarantine, severe illness, and mood-driven idle activity. It also owns the sparse wilderness starter presentation and touch locations for survivor selection, communal storage, First Fire, Workbench/built structures, and the camp edge/gate. Unbuilt anchors remain invisible data. Those interactions emit intent signals only; `MainSleepVirus.gd` decides which contextual sheet/overlay to open and `Game` remains authoritative for all simulation changes.

### `FFSurvivorPanel.gd`
Legacy concise roster/dashboard implementation retained as an internal reusable component while camp interaction replaces standalone roster navigation. Detailed current presentation belongs to the active inspector wrapper.

### `FFCombat.gd`
Established tactical board/runtime foundation: map state, actors, infected, vision/fog, facing, sound propagation, doors/glass/hazards, physical loot-container state, objectives, survivor/pet rescue escort state, persistence, and rendering integration.

### `FFCombatThreeStat.gd`
Current combat rules: Combat/Agility attack and movement behavior, Stealth, Sprint, Forward, Shove, weapon-class handling, and no armor mitigation.

### `FFCombatVirus.gd`
Thin active tactical wrapper. Counts successful direct infected attacks against the controlled survivor, persists/returns that count, and prevents a contacted living rescue from being failed merely because the player reaches the exit before the escort's next scheduled movement. It must not treat generic physical damage as virus exposure.

### `FFTacticalBalance.gd`
Pure tactical tuning. Current formulas use Combat and Agility only. Owns infected counts/HP/damage, container search/loot tuning, Shove resistance/stagger, and infected hit chance.

### `FFTacticalTime.gd`
Low-level tactical timeline utilities for load, fatigue, condition, stance, weapon timing, and infected pace. `FFThreeStatRules.gd` applies current Agility-based normal/stealth/sprint movement modifiers on top of those base action costs.

### `FFTacticalScenarios.gd`
Encounter objective/catalog ownership and objective/place pairing. Tactical scene time snapshots the real settlement clock at encounter creation.

### `FFTacticalEnvironments.gd`
Authored physical places, geometry, props, searchable container anchors, entries, and deliberately separated extraction exits. Current families include alley, gas station, house, apartment, store, warehouse yard, and drainage wash.

### `FFTacticalTiles.gd`
Atlas-region lookup and tactical environment/item rendering.

### `FFTacticalLighting.gd`
Ambient profiles, authored/fixed light math, Secondary portable-light profiles, daylight/window behavior, and light-dependent visibility helpers.

### `FFTacticalSound.gd`
Surface-aware labels, bounded fuzzy source estimates, and ambient sound profiles. Tactical propagation/AI state remains in combat runtime.

### `FFTacticalVisuals.gd`
Persistent survivor appearances, infected visual families, rescued-pet rendering, weapons, corpses, impact effects, and tactical character rendering. Presentation only.

### `FFExpeditionRules.gd`
Pure single-survivor expedition/logistics rules: fixed route hours, the two starting routes, explicit future long-range route unlock keys, zone caps, and compatibility haul helpers. Standard Send Out duration is authored and no longer shortened by Agility. Encounter-family weighting belongs to `FFTacticalScenarios.gd`.

### `FFCampLifeRules.gd`
Pure camp-life tuning for survivor needs/moodlets, autonomous idle choice, scheduled midday drinking/evening eating/overnight sleep, awake fatigue and sleep recovery, pet affection/retention/daily reward, authoritative camp-condition degradation/recovery/bands, daily water/meal/sleep-window accounting, recovery/treatment modifiers, defense-building effects, and camp cadence. Idle choices include sleep plus visible mood responses such as checking rations/water, washing, watching the treeline, wandering, and watching the fire. `GameSleepVirus.gd` promotes sleep into the authoritative Sleeping status/task. Productive training, chores, maintenance, crafting, treatment, pet care, and expeditions are player-assigned.

### `FFCampChoreMinigame.gd`
Shared touch-first presentation/controller for the four daily chore interactions. It renders one reusable six-target interaction surface with chore-specific instructions and labels, emits action intents only, and never awards resources or mutates camp state. `MainSleepVirus.gd` pauses/restores settlement simulation around the overlay and forwards intents to authoritative `GameSleepVirus.gd` chore APIs.

### `FFVirusRules.gd`
Pure zombie-virus rules. Owns stage names/normalization, contact-to-exposure probability, daily progression, camp-spread probability, and treatment plans/costs. It does not mutate Game state or render UI.

Current virus stages are **Clear → Exposed → Infected → Feverish**. Exposed can be decontaminated with Clean Water + Sterile Dressing; Infected uses Medicine; Feverish emergency treatment requires Infirmary + 2 Medicine. Quarantine prevents close-contact camp spread. Terminal consequence is applied by Game orchestration after an untreated Feverish daily transition.

### `FFCampSocial.gd`
Relationships, chatter, political standing, and leadership support. **Leadership** is the active progression stat for candidate standing and social/political checks. Active orchestration passes only assignable/available survivors into ordinary chatter selection.

### `FFFieldEventsLegacy.gd`
Temporary remaining outside-world text-event catalog. Outside-world content should continue moving toward tactical/physical play; camp social/political narrative remains valid.

### `FFSaveCodec.gd`
Persistence transport only: JSON/file read-write, compatibility check, invalidation. Current save schema remains 7. The three-stat layer adds the stat-model compatibility marker; virus state is additive and normalized by the active runtime.

### `scripts/ci/FFArchitectureSmoke.gd`
Deterministic pure-rule/source-contract checks. UI/autoload-dependent scripts are compiled by import/startup gates in their real project context; smoke asserts the active wrapper chain plus durable rules such as scheduled eating/drinking/sleep, the single five-real-seconds-per-hour clock, always-tactical Send Out routing, 3h/5h starting routes, survivor training, sparse camp interaction, infected-contact tracking, and virus treatment requirements.

## Camp interaction boundary

The living camp is the primary interaction surface, but it remains a UI layer rather than a second simulation. `FFCampViewSleepVirus.gd` may determine which visible entity/cell was tapped and emit an intent signal. It must not spend resources, assign workers, start expeditions, alter survivor state, or perform crafting/building directly. `MainSleepVirus.gd` routes intent to contextual UI that calls the existing authoritative Game APIs.

The active UI no longer exposes the legacy four-tab bar. A new game visibly starts as wilderness plus four physical essentials: First Fire, a bedroll, communal storage, and a Workbench. First Fire exposes Cook Food, Boil Water, and Sterile Dressing; the Workbench exposes its own recipe catalog. Deliberate survivor work is assigned from the survivor inspector rather than a dedicated management kiosk. Future construction anchors remain invisible until that construction interaction is deliberately reintroduced.

At-a-glance mood/need/virus indicators are derived presentation from existing survivor state. They do not create a second need or mood model.

## Availability boundary

A survivor is assignable only when the active Game layer says so. `GameSleepVirus.survivor_can_assign()` is the canonical current check for worker/equipment availability: living, `Available`, no active task, not quarantined, and not severely ill.

Sleeping, treatment/recovery, crafting, building, garden work, chores, pet care, expeditions, quarantine, and severe virus illness therefore cannot be simultaneously treated as free labor. UI should consume the Game availability API/status rather than inventing exceptions.

## Tactical pause boundary

Tactical encounters pause settlement simulation. Tactical action ticks and settlement time are different scales. Tactical thinking must not consume camp resources, advance building/recovery/virus progression, or trigger unrelated camp events.

Detailed survivor/item inspection also pauses settlement simulation while open and restores the prior pause state on close.

## Settlement time scale

`Game.gd` retains `DAY_SECONDS := 120.0`. Active `GameSleepVirus.gd` has **no simulation-speed multiplier**: real active delta is settlement delta, giving **5 real active seconds = 1 in-game hour** and 120 real active seconds per full in-game day. Needs, fire/maintenance decay, survivor tasks/recovery, camp events, chatter timing, daily transitions, and expedition departure travel all use that same unit. Tactical action ticks remain separate and freeze settlement simulation completely. UI refresh/autosave remain real-time concerns.

## Frozen scope

The living 2D camp is the final presentation and primary home/menu surface. Pets, active camp duties, authoritative sleep, and zombie-virus consequence/treatment depth are approved gameplay. Vehicles, 3D camp rendering, multi-survivor expeditions, and tactical companion AI remain cut. The hard population ceiling is 18; the mature-settlement milestone remains 15+ living survivors + all planned buildings + an elected leader, after which play continues indefinitely.

## Save boundary

Current schema: **7**.

Current survivor-model marker: **`combat-agility-leadership-v1`**.

Current additive virus marker: **`zombie-virus-v1`**.

A schema-7 save carrying the previous six-skill survivor shape is deliberately invalidated and restarted instead of migrated. Virus fields are additive/normalized and do not require a schema reset. Camp-menu interaction/layout is presentation-only and does not change save shape. The filename `user://first_fire_alpha01.json` remains intentionally unchanged.

## Permanent CI gate

Pages CI validates canonical source and the active wrapper files, installs Godot 4.7.1/templates, imports/parses, runs architecture smoke, boots the real project headlessly, exports Web, rejects script/parse/load errors, uploads the Pages artifact, and deploys only after the gates pass.

## Refactor rule

The source razor was a one-time exception. Future cleanup remains local and feature-driven. The current wrapper stack is a deliberate small-blast-radius specialization of mature foundations; fold wrappers into base owners only when a focused change makes that safer than maintaining the seam.