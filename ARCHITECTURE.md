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
UI, presentation, input, menus, and transitions only.

### `FFCombat.gd`
Tactical runtime once a physical scenario exists: board state, actors, movement/action timing, zombie behavior, vision/fog, facing, sound, doors/glass/hazards, melee/firearms, objectives, and completion.

### `FFTacticalScenarios.gd`
Tactical scenario/catalog ownership: encounter-kind weights, location catalogs, and layout selection. Alpha 0.3/0.4 should grow this toward data-driven physical versions of all outside-world events, authored chunks, objective combinations, hazards, human/survivor situations, and optional objectives.

### `FFFieldEventsLegacy.gd`
Temporary Alpha 0.2 compatibility owner for remaining **outside-world text-event selection only**. Delete it when Alpha 0.3 has tactical equivalents for every field event and no caller needs the text field path. Camp stories/politics remain valid narrative events.

### `FFExpeditionRules.gd`
Pure expedition/logistics rules: travel duration, recruit protection, tactical-event share, zone haul caps, and routine haul-count distributions. This is the integration seam for future vehicle speed/range/cargo effects and route/logistics constraints.

### `FFCampLifeRules.gd`
Camp-life cadence and idle recovery tuning. Future home for shared camp vibe/comfort/resource-security modifiers that influence autonomous life.

### `FFCampSocial.gd`
Relationship mutation/labels and survivor social-selection rules. Alpha 0.5 should grow autonomous interactions here: personality, stress, health, fatigue, injuries, shared history, losses/successes, politics, comfort, resentment, friendship, and meaningful camp-story triggers.

### `FFSaveCodec.gd`
Persistence transport only: JSON/file read-write, compatibility check, invalidation. During Alpha, `Game.gd` still owns the actual state dictionary/schema.

### `scripts/ci/FFArchitectureSmoke.gd`
Deterministic module-contract checks. Add cheap regression invariants here when important bugs teach the project something reusable.

## Planned seams — do not create empty modules early

### Future `FFPets.gd`
Expected owner for animal state/needs, bonds/trust, care outcomes, species/training roles, and pet-specific expedition state. It should consume camp/social/resource state; survivors care for pets autonomously when possible.

### Future `FFVehicles.gd`
Expected owner for vehicle definitions/state, fuel, condition/reliability, seats, cargo/storage, repairs, and noise. It feeds derived logistics into `FFExpeditionRules`. On tactical maps, the vehicle becomes the physical entry/exit anchor — the map’s “stairs.” No real-time driving subsystem is planned.

### Future 3D camp presentation
A dedicated presentation scene/controller should **read** authoritative survivor/camp/pet/vehicle state. It can visualize work, rest, conversations, pets, and repairs but must not become a second simulation.

## Tactical pause boundary

Entering a tactical field encounter pauses normal settlement simulation. Tactical turns and settlement time are different scales. Do not let tactical UI/scenario code advance food use, building, recovery, or unrelated camp events.

## Save boundary

Current schema: **3**. Alpha policy is clean invalidation on meaningful incompatibility rather than accumulating migrations.

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
