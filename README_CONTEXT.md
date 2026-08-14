# First Fire — Project Context

> **MANDATORY CONTEXT RULE FOR GPT:** Before any code edit in this repository, fetch and reread both `README_SOPS.md` and this file from current `main`. Then inspect the current repository state relevant to the requested change. Do not code from conversation memory alone.

This file records **what First Fire is, what the current game is trying to become, and the standing design decisions that should survive across chats**. `README_SOPS.md` records **how to work on the code/repository safely**. `CHANGELOG.md` records **what has actually shipped to the playable Alpha**.

If these documents disagree with current code or an explicit new user decision, current repo state plus the user's newest instruction wins. Update this context file when a durable design decision changes.

---

## 1. Project identity

**First Fire** is a mobile-first, menu-driven zombie-apocalypse survivor settlement game built in **Godot 4 / GDScript**.

The core fantasy is not clearing a map or becoming an action hero. It is building and preserving a fragile survivor camp while sending real people into a dangerous persistent world for food, water, materials, recruits, information, and specific objectives.

The game began as a lightweight menu survival game and is evolving toward a **menu-based RimWorld-like settlement simulation with extraction-style expeditions and tactical field encounters**.

Current primary test platform is the **Web build**, especially phone browsers including iPhone/Safari. The original product target remains phone-first play.

Live test build:

`https://dmcexcess-lab.github.io/first-fire/`

---

## 2. Current milestone

The current playable milestone is **Alpha 0.2 — Tactical Expedition Encounters**.

The settlement layer is already playable and persistent. Expeditions can now break into portrait, turn-based tactical encounters using the actual First Fire survivor(s) sent from camp.

Current Alpha scope is intentionally narrow. Prefer **few systems and encounters that are fully implemented** over a large catalog of fake or placeholder content.

The current development posture is:

- play the existing Alpha;
- collect a proper batch of feedback;
- make coherent system/balance passes;
- avoid unnecessary tiny back-and-forth edits;
- do not expand scope simply because a new idea is interesting.

---

## 3. Core design pillars

### Simulation first

Drama should come from interacting systems, scarcity, survivor condition, relationships, equipment, environmental state, and player decisions—not from an AI director manufacturing crises.

Threats should exist physically or arise from persistent world state. Do not spawn danger merely because pacing feels quiet.

### Survivors are people, not disposable cards

The camp's strength comes from its people, their skills, gear, health, fatigue, stress, relationships, and accumulated history.

Death and injury should matter, but one ordinary death should not automatically collapse the entire settlement.

### No character levels

There is no conventional player level or survivor level that acts as the primary source of power.

Skills improve through use. Equipment, condition, experience in specific skills, and camp infrastructure create capability.

### Persistent consequences

Expedition wounds, deaths, ammunition use, resource expenditure, discovered sites, encounter outcomes, relationships, and tactical state should feed back into the persistent settlement/world whenever practical.

### Survival/extraction rather than extermination

The goal of field play is usually to **loot, rescue, investigate, survive, and escape**. Clearing every enemy is not the default objective.

### Low micromanagement where autonomy is more natural

If a survivor is doing nothing, they should recover naturally rather than requiring pointless manual rest assignment. Apply the same philosophy to future systems when autonomous behavior is clearly more human and less tedious.

---

## 4. Core settlement loop

The broad loop is:

1. Maintain the camp and survivors.
2. Decide what resources, information, recruits, or infrastructure matter next.
3. Send one or more survivors on expeditions.
4. Resolve travel, scavenging, decisions, and sometimes tactical encounters.
5. Bring consequences and loot home.
6. Cook, purify, craft, build, recover, and make social/strategic decisions.
7. Repeat while the camp grows from a tiny improvised shelter into a real settlement.

Alpha 0.1's initial progression target was one survivor with a sleeping bag and fire pit growing toward roughly five survivors with a cabin and several early stations. That remains the foundation under Alpha 0.2 combat integration.

---

## 5. UI and platform rules

First Fire is phone-first.

Current core navigation uses four permanent bottom tabs:

**CAMP | CRAFT | BUILD | SURVIVORS**

The game should remain comfortable at a narrow portrait viewport and usable with touch alone. Keyboard-only affordances are not acceptable as the sole path for essential gameplay.

The Web build is a first-class test target, not an afterthought. Browser lifecycle, touch behavior, storage, pause/resume behavior, and mobile Safari constraints matter during architecture decisions.

Long-term presentation may use an evolving camp scene as the menu backdrop, but gameplay clarity and simulation come before visual complexity.

---

## 6. Time, pause, and session behavior

The game is intended to be easy to play briefly and put away immediately.

Standing behavior:

- simulation advances only while the game is active and unpaused;
- backgrounding/minimizing/locking/closing saves and pauses;
- returning should not secretly advance the settlement while the player was away;
- the player resumes intentionally;
- no mobile-game energy system exists.

For Alpha testing, one full in-game day is currently accelerated to **2 real active minutes**. Expedition/crafting/building timers are separately gameplay-balanced.

---

## 7. Survivor model

Survivors are persistent individuals with skills, condition, fatigue, stress, equipment, history, and relationships.

Skills are **use-based** rather than level-based. Tactical encounters currently use the actual expedition survivor's six skills and persistent state.

Idle survivors automatically recover fatigue and stress while still remaining Available for immediate assignment.

Injury, treatment, natural recovery, tactical wounds, and death should remain systemic rather than cosmetic.

Companions sent on expeditions are real participants. In tactical encounters they can support the lead survivor, be injured, and die; those outcomes return to camp state.

---

## 8. Camp resources and economy

Important early resources include:

- Raw Food
- Cooked Food
- Dirty Water
- Clean Water
- Wood
- Scrap Metal
- Cloth
- Plastic
- Hardware
- Medicine
- Ammo
- Seeds

Early survival economy intentionally emphasizes finding **dirty/raw inputs** and processing them at camp.

Current Fire Pit conversions:

- **1 Raw Food → 2 Cooked Food**
- **1 Dirty Water → 2 Clean Water**

Routine scavenging was deliberately reduced after early playtests produced excessive stockpiles.

Current routine haul model:

- Camp Perimeter: 0–3 total items, 25% empty chance
- Nearby: max 4, 15% empty chance
- Residential: max 5, 8% empty chance
- Commercial: max 6, 4% empty chance
- Industrial: max 7, 2% empty chance

Scavenging skill may occasionally improve a haul without exceeding the zone cap.

Routine loot priority is approximately:

**Dirty Water → Raw Food → materials → Clean Water → Cooked Food**

Cooked food should be rare in the world because camp processing is efficient.

---

## 9. Expeditions and narrative encounters

Expeditions are the bridge between settlement management and the dangerous outside world.

Encounters should have real requirements, greyed-out unavailable options, meaningful alternate outcomes, and persistent consequences. Do not implement a fake choice where only one button actually advances the system.

Recruit protection means the player is periodically guaranteed a **recruitment opportunity**, not a forced recruit. Meeting and declining/helping/leaving a potential survivor should resolve that opportunity normally.

Existing developed encounter concepts include injured strangers, survivors inside locations, the dog, backpacks, garages, gunshots, patrol cars, barricades/trading, clinics, hardware cages, construction trailers, and Miller Street Market.

Prefer deepening this small pool over multiplying shallow encounters.

---

## 10. Tactical expedition combat — Alpha 0.2

Some expeditions can now transition into a real portrait tactical board.

Current tactical principles include:

- grid / turn-based movement;
- actual expedition survivors, not temporary combat avatars;
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
- ammunition drawn from persistent First Fire resources;
- wounds, deaths, fatigue, stress, and Combat XP returned to camp.

Zombies that currently see the survivor produce a clear **SPOTTED** state. If line of sight breaks, they pursue the last confirmed position rather than magically tracking through walls.

Current tactical encounter types:

### Survivor Rescue
Reach the stranded survivor and escape. A rescue returns to First Fire's normal survivor/recruit decision flow rather than automatically adding the person to camp.

### Explore Location
Reach/search the objective and escape for a modest additional loot result, then continue the expedition.

### Ambush
There is no location to clear or prize to collect. The goal is to break contact and reach the exit.

Encounter mix varies by expedition zone.

Active tactical encounters are persistent and can be restored after browser reload, including important board and actor state.

---

## 11. Save policy during Alpha

Alpha save compatibility is **not sacred**.

The project uses an explicit save schema version. When a meaningful schema/system change makes old saves inappropriate, increment the schema and invalidate old saves cleanly rather than accumulating migration and normalization code that will become vestigial.

Current save schema is **3**.

Do not add compatibility shims for old Alpha saves unless the user explicitly requests preservation for a particular release.

---

## 12. Content and progression philosophy

The camp itself is the main progression object.

Power should emerge from:

- better-equipped survivors;
- improved skills through use;
- better resource stability;
- more capable infrastructure;
- stronger relationships/team composition;
- better knowledge of the world;
- access to harder/rarer opportunities.

Avoid generic XP bars and level-gating when a concrete world/systemic requirement can do the job.

Early politics and survivor relationships are intended to become more important as the settlement grows.

---

## 13. Monetization boundaries

Future monetization is intentionally non-exploitative.

Standing plan:

- small top banner ad;
- one cold-launch/startup ad, dismissible as the format permits;
- **$0.99 permanent ad-free** option.

Never tie gameplay systems to ad state.

Do **not** add:

- energy systems;
- gacha;
- survivor purchases;
- resource purchases;
- premium currency;
- paid revives;
- paid timer skips;
- power-ups for money.

Timers should be balanced for gameplay, not monetization pressure.

---

## 14. Technical/project reality

Engine: **Godot 4 / GDScript**

Current Web CI uses **Godot 4.7.1**.

This repository is presently reconstructed during CI from:

- `first_fire_alpha01_web_ready.zip`
- `.deploy` Alpha patch fragments
- `.deploy/balance_pass.patch`
- `.deploy/save_schema_reset.patch`
- `.deploy/combat/*` combat source/integration payloads

The exact reconstruction and deployment rules belong in `README_SOPS.md`, not here.

Long-term direction is to place new durable systems in clear modular owners rather than allowing `Game.gd`, giant patches, or UI code to become universal dumping grounds.

---

## 15. Source-of-truth order

When beginning work, use this order:

1. **Newest explicit user instruction**
2. **Current `main` repository state**
3. **`README_SOPS.md`** for coding/repo procedure
4. **`README_CONTEXT.md`** for standing product/design context
5. **`CHANGELOG.md`** for shipped player-facing history
6. Conversation memory only as supporting context

Before **every code edit**, reread the current SOP and context files first.

---

## 16. Near-term development discipline

Do not add a new system just because there is room for one.

For the current Alpha:

- playtest first;
- collect issues and balance observations into batches;
- fix actual bugs and systemic weaknesses;
- deepen existing content before expanding encounter count;
- preserve mobile/browser usability;
- keep new durable systems modular;
- invalidate Alpha saves cleanly when necessary;
- update this file when a durable design rule changes;
- update `CHANGELOG.md` when player-facing behavior ships.
