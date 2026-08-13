# First Fire — Changelog

This file tracks player-facing changes to the playable Alpha builds.

## Alpha 0.2 — Tactical Expedition Encounters — 2026-08-12

### Tactical Combat
- Exploration can now break into a **portrait, turn-based tactical encounter** instead of resolving every dangerous situation as text and dice.
- Tactical encounters use the **actual First Fire expedition survivor**, including their six skills, fatigue, stress, condition, equipped weapon, clothing, pack/tool context, and shared ammunition supply.
- A second survivor sent on the expedition now appears as a real **companion on the tactical board**, follows and supports the lead survivor, and can be injured or killed during the encounter.
- Tactical wounds, deaths, Combat XP, fatigue, stress, and ammunition use return to the persistent camp state after the encounter.
- Tactical combat uses directional vision, fog of war, remembered last-seen zombies, approximate sound locations, facing, doors, glass, environmental obstacles, explosive hazards, stealth/rear advantages, melee, firearms, and physical pre-placed zombies.
- Zombies that currently see the player get a red threat ring plus the global **SPOTTED** warning; once line of sight is broken they pursue the last confirmed position rather than tracking through walls.
- Closed doors open on the first forward action; an open door can then be crossed normally.
- Mobile input disables touch-to-mouse emulation so one touch has one gameplay path.

### Expedition Encounter Types
- **Survivor Rescue:** reach the stranded survivor, then escape. A successful rescue feeds into First Fire's existing survivor/recruit decision popup rather than auto-recruiting them.
- **Explore Location:** reach and search a randomly named location, then escape for a modest extra loot result before the expedition continues.
- **Ambush:** the party is jumped; there is nothing to clear or collect, and the objective is simply to break contact and reach the exit.
- Encounter mix varies by zone, with deeper/industrial travel leaning more toward ambushes and commercial/residential travel leaning more toward locations to explore.
- Tactical encounters replace the expedition's abstract routine-danger resolution for that run, preventing survivors from being hit by a second invisible combat roll after escaping the board.

### Persistence
- Active tactical encounters are saved with survivor health, positions, facing, objective progress, zombie state, doors, broken glass, and removed hazards so a browser reload can resume the same fight.
- Save schema advanced to **3**; older Alpha saves are intentionally invalidated rather than migrated.

## Alpha 0.1 — Hard Save Reset Policy — 2026-08-12

### Saves
- Alpha saves now carry an explicit **save schema version**.
- Saves from an older schema are **invalidated instead of migrated forward**.
- Stale save data is deleted and the game starts fresh rather than maintaining repair/upgrade compatibility code during Alpha development.
- The previous legacy `Resting` save-state compatibility paths and broad loaded-save normalization/repair routine were removed.
- For now, future Alpha changes that alter the save structure may intentionally require a fresh start.

## Alpha 0.1 — Loot / Recovery / Clock Pass — 2026-08-12

### Scavenging & Loot
- Routine expedition rewards now use a **total-haul** roll instead of multiple quantity rolls.
- **Camp Perimeter:** 0–3 total items per run; 25% chance of returning empty-handed.
- Empty-run chance falls as zones get farther from camp: **15% Nearby / 8% Residential / 4% Commercial / 2% Industrial**.
- Maximum routine hauls rise gradually by zone: **3 / 4 / 5 / 6 / 7** items.
- Scavenging skill can occasionally add one extra item, but cannot exceed the zone cap.
- High zone depletion/pressure can reduce the final haul.
- Routine loot priority was rebuilt around: **Dirty Water most common → Raw Food → materials → Clean Water → Cooked Food rarest**.
- Cooked food remains intentionally rare in the world because Raw Food can be processed efficiently at camp.

### Survivor Recovery
- Survivors now **recover fatigue and stress automatically whenever they are Available and doing nothing**.
- Idle recovery does not make survivors unavailable; they can be assigned to work or expeditions immediately.
- The manual **REST / STOP REST** action has been removed.
- Hurt/Wounded natural recovery now progresses while the survivor is idle and Available.
- Treatment completion returns survivors to Available rather than leaving them in a Resting state.
- The camp event option to give someone time to rest now grants an immediate fatigue/stress reduction instead of locking them into Resting.

### Alpha Clock
- Full in-game day accelerated from **4 real minutes to 2 real minutes** for Alpha testing.
- Expedition/crafting/building timer lengths are otherwise unchanged.

## Alpha 0.1 — Systems & Balance Pass — 2026-08-12

### Encounters
- Recruitment protection now guarantees a **recruitment opportunity**, not a forced recruit.
- Declining or resolving a survivor encounter no longer causes the same companion event to repeat forever.
- Camp Perimeter runs do not count toward recruit-protection progress.
- **Injured Stranger** now has meaningful branching outcomes: bring them home, treat them, give supplies, or leave them.
- Helping a stranger without recruiting them can create a later follow-up encounter.
- **Someone Inside** can now resolve as a survivor, infected threat, empty/animal result, or hostile human encounter.
- **The Dog** now has persistent follow-up behavior and can lead to caches or location information.
- **The Backpack, Locked Garage, The Gunshot, Abandoned Patrol Car, The Barricade** now produce explicit result screens and distinct consequences.
- **The Barricade** can lead to trade or information outcomes.
- **Hardware Cage, Neighborhood Clinic, Construction Trailer, Miller Street Market** have fuller branching logic and can preserve unresolved sub-areas for later visits.
- **Smoke in the Distance** was removed from the new random encounter pool for now, while compatibility handlers remain for existing saves.
- Encounter options are now disabled/greyed out when their requirements are not met.

### Food & Water
- Fire Pit cooking changed from **1 Raw Food → 1 Cooked Food** to **1 Raw Food → 2 Cooked Food**.
- Fire Pit boiling changed from **1 Dirty Water → 1 Clean Water** to **1 Dirty Water → 2 Clean Water**.
- Early scavenging loot was rebalanced to make food substantially more common relative to water.
- Crafting UI now shows recipe output quantities.

### Web / UI
- On the Web build, **EXIT** now saves and leaves the game page instead of freezing on a dead Godot canvas.
- Desktop builds still use a normal application quit.

## Alpha 0.1 — First Playable Build

- Playable Godot 4 build with persistent save data.
- Core navigation: **Camp / Craft / Build / Survivors**.
- Active-time game clock with pause-on-background behavior.
- Expeditions, scavenging, loot, fatigue, stress, injury, skills, crafting, building, survivor histories, relationships, and early camp politics.
- Initial progression from one survivor, a sleeping bag, and a fire pit toward a five-person cabin settlement.
- Alpha menu art and pause-screen artwork added.
- Phone-width layout fixes and fixed four-button bottom navigation.
- Web export and GitHub Pages deployment added for browser/iPhone playtesting.
