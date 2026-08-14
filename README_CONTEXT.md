# First Fire — Project Context

> **MANDATORY CONTEXT RULE FOR GPT:** At the start of every new user prompt that requests code or repository changes, fetch and reread both `README_SOPS.md` and this file from current `main`, then inspect the repo state relevant to that prompt. This happens **once per prompt/change request**, not before every individual edit, file write, or commit inside the same coherent batch.

This file records durable product/design context. `README_SOPS.md` records how to work on the repo. `ROADMAP.md` records intended development. `ARCHITECTURE.md` records current module ownership. Newest explicit user instruction plus current repo state wins over older context.

## Current game

**First Fire** is a mobile-first Godot 4 / GDScript zombie-apocalypse survivor settlement game. It mixes menu-driven camp management, extraction-style expeditions, persistent survivor consequences, and portrait turn-based tactical encounters.

Current milestone: **Alpha 0.3A — Tactical Character Graphics**.

Live Web build: `https://dmcexcess-lab.github.io/first-fire/`

Core navigation: **CAMP | CRAFT | BUILD | SURVIVORS**.

First Fire is considered **feature-complete at the pillar level**. The roadmap is about deepening and unifying the existing loop rather than adding another major game mode.

## Design pillars

- **Simulation first.** Drama comes from interacting systems and persistent state, not an AI director manufacturing crises.
- **Survivors are people.** Skills, gear, health, fatigue, stress, relationships, history, wounds, and deaths matter.
- **No conventional character levels.** Capability comes from use-based skills, equipment, condition, team composition, and camp infrastructure.
- **Persistent consequences.** Field outcomes feed back into camp/world state.
- **Extraction over extermination.** Loot, rescue, investigation, survival, and escape matter more than clearing every enemy.
- **Low content count, high implementation depth.** Deepen existing systems before multiplying shallow content.
- **Low pointless micromanagement.** Idle recovery and social/pet care should be systemic/autonomous when natural.
- **Phone/Web first.** Touch, portrait layout, browser lifecycle, storage, pause/resume, and mobile Safari constraints are architectural inputs.

## Outside world vs. camp narrative

The roadmap establishes a clean presentation rule:

- **Outside world = tactical/physical.**
- **Camp social life/politics = narrative/dialogue.**

Alpha 0.2 still contains text-based field events. They are now deliberately isolated as legacy behavior in `FFFieldEventsLegacy.gd`. Alpha 0.3 should convert those events into tactical situations one by one and then delete that module.

Tactical encounters pause normal settlement simulation. Tactical thinking time must not consume camp food, advance construction/recovery, or fire unrelated camp events.

## Tactical combat

Tactical encounters use the actual expedition survivor(s), not temporary avatars. Current principles include grid turns, directional vision/facing, fog of war, remembered last-seen enemies, approximate sound information, doors, glass, obstacles, explosive hazards, stealth/rear advantages, melee, firearms, and pre-placed zombies.

Current tactical encounter types include:

- **Survivor Rescue**
- **Explore Location**
- **Ambush**

Wounds, deaths, fatigue, stress, ammunition use, and Combat XP return to camp state. Active tactical encounters persist across browser reloads.

`FFCombat.gd` owns tactical runtime mechanics. `FFTacticalScenarios.gd` owns what kind of physical situation/location/layout is created and is the intended Alpha 0.3/0.4 expansion seam. `FFTacticalVisuals.gd` owns persistent survivor appearance generation, zombie visual families, weapon silhouettes, and character rendering; tactical mechanics remain in `FFCombat.gd`.

Survivors now keep persistent modular tactical appearances. Zombies use varied civilian/worker/service/medical/decayed/heavy visual families, while those families remain cosmetic until a future gameplay change explicitly says otherwise. Equipped weapons are drawn as separate readable silhouettes beside survivors.

## Expedition logistics

`FFExpeditionRules.gd` owns current travel duration, recruit protection, tactical-event mix, zone caps, and routine haul-count rules.

It is also the intended integration seam for vehicles. Vehicles should affect travel/logistics and become the tactical map’s physical entry/exit anchor (“stairs”), not create a driving minigame.

## Autonomous camp life

`FFCampLifeRules.gd` owns camp-life cadence/recovery tuning.

`FFCampSocial.gd` owns current relationship/social-selection rules and is the intended owner for Alpha 0.5 autonomous survivor interactions.

Future interactions should be influenced by personality, relationships, stress, health, fatigue, injuries, recent losses/successes, resource security, comfort/crowding, shared history, politics/leadership, and overall camp vibe. Routine interactions should occur autonomously; the player handles conditions and meaningful consequences rather than scheduling conversations.

Pets should eventually get a dedicated owner (anticipated `FFPets.gd`) with lightweight persistent needs/bonds. Survivors should care for them autonomously when possible. Pet behavior should integrate with camp-life/social state and tactical expeditions rather than becoming a repetitive button timer.

## Current economy / time

For Alpha testing, one full in-game day is **2 real active minutes**.

Fire Pit conversions:
- **1 Raw Food → 2 Cooked Food**
- **1 Dirty Water → 2 Clean Water**

Routine scavenging remains intentionally constrained after early over-looting:
- Camp Perimeter: 0–3 items, 25% empty
- Nearby: max 4, 15% empty
- Residential: max 5, 8% empty
- Commercial: max 6, 4% empty
- Industrial: max 7, 2% empty

Loot priority is approximately **Dirty Water → Raw Food → materials → Clean Water → Cooked Food**.

## Saves

Alpha save compatibility is **not sacred**. Use explicit save schema versions and invalidate old saves cleanly when meaningful schema/system changes occur instead of accumulating migrations.

Current save schema: **4**.

The save filename remains `user://first_fire_alpha01.json` intentionally for compatibility. Its legacy name alone is not a reason to wipe a working Alpha save.

`FFSaveCodec.gd` owns persistence file/JSON mechanics. `Game.gd` still owns the actual state schema while Alpha remains fluid.

## Canonical technical reality

The one-time source razor replaced the historical ZIP/patch/Base64 reconstruction pipeline.

**Canonical Godot source now lives directly under `game/`.** CI builds that directory directly.

Current important module boundaries are documented in `ARCHITECTURE.md`.

`Game.gd` remains the persistent state/orchestration facade, but new durable roadmap rules should not be dumped into it. Existing compatibility wrappers may remain until their callers can be safely simplified.

Current Web CI uses **Godot 4.7.1** and runs import/parse, architecture, startup, and export gates before Pages deployment.

## Roadmap ownership summary

- Alpha 0.3/0.4 tactical field conversion/variety → `FFTacticalScenarios` + `FFCombat`
- expedition/logistics/vehicles → `FFExpeditionRules` + future `FFVehicles`
- autonomous survivor relationships → `FFCampSocial`
- camp-life cadence/recovery → `FFCampLifeRules`
- pets → future `FFPets`, consuming camp/social state
- saves → `FFSaveCodec` transport + current Game schema
- Beta 3D camp → presentation only; reads simulation state, does not own it

## Source-of-truth order

1. Newest explicit user instruction
2. Current `main` repo state
3. `README_SOPS.md`
4. `README_CONTEXT.md`
5. `ARCHITECTURE.md`
6. `ROADMAP.md`
7. `CHANGELOG.md`
8. Conversation memory only as supporting context

At the start of **each new code/change prompt**, reread SOP + context once, then perform that prompt’s coherent batch without rereading between individual edits.

## Required code-change response footer

At the end of every prompt in which code/repository behavior was changed, include:

- Changelog: `https://github.com/dmcexcess-lab/first-fire/blob/main/CHANGELOG.md`
- Play: `https://dmcexcess-lab.github.io/first-fire/`
