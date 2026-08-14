# First Fire — Architecture

This document records the canonical module boundaries after the one-time source razor and where roadmap work belongs.

## Canonical source

The Godot project is ordinary source under `game/`:

```text
game/
  project.godot
  export_presets.cfg
  main.tscn
  assets/
  scripts/
```

There is no active ZIP/patch/Base64 reconstruction chain. Git history preserves the old packaging if historical inspection is ever needed.

Preferred dependency direction is:

**data/catalogs → simulation/rule modules → Game orchestration/state → Main UI/input**

UI may request actions and render state; it should not become authoritative simulation.

## Current owners

### `FFData.gd`
Shared declarative catalogs used across systems. Do not turn it into a universal dumping ground when a growing subsystem deserves its own data owner.

### `Game.gd`
Persistent state and orchestration facade: camp ticks, expedition sequencing, event/tactical transitions, and the fluid Alpha save-state schema. It may keep compatibility wrappers where removing them would add needless blast radius, but new durable rules should live in dedicated modules.

### `Main.gd`
Top-level UI/input coordinator: persistent HUD, navigation, main menu, expedition launcher, event/tactical transitions, and mounting presentation modules. It should coordinate presentation rather than contain every detailed screen.

### `FFCampView.gd`
Living 2D camp presentation built from the tactical tile/character language. It reads authoritative buildings, survivor status/tasks, equipment, appearance, fatigue/stress, and camp clock state; it maps those facts to visual stations and cosmetic movement only. Crafting survivors walk to the real task station, builders move to the relevant construction anchor, tending survivors move to the garden, recovering survivors move toward shelter, and expedition survivors disappear from camp. It must never become the owner of work timing, survivor status, resource production, or pathfinding gameplay.

### `FFSurvivorPanel.gd`
Survivor-tab dashboard presentation. Owns the concise CAMP/OUT/BUSY/LOST summary, current away-party cards and remaining times, recent return summaries derived from persistent camp history, and the compact roster. It does not own survivor state or expedition rules.

### `FFInspector.gd`
Reusable modal inspection presentation for detailed survivor sheets and camp inventory/item information. It owns the inspection pause/restore behavior and item help text, while survivor/equipment actions still go through `Game.gd`. Inspection is intentionally schema-neutral and must not become a second inventory or survivor-state model.

### `FFCombat.gd`
Tactical runtime once a physical scenario exists: board state, actors, movement/action timing, zombie behavior, vision/fog, facing, sound, doors/glass/hazards, melee/firearms, objectives, and completion.

### `FFTacticalScenarios.gd`
Tactical objective/catalog ownership: encounter-kind weights and combination of an objective with a compatible physical environment. Objective and place are intentionally separate so the same location can host rescue, search, or ambush situations.

### `FFTacticalEnvironments.gd`
Authored tactical place ownership: recognizable 20×18 environment templates, zone compatibility, ground/theme metadata, props, party entry positions, and one-or-multiple escape routes. Current families include back alley, gas station, residential house, apartment, corner store, warehouse yard, and drainage wash. Geometry must keep every declared exit reachable from the authored party spawn.

### `FFTacticalTiles.gd`
Tactical environment atlas renderer. Owns atlas-region lookup and drawing for ground, structural tiles, props, and carried-item icons. Physical geometry/occlusion remains authoritative in `FFTacticalEnvironments.gd` / `FFCombat.gd`.

### `FFTacticalTime.gd`
Pure tactical action-timing rules. Converts survivor equipment weight, fatigue, condition, skills, stance, and zombie pace/mass profiles into actual timeline costs used by `FFCombat.gd`.

### `FFTacticalSound.gd`
Pure tactical sound presentation/localization rules: surface-aware labels, bounded fuzzy source estimates, and ambient sound profiles. `FFCombat.gd` still owns propagation and AI reaction state.

### `FFTacticalLighting.gd`
Tactical lighting rules/presentation helper. Owns ambient low-light profiles, fixed-light falloff/color presets, data-driven Secondary light-item cone math, and cheap glow animation rules. `FFTacticalEnvironments.gd` owns fixed light placement; `FFCombat.gd` owns occlusion, light-map recalculation, fog/vision, and draw order. Lighting does not advance settlement simulation.

### `FFTacticalVisuals.gd`
Tactical character presentation owner. Generates persistent survivor appearance dictionaries, zone-weighted infected visual families, weapon silhouettes, and the procedural character/corpse/impact drawing used by `FFCombat.gd`. It is presentation-only: infected visual families do not imply different stats or AI unless a future gameplay change explicitly adds them.

### `FFFieldEventsLegacy.gd`
Temporary Alpha 0.2 compatibility owner for remaining **outside-world text-event selection only**. Delete it when Alpha 0.3 has tactical equivalents for every field event and no caller needs the text field path. Camp stories/politics remain valid narrative events.

### `FFExpeditionRules.gd`
Pure single-survivor expedition/logistics rules: travel duration, recruit protection, tactical-event share, zone haul caps, and routine haul-count distributions. Multi-survivor dispatch and vehicles are not part of the final design.

### `FFCampLifeRules.gd`
Camp-life cadence, idle recovery, injury/treatment modifiers, defensive-building risk, rain-catcher output, and chatter timing.

### `FFCampSocial.gd`
Relationship mutation/labels, candidate standing, leadership support, pair selection, and autonomous camp chatter. Personality, stress, shortages, relationship state, leadership opinion and policy can shape quiet interactions; Game applies consequences and the camp view renders them.

### `FFSaveCodec.gd`
Persistence transport only: JSON/file read-write, compatibility check, invalidation. During Alpha, `Game.gd` still owns the actual state dictionary/schema.

### `scripts/ci/FFArchitectureSmoke.gd`
Deterministic module-contract checks. Add cheap regression invariants here when important bugs teach the project something reusable.

## Frozen scope

The living **2D** camp is final presentation. Pets, vehicles, 3D camp rendering, multi-survivor expeditions, and tactical companion AI are deliberately cut. New code should complete/tune existing owners rather than create replacement feature pillars.

The hard population ceiling is 18; the mature-settlement milestone is 15+ survivors with all planned buildings and an elected leader, and it does not end the save.

## Tactical pause boundary

Entering a tactical field encounter pauses normal settlement simulation. Tactical turns and settlement time are different scales. Do not let tactical UI/scenario code advance food use, building, recovery, or unrelated camp events.

Detailed survivor/item inspection also pauses settlement simulation while the modal is open, then restores the prior pause state. This is a UI inspection boundary, not tactical time and not a new simulation state.

## Save boundary

Current schema: **7**. Alpha policy is clean invalidation on meaningful incompatibility rather than accumulating migrations.

The filename `user://first_fire_alpha01.json` remains intentionally for compatibility; its old name alone is not grounds for a save wipe.

## Permanent CI gate

Pages CI now:

1. validates canonical `game/` structure and absence of old reconstruction artifacts;
2. imports/parses the Godot project;
3. runs deterministic architecture smoke;
4. boots the actual project headlessly;
5. exports Web;
6. rejects `SCRIPT ERROR`, `Parse Error`, and `Failed to load script` from logs;
7. deploys Pages only after all gates pass.

## Post-razor refactor rule

The project-wide razor was a one-time exception. Future refactors should be local and feature-driven: put new behavior in its durable owner, delete proven-dead code, retain safe compatibility facades when removal adds risk, and do not launch another broad cleanup merely for aesthetics.
