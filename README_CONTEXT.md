# First Fire — Project Context

> **MANDATORY CONTEXT RULE FOR GPT:** At the start of every new user prompt that requests code or repository changes, fetch and reread both `README_SOPS.md` and this file from current `main`, then inspect the repository state relevant to that prompt. This is **once per prompt/change request** — not before every individual edit, file write, or commit inside the same coherent batch. A follow-up prompt that requests additional changes starts a new refresh cycle.

This file records what First Fire is, what the current game is trying to become, and the standing design decisions that should survive across chats. `README_SOPS.md` records how to work on the repository safely. `CHANGELOG.md` records what has actually shipped.

If these documents disagree with current code or a newer explicit user decision, current repo state plus the newest instruction wins.

## Project identity

**First Fire** is a mobile-first, menu-driven zombie-apocalypse survivor settlement game built in **Godot 4 / GDScript**.

The central fantasy is preserving and growing a fragile survivor camp while sending real people into a dangerous persistent world for food, water, materials, recruits, information, and specific objectives. It is evolving toward a **menu-based RimWorld-like settlement simulation with extraction-style expeditions and tactical field encounters**.

Primary current test target: **Web/mobile browser**, especially phone browsers including iPhone/Safari.

Live Alpha: `https://dmcexcess-lab.github.io/first-fire/`

## Current milestone

Current playable milestone: **Alpha 0.2 — Tactical Expedition Encounters**.

The settlement layer is playable and persistent. Expeditions can transition into portrait, turn-based tactical encounters using the actual First Fire survivor or survivors sent from camp.

Current development posture:

- playtest before expanding scope;
- collect feedback into coherent batches;
- prefer systemic/balance passes over tiny ping-pong edits;
- keep encounter count low while making existing encounters complete;
- do not expand simply because an idea is interesting.

## Core design pillars

### Simulation first
Drama should emerge from interacting systems, scarcity, condition, relationships, gear, environment, and player decisions — not from an AI director manufacturing crises.

Threats should exist physically or arise from persistent state. Do not spawn danger just because pacing feels quiet.

### Survivors are people
Survivors are persistent individuals with skills, gear, health, fatigue, stress, relationships, history, injuries, and consequences. Death should hurt, but one ordinary death should not automatically destroy the settlement.

### No conventional character levels
Skills improve through use. Equipment, condition, skill experience, team composition, and camp infrastructure create capability.

### Persistent consequences
Wounds, deaths, ammo use, resource expenditure, discovered sites, encounter outcomes, relationships, and tactical state should feed back into settlement/world state whenever practical.

### Extraction over extermination
Field play is usually about **loot, rescue, investigation, survival, and escape**. Clearing every enemy is not the default objective.

### Avoid pointless micromanagement
If a survivor is idle, natural recovery should happen automatically rather than requiring a manual Rest assignment. Apply the same philosophy to future systems when autonomy is more natural and less tedious.

## Core settlement loop

1. Maintain camp and survivors.
2. Decide what resources, information, recruits, or infrastructure matter next.
3. Send survivors on expeditions.
4. Resolve travel, scavenging, narrative choices, and sometimes tactical encounters.
5. Bring loot and consequences home.
6. Cook, purify, craft, build, recover, and make social/strategic decisions.
7. Repeat while the camp grows from a tiny improvised shelter into a real settlement.

The original Alpha progression foundation remains: one survivor with a sleeping bag and fire pit growing toward roughly five survivors, a cabin, and several early stations.

## UI / platform rules

First Fire is phone-first.

Permanent bottom tabs: **CAMP | CRAFT | BUILD | SURVIVORS**.

The game should remain comfortable at a narrow portrait viewport and usable by touch alone. Essential gameplay must not rely on keyboard-only controls.

The Web build is a first-class target. Browser lifecycle, touch behavior, storage, pause/resume, and mobile Safari constraints are architectural inputs.

Long-term presentation may use an evolving camp scene as the menu backdrop, but clarity and simulation come before visual complexity.

## Time / pause / session behavior

- simulation advances only while active and unpaused;
- backgrounding/minimizing/locking/closing saves and pauses;
- returning should not secretly advance settlement time;
- the player resumes intentionally;
- there is no mobile-game energy system.

For current Alpha testing, one full in-game day is **2 real active minutes**. Expedition/crafting/building timers are separately balanced.

## Survivor model

Survivors are persistent people with skills, condition, fatigue, stress, equipment, history, and relationships.

Skills are **use-based**. Idle survivors automatically recover fatigue and stress while remaining Available for immediate assignment.

Injury, treatment, natural recovery, tactical wounds, and death are systemic rather than cosmetic.

Companions sent on expeditions are real participants. In tactical encounters they can support the lead survivor, be injured, or die; those outcomes return to camp state.

## Early economy

Important resources include Raw Food, Cooked Food, Dirty Water, Clean Water, Wood, Scrap Metal, Cloth, Plastic, Hardware, Medicine, Ammo, and Seeds.

Early survival emphasizes finding dirty/raw inputs and processing them at camp.

Current Fire Pit conversions:

- **1 Raw Food → 2 Cooked Food**
- **1 Dirty Water → 2 Clean Water**

Routine scavenging was reduced after early playtests produced excessive stockpiles.

Current routine haul model:

- Camp Perimeter: 0–3 total items, 25% empty chance
- Nearby: max 4, 15% empty chance
- Residential: max 5, 8% empty chance
- Commercial: max 6, 4% empty chance
- Industrial: max 7, 2% empty chance

Scavenging skill may occasionally improve a haul without exceeding the zone cap.

Routine loot priority is approximately: **Dirty Water → Raw Food → materials → Clean Water → Cooked Food**.

## Expeditions / narrative encounters

Expeditions connect camp management to the outside world.

Encounters should have real requirements, visibly disabled unavailable options, meaningful alternate outcomes, and persistent consequences. Do not implement fake choices where only one option actually advances the system.

Recruit protection guarantees a **recruitment opportunity**, not a forced recruit.

Existing developed encounter concepts include injured strangers, survivors inside locations, the dog, backpacks, garages, gunshots, patrol cars, barricades/trading, clinics, hardware cages, construction trailers, and Miller Street Market.

Prefer deepening this pool over multiplying shallow encounters.

## Tactical expedition combat — Alpha 0.2

Some expeditions can transition into a portrait tactical board.

Current tactical principles include:

- grid / turn-based movement;
- actual expedition survivors rather than temporary combat avatars;
- directional vision and facing;
- fog of war;
- remembered last-seen enemies;
- approximate sound information;
- doors and glass;
- environmental obstacles;
- explosive hazards;
- stealth/rear advantages;
- melee and firearms;
- pre-placed physical zombies rather than edge spawning;
- persistent ammunition use;
- wounds, deaths, fatigue, stress, and Combat XP returned to camp.

Zombies that currently see the survivor create a clear **SPOTTED** state. When line of sight breaks, they pursue the last confirmed position rather than tracking magically through walls.

Current tactical encounter types:

- **Survivor Rescue:** reach the stranded survivor and escape; success returns to normal recruitment decision flow.
- **Explore Location:** search the objective and escape for additional loot before the expedition continues.
- **Ambush:** break contact and reach the exit; there is no location to clear.

Active tactical encounters are persistent across browser reloads, including important board and actor state.

## Save policy during Alpha

Alpha save compatibility is **not sacred**.

The project uses an explicit save schema. When meaningful system/schema changes make old saves inappropriate, increment the schema and invalidate old saves cleanly instead of accumulating migration/normalization baggage.

Current save schema: **3**.

Do not add old-save compatibility shims unless explicitly requested for a specific release.

## Progression philosophy

The camp itself is the main progression object.

Power should emerge from better-equipped survivors, improved use-based skills, resource stability, infrastructure, relationships/team composition, world knowledge, and access to harder opportunities.

Avoid generic XP/level gating when a concrete systemic/world requirement can do the job.

Early politics and survivor relationships are intended to become more important as the settlement grows.

## Monetization boundaries

Future monetization is intentionally non-exploitative: small top banner ad, one cold-launch/startup ad dismissible as the format permits, and a **$0.99 permanent ad-free** option.

Never tie gameplay systems to ad state. Do not add energy systems, gacha, survivor/resource purchases, premium currency, paid revives, paid timer skips, or paid power-ups. Timers are balanced for gameplay, not monetization pressure.

## Technical reality

Engine: **Godot 4 / GDScript**. Current Web CI uses **Godot 4.7.1**.

The current repository reconstructs the playable project during CI from:

- `first_fire_alpha01_web_ready.zip`
- `.deploy` Alpha patch fragments
- `.deploy/balance_pass.patch`
- `.deploy/save_schema_reset.patch`
- `.deploy/combat/*` combat source/integration payloads

Exact reconstruction/deployment rules belong in `README_SOPS.md`.

Long-term direction is to give durable systems clear owners instead of letting `Game.gd`, giant patches, or UI code become dumping grounds.

## Source-of-truth order

1. **Newest explicit user instruction**
2. **Current `main` repository state**
3. **`README_SOPS.md`** for coding/repo procedure
4. **`README_CONTEXT.md`** for standing game/design context
5. **`CHANGELOG.md`** for shipped player-facing history
6. Conversation memory only as supporting context

At the start of **every new code/change prompt**, reread the current SOP and context files once before beginning that prompt's coherent batch. A follow-up prompt requesting additional changes is a new refresh cycle; individual edits within the same prompt are not.

## Near-term discipline

- playtest first;
- batch issues and balance observations;
- fix actual bugs and systemic weaknesses;
- deepen existing content before expanding encounter count;
- preserve mobile/browser usability;
- keep new durable systems modular;
- invalidate Alpha saves cleanly when needed;
- update this file when a durable design rule changes;
- update `CHANGELOG.md` when player-facing behavior ships.
