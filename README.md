# First Fire

**First Fire** is an early playable zombie-apocalypse survivor settlement game built in Godot 4. It mixes menu-driven camp management, extraction-style expeditions, persistent survivor consequences, and portrait turn-based tactical encounters.

Created by DMC and AI.

## Play the current Alpha

**Web build:** https://dmcexcess-lab.github.io/first-fire/

The current playable milestone is **Alpha 0.2 — Tactical Expedition Encounters**. The game is designed phone-first and actively tested in mobile browsers, including iPhone/Safari.

> Alpha saves may be intentionally invalidated when major systems or save structures change. This is deliberate while the game is still in active development.

## What you do

Build a fragile survivor camp, keep people fed and supplied, craft and build infrastructure, send real survivors into the outside world, make decisions during tactical encounters, and bring the consequences home.

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

First Fire is **feature-complete at the pillar level**. Development now focuses on deepening and unifying the existing loop rather than adding another major mode.

The roadmap moves toward:

- every outside-world event becoming a physical tactical event;
- camp text events focusing on survivor stories and politics;
- richer tactical locations/maps/graphics;
- autonomous survivor social behavior;
- pets with lightweight persistent needs and autonomous survivor care;
- vehicles as expedition/logistics equipment and tactical entry/exit anchors;
- a living 3D camp background that visualizes the simulation without becoming a second control mode.

See [`ROADMAP.md`](ROADMAP.md) for the full sequence.

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
