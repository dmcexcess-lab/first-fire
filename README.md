# First Fire

**First Fire** is an early playable zombie-apocalypse survivor settlement game built in Godot 4. It mixes menu-driven camp management, extraction-style expeditions, persistent survivor consequences, and portrait turn-based tactical encounters.

Created by DMC and AI.

## Play the current Alpha

**Web build:** https://dmcexcess-lab.github.io/first-fire/

The current playable milestone is **Alpha 0.2 — Tactical Expedition Encounters**. The game is designed phone-first and is actively tested in mobile browsers, including iPhone/Safari.

> Alpha saves may be intentionally invalidated when major systems or save structures change. This is deliberate while the game is still in active development.

## What you do

Build a fragile survivor camp, keep people fed and supplied, craft and build infrastructure, send real survivors into the outside world, make decisions during encounters, and bring the consequences home.

The field game is about **survival, looting, rescue, investigation, and escape** rather than clearing every enemy from a map.

Survivors are persistent individuals. Their skills, gear, health, fatigue, stress, relationships, history, wounds, and deaths matter back at camp.

## Current Alpha features

- Persistent camp and survivor state
- **Camp / Craft / Build / Survivors** mobile navigation
- Use-based survivor skills rather than character levels
- Food/water processing and survival economy
- Crafting and settlement construction
- Expeditions, scavenging, discovered sites, and branching encounters
- Recruitment decisions and survivor relationships
- Automatic idle recovery rather than manual rest micromanagement
- Tactical expedition encounters using the actual expedition survivor and companion
- Directional vision, fog of war, facing, sound information, doors, glass, hazards, stealth, melee, and firearms
- Survivor Rescue, Explore Location, and Ambush tactical objectives
- Tactical wounds, deaths, fatigue, stress, ammunition use, and Combat XP feeding back into camp
- Active tactical encounters that can survive a browser reload
- Web deployment through GitHub Pages

## Design direction

First Fire is being built around a few strong rules:

- **Simulation first.** Drama should emerge from systems and persistent state rather than an AI director manufacturing trouble.
- **Survivors are people, not disposable units.** Their condition, skills, equipment, relationships, and history are the real progression system.
- **No player levels as the main source of power.** Capability comes from use-based skills, gear, health, team composition, and camp infrastructure.
- **Persistent consequences matter.** Field decisions should affect the settlement and future expeditions.
- **Extraction over extermination.** Getting what you need and getting home alive is usually more important than killing everything.
- **Low content count, high implementation depth.** A few complete encounters are preferred over a large pile of placeholder events.
- **Phone-first usability.** Touch, portrait screen space, browser lifecycle, and mobile performance are design constraints from the start.

## Development status

First Fire is an active Alpha and balance is still moving quickly. Current testing is focused on the early settlement economy, expedition pacing, survivor recovery, encounter quality, and the integration between camp play and tactical field encounters.

The repository currently reconstructs the playable Godot project during CI from a base Alpha package plus persistent patch/module inputs. This is a development-stage packaging setup, not the intended final project layout.

## Project documentation

- [`README_CONTEXT.md`](README_CONTEXT.md) — durable game/design context and current product direction
- [`README_SOPS.md`](README_SOPS.md) — coding, GitHub, architecture, packaging, testing, and deployment SOP for GPT-assisted development
- [`CHANGELOG.md`](CHANGELOG.md) — player-facing changes by Alpha build

For development work, **current repository state and the newest explicit design decision are the source of truth**.
