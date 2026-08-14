# First Fire — Project Context

> **MANDATORY CONTEXT RULE FOR GPT:** At the start of every new user prompt that requests code or repository changes, fetch and reread both `README_SOPS.md` and this file from current `main`, then inspect the repo state relevant to that prompt. This happens **once per prompt/change request**, not before every individual edit, file write, or commit inside the same coherent batch. A follow-up prompt requesting additional changes starts a new refresh cycle.

This file records the durable product/design context. `README_SOPS.md` records how to work on the repo safely. `CHANGELOG.md` records what has actually shipped. Newest explicit user instruction plus current repo state wins over older context.

## Current game

**First Fire** is a mobile-first Godot 4 / GDScript zombie-apocalypse survivor settlement game. It mixes menu-driven camp management, extraction-style expeditions, persistent survivor consequences, and portrait turn-based tactical encounters.

Current milestone: **Alpha 0.2 — Tactical Expedition Encounters**.

Live Web build: `https://dmcexcess-lab.github.io/first-fire/`

Core navigation: **CAMP | CRAFT | BUILD | SURVIVORS**.

## Design pillars

- **Simulation first.** Drama comes from systems and persistent state, not an AI director manufacturing crises.
- **Survivors are people.** Skills, gear, health, fatigue, stress, relationships, history, wounds, and deaths matter.
- **No conventional character levels.** Capability comes from use-based skills, equipment, condition, team composition, and camp infrastructure.
- **Persistent consequences.** Field outcomes feed back into camp/world state.
- **Extraction over extermination.** Loot, rescue, investigation, survival, and escape matter more than clearing every enemy.
- **Low content count, high implementation depth.** Deepen existing encounters before multiplying shallow ones.
- **Low pointless micromanagement.** Idle survivors recover automatically while remaining Available.
- **Phone/Web first.** Touch, portrait layout, browser lifecycle, storage, pause/resume, and mobile Safari constraints are architectural inputs.

## Current economy / time

For Alpha testing, one full in-game day is **2 real active minutes**.

Fire Pit conversions:
- **1 Raw Food → 2 Cooked Food**
- **1 Dirty Water → 2 Clean Water**

Routine scavenging is intentionally constrained after early over-looting:
- Camp Perimeter: 0–3 items, 25% empty
- Nearby: max 4, 15% empty
- Residential: max 5, 8% empty
- Commercial: max 6, 4% empty
- Industrial: max 7, 2% empty

Loot priority is approximately **Dirty Water → Raw Food → materials → Clean Water → Cooked Food**.

## Expeditions / encounters

Encounters should have real requirements, disabled unavailable options, meaningful alternate outcomes, and persistent consequences. Recruitment protection guarantees a recruitment **opportunity**, not a forced recruit.

Prefer deepening the existing encounter pool over adding placeholder content.

## Tactical combat — Alpha 0.2

Tactical encounters use the actual expedition survivor(s), not temporary combat avatars. Current principles include grid turns, directional vision/facing, fog of war, remembered last-seen enemies, approximate sound information, doors, glass, obstacles, explosive hazards, stealth/rear advantages, melee, firearms, and pre-placed zombies.

Current tactical encounter types:
- **Survivor Rescue** — reach the stranded survivor and escape; success returns to normal recruitment flow.
- **Explore Location** — search the objective and escape for extra loot.
- **Ambush** — break contact and reach the exit.

Wounds, deaths, fatigue, stress, ammunition use, and Combat XP return to camp state. Active tactical encounters persist across browser reloads.

## Saves

Alpha save compatibility is **not sacred**. Use an explicit save schema and invalidate old Alpha saves cleanly when meaningful system/schema changes occur instead of accumulating migration baggage.

Current save schema: **3**.

## Technical reality

Current Web CI uses **Godot 4.7.1**. The playable project is reconstructed during CI from the base ZIP plus `.deploy` patch/module inputs, including the combat module. Exact reconstruction rules belong in `README_SOPS.md`.

New durable systems should get clear owners rather than growing `Game.gd`, giant patch chains, or UI-owned simulation rules.

## Source-of-truth order

1. Newest explicit user instruction
2. Current `main` repo state
3. `README_SOPS.md`
4. `README_CONTEXT.md`
5. `CHANGELOG.md`
6. Conversation memory only as supporting context

At the start of **each new code/change prompt**, reread SOP + context once, then perform that prompt's coherent batch without rereading between individual edits.
