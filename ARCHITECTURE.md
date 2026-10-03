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

`FFThreeStatRules.gd` owns the canonical stat catalog, authoritative weapon damage/range/pattern ladder, weapon-hand classes, and Agility movement/stealth/sprint math. Weapon tier owns raw damage/kill count while Combat primarily changes attack reliability. Active tactical movement preserves a strong crouch > walk > sprint action-cost separation across the full Agility range.

`GameThreeStat.gd` remains the three-stat compatibility/specialization layer over `Game.gd`. It owns survivor generation, progression, three-stat expedition checks, treatment specialization, abstract danger, loot hooks, politics specialization, and the `combat-agility-leadership-v1` compatibility marker.

`GameSleepVirus.gd` is the **active Game autoload**. It extends `GameThreeStat.gd` with the direct five-minute settlement day, live post-tactical Away timers, authoritative sleep/work availability, timed survivor training/chores, a separate zombie-virus survivor axis, quarantine/treatment, camp spread, and tactical infected-contact integration. Save schema is 8 after the deliberate camp-progression reset.

`MainThreeStat.gd` remains the three-stat UI specialization over `Main.gd`. `MainSleepVirus.gd` is the **active main-scene script** and routes the living camp, inspector, and tactical runtime to their sleep/virus-aware wrappers.

`FFCombatThreeStat.gd` remains the active combat-model specialization over `FFCombat.gd`; `FFCombatVirus.gd` is the final active tactical wrapper and records successful Bite hits for lead/companion virus exposure plus rescue-extraction ordering protection. Scratches never enter the virus pipeline.

`FFInspectorThreeStat.gd` remains the three-stat survivor/item presentation foundation; `FFInspectorVirus.gd` is the active inspector wrapper and adds zombie-virus status, treatment, quarantine, and medical-item explanations.

`FFCampView.gd` remains the living-camp drawing/motion foundation. `FFCampViewSleepVirus.gd` is the active camp/menu surface: it maps authoritative sleep/treatment/quarantine state, draws at-a-glance mood/need information, provides the zoomed/pannable phone viewport plus problem-state cues, performs touch hit-testing against visible camp entities, and emits navigation/selection intent without mutating simulation state.

## Core owners

### `FFData.gd`
Shared declarative catalogs. Item names, recipes, zones, buildings, backgrounds, gear data, and the Bandage / rare First Aid Kit / Zombie Corpse → Zombie Cure medical supply ladder live here. Legacy `protect`, old background skill-bonus fields, or other stale catalog metadata are not authoritative when contradicted by active rules; remove them when a focused cleanup safely owns that data.

### `Game.gd`
Persistent state/orchestration foundation: camp ticks, survivor work assignment, duplicate-safe construction assignment, tiered shelter capacity, camp-maintenance and pet state, expedition sequencing, event/tactical transitions, **gear condition plus 4/6/8 carry-cap data**, and schema-8 state transport shape.

### `GameThreeStat.gd`
Three-stat specialization and compatibility boundary. It keeps the base orchestration usable while ensuring the live survivor model contains only Combat, Agility, and Leadership.

### `GameSleepVirus.gd`
Active settlement orchestration layer. Owns the single direct settlement clock, normal resumed camp simulation while post-tactical expeditions remain Away on their route timers, authoritative Sleeping and **Exhausted 3–5h forced-rest** status/tasks, **natural idle fatigue recovery**, centralized assignment availability, zombie-virus state progression, quarantine, timed virus treatment, camp spread, and handoff of tactical infected-contact results into persistent survivor state.

### `Main.gd`
Top-level UI/input foundation: legacy navigation shells, overlays, work board primitives, expedition modal, and shared interaction flow. The active runtime may reuse these mature UI functions without exposing their old standalone tab navigation.

### `MainThreeStat.gd`
Three-stat UI specialization, including the three-stat worker picker and routing foundations.

### `MainSleepVirus.gd`
Active main-scene wrapper and current camp-as-menu controller. It hides the legacy CAMP / CRAFT / BUILD / SURVIVORS tab bar in active play and keeps `current_tab` as an internal compatibility detail only. The living camp remains touch-active at all times outside modal overlays. Physical camp objects open narrow contextual sheets: First Fire/Tavern → hearth crafting, built Workbench/Sewing Table/Infirmary → station crafting, built structures → contextual details/actions, **work board → daily work plus permanent camp-expansion planner**, gate → survivor + destination + LEAVE CAMP, survivor → inspector plus deliberate work assignments, communal storage → communal inventory. Future construction anchors remain invisible until work begins. Those sheets return to the camp rather than becoming parallel top-level menus.

### `FFCampView.gd`
Living 2D camp presentation foundation. Reads authoritative state and maps it to visual stations/cosmetic survivor motion only. It must not own work timing, resources, survivor rules, or pathfinding gameplay.

### `FFCampViewSleepVirus.gd`
Active camp/menu renderer and touch hit-test layer. Owns deterministic visual sleep-slot selection and presentation for Sleeping/**Exhausted**, training, treatment, **live animated chores**, pet care, quarantine, severe illness, and mood-driven idle activity. It also owns the sparse wilderness starter presentation and touch locations for survivor selection, communal storage, First Fire, Workbench/built structures, and the camp edge/gate. Unbuilt anchors remain invisible data. Those interactions emit intent signals only; `MainSleepVirus.gd` decides which contextual sheet/overlay to open and `Game` remains authoritative for all simulation changes.

### `FFSurvivorPanel.gd`
Legacy concise roster/dashboard implementation retained as an internal reusable component while camp interaction replaces standalone roster navigation. Detailed current presentation belongs to the active inspector wrapper.

### `FFCombat.gd`
Established tactical board/runtime foundation: map state, actors, infected, vision/fog, facing, sound propagation, doors/glass/hazards, **locked door / locked optional-container state**, physical loot-container state, **party-pooled item-slot carry capacity (4 base per survivor; packs raise it to 6 or 8)**, harvestable killed-infected corpses, objectives, survivor/pet rescue escort state, persistence, and rendering integration. Lock picking consumes the equipped persistent Lock Pick state rather than an abstract skill roll.

### `FFCombatThreeStat.gd`
Current combat rules: Combat/Agility attack and movement behavior, Stealth, Sprint, Forward, Shove, **magazine/chamber reloads with no camp Ammo resource**, Pump Shotgun cycling, distance-based ranged hit falloff, physical Crossbow/shotgun projectile range, multi-projectile shotgun cones, active off-hand use/Flashlight drain/Firecracker lure, weapon-class handling, and no armor mitigation.

### `FFCombatVirus.gd`
Thin active tactical wrapper. Counts **successful Bite hits only** for the controlled survivor and optional expedition companion, persists/returns those bite counts, and prevents a contacted living rescue from being failed merely because the player reaches the exit before the escort's next scheduled movement. Scratch and generic physical damage never enter virus exposure tracking.

### `FFTacticalBalance.gd`
Pure tactical tuning. Current formulas use Combat and Agility only. Owns infected encounter population/HP/damage, **Scratch/Bite attack profiles**, mob-pressure bonuses, distance-scaled searchable-container targets, **distance-scaled locked-door/container probability**, container search/loot tuning, Shove resistance/stagger, and infected hit chance. Infected durability is intentionally compressed to roughly **7–10 HP** across LIGHT/MED/HEAVY mass classes so the authored weapon kill-count ladder remains stable; mass matters more for shove/attack behavior than sponge HP. Infected attempt Scratch most of the time (higher hit chance, low damage) and Bite rarely (lower hit chance, high damage). Nearby group size still raises pressure, adds only a small damage bonus, accelerates repeated attacks, and expands pack alerting. Current population contract: Very Short exploration rolls 0–3 infected and is the only route that may produce 0–1; longer exploration floors at 2; ambushes use 5, pet rescues 3, and survivor rescues 5. Very Short targets 3–5 searchable containers, with higher tiers increasing from there.

### `FFTacticalTime.gd`
Low-level tactical timeline utilities for fatigue, condition, stance, weapon timing, and infected pace. Equipment weight/size no longer modifies timing; carry capacity is owned separately by the tactical 4/6/8 slot rule. `FFThreeStatRules.gd` applies current Agility-based normal/stealth/sprint movement modifiers on top of those base action costs.

### `FFTacticalScenarios.gd`
Encounter objective/catalog ownership and objective/place pairing. Tactical scene time snapshots the real settlement clock at encounter creation.

### `FFTacticalEnvironments.gd`
Authored physical places, geometry, props, searchable container anchors, entries, and deliberately separated extraction exits. Current families include alley, gas station, house, apartment, store, warehouse yard, and drainage wash.

### `FFTacticalTiles.gd`
Atlas-region lookup and tactical environment/item rendering.

### `FFTacticalLighting.gd`
Ambient profiles, authored/fixed light math, Flashlight/off-hand light profiles, daylight/window behavior, and light-dependent visibility helpers. Flashlight charge ownership/persistence stays in Game/tactical actor state rather than this pure presentation/rule helper.

### `FFTacticalSound.gd`
Surface-aware labels, bounded fuzzy source estimates, and ambient sound profiles. Tactical propagation/AI state remains in combat runtime.

### `FFTacticalVisuals.gd`
Persistent survivor appearances, infected visual families, rescued-pet rendering, weapons, corpses, impact effects, and tactical character rendering. Presentation only.

### `FFExpeditionRules.gd`
Pure expedition/logistics rules: five distance bands, fixed route hours, maximum two-person party size, per-survivor Cooked Food/Clean Water travel costs, the Very Far Expedition Vehicle gate, zone caps, and compatibility haul helpers. Standard Send Out duration is authored and no longer shortened by Agility. Encounter-family weighting belongs to `FFTacticalScenarios.gd`.

### `FFCampLifeRules.gd`
Pure camp-life tuning for survivor needs/moodlets, autonomous idle choice, scheduled midday drinking/evening eating/**8-hour normal sleep**, shelter-tier sleep quality and mood recovery, **idle fatigue recovery and 3–5h forced-exhaustion duration**, pet affection/retention/daily reward, authoritative camp-condition degradation/recovery/bands, daily water/meal/sleep-window accounting, **Large Tarp/Barracks/Dormitory shelter effects, three-stage Tavern social recovery including optional Beer sessions, water and defense-building effects**, recovery/treatment modifiers, and camp cadence. It also owns the **pure deterministic camp-pressure tables** for zombie-breach d100 outcomes, Noise Line/Watch Post defense bonuses, spoilage odds, and storm break thresholds. It does not choose event participants or mutate camp state. Idle choices include sleep plus visible mood responses such as checking rations/water, washing, watching the treeline, wandering, and watching the fire. `GameSleepVirus.gd` promotes sleep into the authoritative Sleeping status/task. Productive training, chores, maintenance, crafting, treatment, pet care, and expeditions are player-assigned.

### `FFCampChoreMinigame.gd`
Shared touch-first presentation/controller for the four timed maintenance interactions. It renders one reusable six-target interaction surface with chore-specific instructions and labels, emits action intents only, and never awards resources or mutates camp state. `GameSleepVirus.gd` owns irregular incident scheduling, deadlines, failure consequences, and the one-active-problem invariant. The overlay is a lower translucent sheet over the **still-running living camp**; `MainSleepVirus.gd` does **not** pause settlement for it and forwards intents to authoritative Game APIs while the assigned survivor continues its camp animation.

### `FFVirusRules.gd`
Pure zombie-virus rules. Owns stage names/normalization, contact-to-exposure probability, daily progression, camp-spread probability, and treatment plans/costs. It does not mutate Game state or render UI.

Current virus stages are **Clear → Exposed → Infected → Feverish**. Tactical transmission is Bite-only: every successful Bite gets an independent fixed **3%** exposure roll, while Scratch and generic physical damage have zero virus chance. The probability never increases from prior attacks. Exposed has a 50% natural-clear chance on its next daily progression. Established camp-spread probabilities remain reduced. Exposed can be decontaminated with Clean Water + a crafted Bandage; Infected consumes 1 Zombie Cure; Feverish emergency treatment requires an Infirmary + 1 Zombie Cure. Zombie Cure remains the rarest direct medical find and is also craftable at the Infirmary from 2 physically recovered Zombie Corpses. Quarantine prevents close-contact camp spread. Terminal consequence is applied by Game orchestration after an untreated Feverish daily transition.

### `FFCampSocial.gd`
Relationships, chatter, political standing, and leadership support. **Leadership** is the active progression stat for candidate standing and social/political checks. Active orchestration passes only assignable/available survivors into ordinary chatter selection.

### `FFFieldEventsLegacy.gd`
Temporary remaining outside-world text-event catalog. Outside-world content should continue moving toward tactical/physical play; camp social/political narrative remains valid.

### `FFSaveCodec.gd`
Persistence transport only: JSON/file read-write, compatibility check, invalidation. Current save schema is 8. Schema 7 is intentionally invalidated because the camp building identities/starter state changed materially; the three-stat and virus markers remain part of the current model.

### `scripts/ci/FFArchitectureSmoke.gd`
Deterministic pure-rule/source-contract checks. UI/autoload-dependent scripts are compiled by import/startup gates in their real project context; smoke asserts the active wrapper chain plus durable rules such as scheduled eating/drinking/sleep, the five-minute camp day, always-tactical Send Out routing, five expedition distance bands, party-scaled travel supplies, real tactical companion activation, survivor training, sparse camp interaction, infected-contact tracking, and virus treatment requirements.

## Camp event / expedition return boundary

`Game.gd` owns the existing camp narrative event queue, including event candidate selection, pre-rolled hidden luck stored in event context, choice resolution, and persistent building/resource/survivor mutation. Zombie breaches are explicitly **luck + infrastructure**, not survivor-stat or tactical-player-skill checks. `FFCampSocial.gd` remains the owner of relationships/chatter/political standing rather than absorbing destructive event rules.

Expedition return is not a loot generator. `Game.resolve_combat()` records only tactical loot already reported by the board onto the expedition's persisted return payload; it does **not** immediately add that haul to communal inventory. After tactical resolution, `_resume_expedition()` starts/resumes the real Away timer. `_finish_expedition()` may commit that carried payload only when the timer reaches zero **and at least one human returner is alive**; otherwise carried loot/gear and a rescued pet are lost. A living rescued recruit counts as a returner. The return path must not call abstract loot/gear rollers. Legacy outside-world text reward catalogs may remain as compatibility source temporarily, but production expedition flow must not enter them.

## Camp interaction boundary

The living camp is the primary interaction surface, but it remains a UI layer rather than a second simulation. `FFCampViewSleepVirus.gd` may determine which visible entity/cell was tapped and emit an intent signal. It must not spend resources, assign workers, start expeditions, alter survivor state, or perform crafting/building directly. `MainSleepVirus.gd` routes intent to contextual UI that calls the existing authoritative Game APIs.

The active UI no longer exposes the legacy four-tab bar. A new game visibly starts as wilderness plus **three** physical essentials: First Fire, shelter capacity for 3, and communal storage. Shelter presentation is resident-driven: `FFCampView.gd` owns the 3/7/12/18 sleep-slot geometry and draws only the first **living-population** number of beds; `FFCampViewSleepVirus.gd` reuses that same geometry for authoritative sleep placement. The work board owns permanent construction and keeps unbuilt anchors invisible until work begins. Shelter progresses **3 → 7 → 12 → 18** through Bedroll Camp → Large Tarp → Barracks → Dormitory with an exact hard recruitment cap at each tier; full-camp arrivals are discarded rather than queued. Hearth progression is independently authored as **First Fire → Tavern → Tavern Kitchen → Tavern Brewery**. The same physical fire remains the touch target while the Tavern visuals, social-recovery tier, food conversion recipes, and final Beer brewing unlock advance. Workbench is a cheap direct build (**2 Wood + 1 Scrap Metal**, no prerequisite), and until it exists the only crafting surface is First Fire with Cook Food, Boil Water, and Bandage. Built Workbench/Sewing Table/Infirmary expose their station catalogs, with Armory acting as the prerequisite for advanced Workbench recipes.

At-a-glance mood/need/virus indicators are derived presentation from existing survivor state. They do not create a second need or mood model.

## Availability boundary

A survivor is assignable only when the active Game layer says so. `GameSleepVirus.survivor_can_assign()` is the canonical current check for worker/equipment availability: living, `Available`, no active task, not quarantined, and not severely ill.

Sleeping, treatment/recovery, crafting, building, garden work, chores, pet care, expeditions, quarantine, and severe virus illness therefore cannot be simultaneously treated as free labor. UI should consume the Game availability API/status rather than inventing exceptions.

## Tactical pause boundary

Tactical encounters pause settlement simulation. Tactical action ticks and settlement time are different scales. Tactical thinking must not consume camp resources, advance building/recovery/virus progression, or trigger unrelated camp events. After tactical resolution, settlement resumes normally and the expedition stays **Away** until its authored route timer reaches zero. Camp pressure events and fresh maintenance incidents require at least one living survivor physically home; an empty camp cannot generate an interaction nobody can answer.

Detailed survivor/item inspection also pauses settlement simulation while open and restores the prior pause state on close.

## Settlement time scale

`Game.gd` retains the single direct clock and uses `DAY_SECONDS := 300.0`: real active delta is settlement delta, giving **12.5 real active seconds = 1 in-game hour** and 300 real active seconds / five minutes per full in-game day. Camp-life rates and autonomous-life durations preserve their per-in-game-hour behavior at the longer day. Expedition tactical maps launch immediately without advancing this clock; once tactical resolution is final, the route's authored duration is applied once through the same settlement simulation before the party returns. Tactical action ticks remain separate and freeze settlement simulation completely. UI refresh/autosave remain real-time concerns.

## Frozen scope

The living 2D camp is the final presentation and primary home/menu surface. Pets, active camp duties, authoritative sleep, zombie-virus consequence/treatment depth, and **1–2 survivor tactical expeditions** are approved gameplay. The second expedition survivor uses the existing on-map companion AI. A single Expedition Vehicle unlock gates Very Far travel, but full vehicle driving/fuel logistics, parties larger than two, and 3D camp rendering remain cut. The hard population ceiling is 18; the mature-settlement milestone remains 15+ living survivors + all planned buildings + an elected leader, after which play continues indefinitely.

## Save boundary

Current schema: **8**.

Current survivor-model marker: **`combat-agility-leadership-v1`**.

Current additive virus marker: **`zombie-virus-v1`**.

A schema-7 save carrying the previous six-skill survivor shape is deliberately invalidated and restarted instead of migrated. Virus fields are additive/normalized and do not require a schema reset. Camp-menu interaction/layout is presentation-only and does not change save shape. The filename `user://first_fire_alpha01.json` remains intentionally unchanged.

## Permanent CI gate

Pages CI validates canonical source and the active wrapper files, installs Godot 4.7.1/templates, imports/parses, runs architecture smoke, boots the real project headlessly, exports Web, rejects script/parse/load errors, uploads the Pages artifact, and deploys only after the gates pass.

## Refactor rule

The source razor was a one-time exception. Future cleanup remains local and feature-driven. The current wrapper stack is a deliberate small-blast-radius specialization of mature foundations; fold wrappers into base owners only when a focused change makes that safer than maintaining the seam.