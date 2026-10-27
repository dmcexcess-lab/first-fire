# First Fire

**First Fire** is an early playable zombie-apocalypse survivor settlement game built in Godot 4. It combines a living camp/base simulation with solo turn-based extraction raids and persistent survivor consequences.

Created by DMC and AI.

## Play the extraction/base-sim slice

**Web build:** https://dmcexcess-lab.github.io/first-fire/

The current playable milestone is **Turn-Based Extraction Neighborhood**. Phone/Web remains the primary target; actual mobile Safari playtesting is still required for the new turn-based controls.

> Alpha saves may be intentionally invalidated when major systems or save structures change. This is deliberate while the game is still in active development.

The founder starts with a Revolver and finite ammunition. Equip at the gate, loot physical containers, escape, and bring supplies home to build and sustain the camp. Ammunition persists; Workbench resupply costs Scrap Metal. Raid death loses the survivor and equipped kit. Existing schema-8 camp saves are preserved.

## What you do

Build a fragile survivor camp, keep people fed and supplied, craft and build infrastructure, send real survivors into the outside world, loot and fight in turn-based raids, then survive a full extraction turn, and bring the consequences home.

The field game is about **survival, looting, rescue, investigation, and escape** rather than clearing every enemy from a map.

Survivors are persistent individuals. Their skills, gear, health, fatigue, stress, relationships, history, wounds, and deaths matter back at camp.

## Current Alpha features

- Persistent camp and survivor state
- Living-camp touch navigation to survivors, stations, storage, work and the gate
- Use-based survivor skills rather than character levels
- Food/water processing and survival economy
- Crafting and settlement construction
- Expeditions, scavenging, discovered sites, and branching encounters
- Recruitment decisions and survivor relationships
- Automatic idle recovery rather than manual rest micromanagement
- Tactical expedition encounters using the actual solo expedition survivor
- Directional vision, fog of war, facing, sound information, doors, glass, hazards, stealth, melee, and firearms
- Survivor Rescue, Explore Location, and Ambush tactical objectives
- Tactical wounds, deaths, fatigue, stress, ammunition use, and Combat XP feeding back into camp
- Active tactical encounters that can survive a browser reload
- Web deployment through GitHub Pages

## Design direction

Each raid generates a new large Country, Suburbs or City map with 4–7 random extraction points. Ordinary fragile zombies are pre-placed at biome-specific density; noise draws crowds, and the zombie phase moves them together in two simultaneous beats. You guide the camp: its needs, morale, housing and elected leaders persist, and even losing every camper leaves a place that a future arrival can resettle. Field supplies remain the five basic resources plus equipment, with other supplies produced in camp.


See [`ROADMAP.md`](ROADMAP.md) for the development sequence.

## Development architecture

The one-time source razor replaced the historical ZIP/patch/Base64 reconstruction pipeline.

The canonical Godot project now lives directly in [`game/`](game/), and CI builds that source directly.

Durable rules are being separated into clear owners for tactical scenarios, expedition/logistics rules, camp-life tuning, social relationships, save I/O, and tactical runtime. The remaining Alpha 0.2 text-based outside-world encounter catalog is explicitly isolated as legacy code pending the Alpha 0.3 tactical conversion.

See [`ARCHITECTURE.md`](ARCHITECTURE.md) for current ownership.

## Project documentation

- [`ROADMAP.md`](ROADMAP.md) — planned development through 1.0
- [`ARCHITECTURE.md`](ARCHITECTURE.md) — canonical source layout and module ownership
- [`README_CONTEXT.md`](README_CONTEXT.md) — durable game/design context
- [`README_SOPS.md`](README_SOPS.md) — coding, GitHub, testing, and deployment SOP for GPT-assisted development
- [`CHANGELOG.md`](CHANGELOG.md) — shipped changes by Alpha build

For development work, **current repository state and the newest explicit design decision are the source of truth**.
