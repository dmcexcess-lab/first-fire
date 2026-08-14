# First Fire — Changelog

This file tracks player-facing changes to the playable Alpha builds, plus major technical changes that affect development/reliability.

## Alpha 0.2 — Survivor Dashboard & Inspection Pass — 2026-08-13

### Survivors
- Rebuilt the **Survivors** tab as a compact dashboard instead of showing a selector and a full character sheet at the same time.
- Added at-a-glance **CAMP / OUT / BUSY / LOST** counts.
- Survivors currently outside camp are now promoted to their own **OUTSIDE CAMP** section with party names, destination, and live remaining time or decision/tactical status.
- Added **RECENT RETURNS**, using persistent camp history to show the latest expedition return summaries and recovered resources without adding a second expedition-history system.
- The roster now stays concise: name, condition, current activity, fatigue/stress, INSPECT, and SEND OUT when available.

### Survivor Inspector
- Added a full-screen survivor inspector with background, traits, condition/status, fatigue, stress, expedition count, leadership ability, all six skills with XP progress, relationships, extended personal history, and current loadout.
- Equipment management moved into the inspector, including camp gear availability and EQUIP actions.
- Treatment and SEND OUT remain available from the detailed survivor view.
- Opening a survivor inspector **pauses settlement simulation** and closing it restores the previous pause state.

### Camp Inventory / Item Information
- Added **CAMP INVENTORY** access from the Survivors dashboard without changing the Camp tab.
- Camp inventory now groups owned resources, crafted components, and unequipped gear.
- Tapping an item opens detailed field notes plus currently implemented gameplay data such as equipment slot, combat value, protection, capacity, skill bonuses, ammo use, tool tags, and inventory size when applicable.
- Inventory and item inspection use the same modal pause boundary as survivor inspection, so reading details never burns settlement time.

### Web / Compatibility
- Web **EXIT** remains explicitly pinned to save first and redirect to **Google** rather than leaving a frozen Godot canvas.
- No simulation rules or save data shape changed; save schema remains **3**.

## Alpha 0.2 — Architecture Razor — 2026-08-13

### Source / Architecture
- Canonical Godot source now lives directly under `game/`.
- Removed the active ZIP/patch/Base64 reconstruction chain from the repository tree; Git history retains the old packaging if historical inspection is ever needed.
- Extracted expedition/logistics rules into `FFExpeditionRules.gd`.
- Extracted tactical scenario selection/catalog ownership into `FFTacticalScenarios.gd`.
- Extracted camp-life tuning into `FFCampLifeRules.gd`.
- Extracted relationship/social-selection rules into `FFCampSocial.gd`.
- Extracted file/JSON persistence mechanics into `FFSaveCodec.gd`.
- Isolated the remaining outside-world text encounter catalog in `FFFieldEventsLegacy.gd`, explicitly temporary until Alpha 0.3 converts those situations to tactical encounters.
- `Game.gd` now delegates these rules to their owners while retaining low-risk compatibility facades where useful.

### CI / Reliability
- GitHub Pages now builds the canonical `game/` project directly.
- CI now imports/parses the project, runs deterministic architecture smoke tests, boots the real project headlessly, exports Web, and rejects script/parse/load errors before publication.
- The stronger startup gate exposed and fixed three pre-existing Godot 4.7 strict type-inference errors in tactical combat that the older export-only pipeline did not catch.

### Compatibility
- This pass intentionally avoids gameplay balance/content changes.
- Save schema remains **3**.
- The legacy save filename remains unchanged so this behavior-preserving refactor does not unnecessarily reset current Alpha saves.

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
