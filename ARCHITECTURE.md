# First Fire — Architecture

This document records the canonical module boundaries and where feature-freeze work belongs.

## Canonical source

The Godot project is ordinary source under `game/`. There is no active ZIP/patch/Base64 reconstruction chain. Preferred dependency direction is:

**data/catalogs → simulation/rule modules → Game orchestration/state → Main UI/input**

UI may request actions and render state; it should not become authoritative simulation.

## Active three-stat layer

First Fire now has exactly three survivor progression stats:

- **Combat** — melee/firearm handling, attack reliability, and combat output.
- **Agility** — movement pace, stealth, sprinting, avoidance, and physical escape capability.
- **Leadership** — camp influence, social checks, political standing, and voting strength.

The former Scavenging, Survival, Medical, Technical, and Social stats are no longer player-facing survivor stats. Crafting, treatment, searching, and other noncombat work should use tools, resources, traits, infrastructure, state, and authored rules instead of recreating hidden substitute skill trees.

`FFThreeStatRules.gd` owns the canonical stat catalog, weapon-hand classes, class combat profiles, and Agility movement/stealth/sprint math.

`GameThreeStat.gd` is the active `Game` autoload. It extends the proven `Game.gd` orchestration foundation while overriding survivor generation, progression, expedition checks, treatment, abstract danger, loot skill hooks, politics, injury protection, and save compatibility for the three-stat model. Existing saves whose survivor state is not the three-stat model are invalidated cleanly through the `combat-agility-leadership-v1` model marker. The underlying save schema remains 7.

`MainThreeStat.gd` is the active main-scene script. It extends `Main.gd` and mounts the three-stat inspector and tactical runtime without duplicating the mature navigation/event/camp UI.

`FFInspectorThreeStat.gd` is the active detailed survivor/item presentation. It exposes only Combat / Agility / Leadership, shows weapon hand/class information, and does not present clothing protection as armor.

`FFCombatThreeStat.gd` is the active tactical runtime specialization. It extends the established `FFCombat.gd` board/environment/objective runtime and owns the current combat action layer:

- **1H Melee**
- **2H Melee**
- **1H Gun**
- **2H Gun**
- **Stealth** — Agility-driven, quieter and slower movement with positional stealth-attack opportunity
- **Sprint** — Agility-driven, faster/louder movement with increased grab avoidance
- **Forward** — dedicated touch movement action occupying the former Guard slot
- **Shove** — spacing/stagger action with mass-based resistance/stagger

There is **no armor mitigation** in the active combat or abstract-injury paths. Clothing may remain as carried/equipped gear for identity, weight, crafting, or future non-armor utility, but it must not cancel or reduce incoming physical damage.

## Core owners

### `FFData.gd`
Shared declarative catalogs. Item names, recipes, zones, buildings, backgrounds, and gear data live here. Legacy `protect`, old background skill-bonus fields, or other stale catalog metadata are not authoritative when contradicted by the active three-stat rules; remove them when a focused cleanup safely owns that data.

### `Game.gd`
Persistent state/orchestration foundation: camp ticks, survivor work assignment, camp-maintenance and pet state, expedition sequencing, event/tactical transitions, and schema-7 state transport shape. The active runtime is `GameThreeStat.gd`, which specializes this foundation for the current stat/combat model.

### `Main.gd`
Top-level UI/input foundation. The active main scene uses `MainThreeStat.gd`, which keeps the mature UI while routing survivor inspection and tactical play to the current three-stat implementations. CAMP presents the touch-first work board and pet-care interactions; authoritative progress/resources remain in `Game.gd`.

### `FFCampView.gd`
Living 2D camp presentation. It reads authoritative state and maps it to visual stations/cosmetic survivor motion only. It must not own work timing, resources, survivor rules, or pathfinding gameplay.

### `FFSurvivorPanel.gd`
Concise Survivors-tab dashboard: CAMP/OUT/BUSY/LOST summary, outside-camp cards, recent returns, and roster. Detailed three-stat presentation belongs to `FFInspectorThreeStat.gd`.

### `FFCombat.gd`
Established tactical board/runtime foundation: map state, actors, zombies, vision/fog, facing, sound propagation, doors/glass/hazards, physical loot-container state, objectives, survivor/pet rescue escort state, persistence, and rendering integration. Current player combat rules are specialized by `FFCombatThreeStat.gd`.

### `FFTacticalBalance.gd`
Pure tactical tuning. Current formulas use Combat and Agility only. It owns infected counts/HP/damage, container search/loot tuning, Shove resistance/stagger, and zombie hit chance. Search/explore rewards are no longer improved by a Scavenging stat.

### `FFTacticalTime.gd`
Low-level tactical timeline utilities for load, fatigue, condition, stance, weapon timing, and infected pace. `FFThreeStatRules.gd` applies the current Agility-based normal/stealth/sprint movement modifiers on top of those base action costs.

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
Pure single-survivor expedition/logistics rules: travel duration, recruit protection, tactical-event share, zone haul caps, and haul-count distributions. Agility is the active survivor stat passed into travel timing by `GameThreeStat.gd`.

### `FFCampLifeRules.gd`
Pure camp-life tuning for survivor idle needs/moodlets, pet needs/care effects, fire and camp-maintenance decay, recovery/treatment modifiers, defense-building effects, and camp cadence. Eating/drinking, sleeping, and fun remain systemic idle behavior; productive chores, maintenance, crafting/building, pet care, and expeditions are assigned by the player through `Game.gd`.

### `FFCampSocial.gd`
Relationships, chatter, political standing, and leadership support. **Leadership** is the active progression stat for candidate standing and social/political checks.

### `FFFieldEventsLegacy.gd`
Temporary remaining outside-world text-event catalog. Outside-world content should continue moving toward tactical/physical play; camp social/political narrative remains valid.

### `FFSaveCodec.gd`
Persistence transport only: JSON/file read-write, compatibility check, invalidation. Current save schema remains 7; `GameThreeStat.gd` adds a stat-model compatibility marker so pre-reset six-skill saves are invalidated rather than migrated.

### `scripts/ci/FFArchitectureSmoke.gd`
Deterministic pure-rule/source-contract checks. UI/autoload-dependent scripts are compiled by import/startup gates in their real project context rather than preloaded by the standalone smoke runner.

## Tactical pause boundary

Tactical encounters pause settlement simulation. Tactical action ticks and settlement time are different scales. Tactical thinking must not consume camp resources, advance building/recovery, or trigger unrelated camp events.

Detailed survivor/item inspection also pauses settlement simulation while open and restores the prior pause state on close.

## Frozen scope

The living 2D camp is final presentation. Pets and active camp duties are approved gameplay. Vehicles, 3D camp rendering, multi-survivor expeditions, and tactical companion AI remain cut. The hard population ceiling is 18; the mature-settlement milestone remains 15+ living survivors + all planned buildings + an elected leader, after which play continues indefinitely.

## Save boundary

Current schema: **7**.

Current survivor-model marker: **`combat-agility-leadership-v1`**.

A schema-7 save carrying the previous six-skill survivor shape is deliberately invalidated and restarted instead of migrated. The filename `user://first_fire_alpha01.json` remains intentionally unchanged.

## Permanent CI gate

Pages CI validates canonical source, installs Godot 4.7.1/templates, imports/parses, runs architecture smoke, boots the real project headlessly, exports Web, rejects script/parse/load errors, uploads the Pages artifact, and deploys only after the gates pass.

## Refactor rule

The source razor was a one-time exception. Future cleanup remains local and feature-driven. The current three-stat subclasses are a deliberate small-blast-radius specialization of mature foundations; fold them into base owners only when a focused change makes that safer than maintaining the seam.