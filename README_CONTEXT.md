# First Fire — Project Context

> **MANDATORY CONTEXT RULE FOR GPT:** At the start of every new user prompt that requests code or repository changes, fetch and reread both `README_SOPS.md` and this file from current `main`, then inspect the repo state relevant to that prompt. This happens **once per prompt/change request**, not before every individual edit, file write, or commit inside the same coherent batch.

This file records durable product/design context. `README_SOPS.md` records how to work on the repo. `ROADMAP.md` records intended development. `ARCHITECTURE.md` records current module ownership. Newest explicit user instruction plus current repo state wins over older context.

## Current game

**First Fire** is a mobile-first Godot 4 / GDScript zombie-apocalypse survivor settlement game. It mixes menu-driven camp management, extraction-style expeditions, persistent survivor consequences, and portrait turn-based tactical encounters.

Current milestone: **Beta Candidate — Feature Freeze**.

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
- **Low pointless micromanagement.** Idle recovery and social behavior should be systemic/autonomous when natural.
- **Phone/Web first.** Touch, portrait layout, browser lifecycle, storage, pause/resume, and mobile Safari constraints are architectural inputs.
- **Original presentation.** First Fire art should avoid third-party franchise names, logos, characters, or other recognizable branded identifiers unless explicitly requested and appropriate.

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

`FFCombat.gd` owns tactical runtime mechanics. `FFTacticalScenarios.gd` owns encounter objectives and combines them with a compatible place. `FFTacticalEnvironments.gd` owns recognizable authored tactical places, environment geometry, props, party entry points, and escape-route definitions. `FFTacticalVisuals.gd` owns persistent survivor appearance generation, zombie visual families, weapon silhouettes, and character rendering.

Objective and place are now separate: rescue/search/ambush situations can occur across compatible back alleys, gas stations, residential houses, apartments, corner stores, warehouse yards, and drainage washes. Every tactical map declares at least one reachable exit; some have one route and some have multiple. Reaching any exit is always a valid retreat even when the optional rescue/search objective was not completed.

Survivors keep persistent modular tactical appearances. Zombies use varied civilian/worker/service/medical/decayed/heavy visual families, while those families remain cosmetic until a future gameplay change explicitly says otherwise. Equipped weapons are drawn as separate readable silhouettes beside survivors.

Alpha 0.3D replaces the procedural tactical tokens/flat prop drawing with a reusable original sprite/tile atlas and adds randomized **day/night + powered/unpowered** scene states. The same authored place can therefore play in daylight, powered night light, or near-black blackout conditions. Daylight enters authored interiors through windows; glass transmits vision/light while walls, closed doors, and tall props occlude it.

Player vision is now shorter and truly light-dependent instead of being a light-independent cone with a dark filter drawn afterward. Zombie sight also responds to how illuminated the target is, so carrying a bright radial light improves awareness while making the carrier easier to detect.

Tactical action time is authoritative: equipped weight, fatigue, injuries, stance, survivor skill, weapon action time, and per-zombie pace/mass profiles feed the actual tick scheduler. Sound markers use bounded fuzzy localization near the true source, surface-specific footsteps and more ambient/infected noises, and nearby infected share awareness when one spots the party. A nonlethal melee hit reveals the attacker to that infected even when the approach was stealthy. Adjacent doors are now tap/click interactions, allowing explicit closing instead of treating an open door tap as movement.

## Expedition logistics

`FFExpeditionRules.gd` owns current travel duration, recruit protection, tactical-event mix, zone caps, and routine haul-count rules.

Expeditions are permanently single-survivor. Multi-survivor dispatch, companion AI, and vehicle logistics are cut from scope.

## Living camp presentation

The management menus now share a persistent **2D tactical-style living camp view** instead of separate decorative tab splash images. It uses the same tactical tile/character visual language while remaining presentation-only. Built structures appear at stable visual anchors; survivors physically move toward the station implied by their real task/status (crafting, building, tending, recovery), available survivors idle around camp, and expedition survivors are absent. The pause/main menu uses the same living camp as its background. Camp lighting follows the real settlement clock, with fire/cabin glow after dark.

For Alpha/Beta-candidate playtesting, every new founder starts with a **Flashlight equipped in Secondary** so day/night and blackout tactical lighting can always be exercised immediately. Save schema 7 is the final planned Alpha invalidation before Beta save stability. Explore tactical objectives now expose real named gear pickups from a zone-tiered catalog; a pickup is only committed to camp inventory after the survivor reaches it and escapes alive.

## Autonomous camp life

`FFCampLifeRules.gd` owns camp-life cadence/recovery tuning.

`FFCampSocial.gd` owns relationship/social-selection rules, political standing, and autonomous camp chatter. Chatter is selected from real relationship, shortage, personality, leadership-support and policy state; `Game.gd` applies its small consequences and `FFCampView.gd` only renders the callout.

Future interactions should be influenced by personality, relationships, stress, health, fatigue, injuries, recent losses/successes, resource security, comfort/crowding, shared history, politics/leadership, and overall camp vibe. Routine interactions should occur autonomously; the player handles conditions and meaningful consequences rather than scheduling conversations.


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

## Current Alpha 0.3A playtest tuning

- Tactical encounter chance rolls independently from legacy text events and now includes the starting zone: **65% Camp Perimeter / 70% Nearby / 75% Residential / 82% Commercial / 90% Industrial**.
- Tactical drought protection guarantees a tactical encounter on the next normal field run after two consecutive ordinary runs without one.
- Expedition dispatch no longer has a loot-focus selector; routine loot follows the zone's natural loot table plus survivor skill/equipment rules.
- Fatigue gains from expeditions, tactical encounters, crafting/building, and garden work are currently **2×** their original Alpha values. Idle recovery rates are unchanged.

## Saves

Alpha save compatibility is **not sacred**. Use explicit save schema versions and invalidate old saves cleanly when meaningful schema/system changes occur instead of accumulating migrations.

Current save schema: **7**.

The save filename remains `user://first_fire_alpha01.json` intentionally for compatibility. Its legacy name alone is not a reason to wipe a working Alpha save.

`FFSaveCodec.gd` owns persistence file/JSON mechanics. `Game.gd` still owns the actual state schema while Alpha remains fluid.

## Canonical technical reality

The one-time source razor replaced the historical ZIP/patch/Base64 reconstruction pipeline.

**Canonical Godot source now lives directly under `game/`.** CI builds that directory directly.

Current important module boundaries are documented in `ARCHITECTURE.md`.

`Game.gd` remains the persistent state/orchestration facade, but new durable roadmap rules should not be dumped into it. Existing compatibility wrappers may remain until their callers can be safely simplified.

Current Web CI uses **Godot 4.7.1** and runs import/parse, architecture, startup, and export gates before Pages deployment.

## Frozen-scope ownership summary

- tactical field play/conversion → `FFTacticalScenarios` + `FFTacticalEnvironments` + `FFCombat`
- single-survivor expedition logistics → `FFExpeditionRules`
- relationships/politics/autonomous chatter → `FFCampSocial`
- camp cadence/recovery/building effects → `FFCampLifeRules`
- living 2D camp/menu visualization → `FFCampView`
- saves → `FFSaveCodec` transport + current Game schema

There is no future pets, vehicles, companion-expedition, or 3D-camp owner. The 2D camp is final presentation.

Final population ceiling is **18**. At **15+ survivors + every building + an elected leader**, the settlement is marked mature, but the game continues indefinitely.

## Source-of-truth order

1. Newest explicit user instruction
2. Current `main` repo state
3. `README_SOPS.md`
4. `README_CONTEXT.md`
5. `ARCHITECTURE.md`
6. `ROADMAP.md`
7. `CHANGELOG.md`
8. Conversation memory only as supporting context

At the start of **each new code/change prompt**, reread SOP + context once, then perform that prompt's coherent batch without rereading between individual edits.

## Required code-change response footer

At the end of every prompt in which code/repository behavior was changed, include:

- Changelog: `https://github.com/dmcexcess-lab/first-fire/blob/main/CHANGELOG.md`
- Play: `https://dmcexcess-lab.github.io/first-fire/`
