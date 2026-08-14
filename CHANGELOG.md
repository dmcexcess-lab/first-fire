# First Fire — Changelog

This file tracks player-facing changes to the playable Alpha builds, plus major technical changes that affect development/reliability.

## Alpha 0.3E — Living Camp View — 2026-08-13

### Living Tactical Camp
- Replaced the active per-tab Camp/Craft/Build splash banners with one persistent **living camp view** rendered from the same tactical tile and survivor art language used outside camp.
- The pause/main menu now uses that same live camp scene as its background instead of the separate zombie photograph, unifying the game's presentation.
- Camp structures appear at stable visual anchors as they are actually built: Fire Pit and sleeping space first, then rain catcher, shelter, storage, workbench, sewing table, garden, noise line, and cabin. Active construction gets a visible progress marker before completion.
- Survivors are the real persistent survivor sprites. Their cosmetic camp position follows authoritative state: crafting walks them to the selected station, building sends them to the relevant construction anchor, garden work goes to the plot, recovery goes to sleeping/cabin space, available survivors idle around camp, and expedition survivors disappear from the settlement view.
- Camp movement is presentation-only; work timers, status changes, resources, expeditions, and progression remain owned by the existing simulation.
- Camp daylight follows the actual settlement clock. Night darkens the map while the First Fire and completed cabin add warm local glow.

### Alpha Lighting Test Access
- Every new founder now starts with **Flashlight** equipped in the Secondary slot so tactical day/night/blackout lighting can always be tested immediately.
- Save schema advanced to **6** and older Alpha saves are intentionally invalidated instead of migrated.

### Architecture / CI
- Added `FFCampView.gd` as the living camp/menu presentation owner.
- Expanded deterministic architecture smoke coverage for camp station/building anchors and permanent CI validation for the new module, schema, and founder flashlight guarantee.

## Alpha 0.3D — Tactical Senses, Timing & Art — 2026-08-13

### Sprite / Tile Overhaul
- Replaced the flat tactical ground/prop primitives and procedural actor bodies with an original reusable tactical atlas covering ground materials, themed walls, open/closed doors, windows, furniture, shelves, vehicles, industrial clutter, survivors, infected, corpses, weapons, and Secondary light items.
- Survivor appearance remains randomized/persistent but now selects from eight readable sprite identities; infected use eight sprite variants weighted by their existing environment families.
- Equipped weapons and Secondary lighting gear remain visible beside the survivor, now as atlas art instead of tiny generic lines.
- Doors and windows now read as actual structural tiles instead of ambiguous outlines, and authored layout validation checks both party spawns as well as exits.

### Day / Night / Power
- Every tactical encounter independently rolls day or night plus an environment-specific power state. The same Gas Station, House, Apartment, Store, Alley, or Warehouse can therefore appear under different lighting conditions.
- Locations have different chances of retained power; Drainage Wash has none.
- Authored interiors are now explicit physical metadata rather than inferred from floor color.
- Daylight enters interiors through windows. Glass transmits sight and light, while walls, closed doors, and tall props block them.
- Powered fixtures illuminate the same authored locations at night; blackout versions remain dark enough for portable lights to matter.

### Light / Vision Interaction
- Shortened the survivor vision cone and made actual cell light determine whether distant cells inside that cone are visible.
- Bright fixtures, windows, flashlight beams, and radial lights can reveal pockets beyond surrounding darkness instead of lighting being merely a cosmetic overlay.
- Infected vision now also depends on target illumination, so a lantern or flashlight can help you see while making you easier to spot.
- Added Headlamp, Lantern, Glow Stick, and Road Flare Secondary gear alongside Flashlight, with directional vs radial light profiles and distinct colors/ranges.

### Real Tactical Time
- Tactical ticks now derive survivor movement/turn/stance/interaction/attack costs from equipped load, fatigue, wounds, skills, stance, and weapon timing.
- Infected receive persistent pace, attack-speed, and mass profiles; different infected can match a survivor tile-for-tile, lose ground over successive moves, or remain persistently faster/slower.
- Companion movement and attacks use the same derived timing rules instead of a fixed universal cadence.
- HUD now exposes current tick, derived step cost, and load band so the scheduler is inspectable rather than hidden.

### Sound / Awareness / Interaction
- Footstep labels now reflect surface (creak/tap/rustle/scuff/etc.) and high fatigue/load can generate breathing noise.
- Added more infected and environmental sounds including shuffle, moan, fixture hum/buzz, house creaks, pipe knocks, metal rattle, shelf ticks, wind, and gravel.
- Off-screen sound estimates are now fuzzy within a bounded radius of the true source instead of a random square that could point somewhere unrelated.
- Sound labels render in a wider bounded callout so longer words no longer clip off the tile.
- Infected hearing also uses approximate locations for weaker sounds rather than perfect coordinates.
- When one infected visually spots a survivor, nearby infected are alerted to the same vicinity instead of behaving as isolated units.
- A nonlethal melee hit reveals the attacker to the struck infected even when the approach qualified as stealth.
- Tapping/clicking an adjacent door now explicitly uses it, so open doors can be closed; the FORWARD control still handles movement through an already-open doorway.

### Alpha Saves / Architecture
- Save schema advanced to **5** and old Alpha saves are invalidated rather than migrated.
- Removed the schema-4 Tool-slot Flashlight compatibility path.
- Added `FFTacticalTiles.gd`, `FFTacticalTime.gd`, and `FFTacticalSound.gd` as durable owners for presentation atlas rendering, derived action timing, and sound-localization rules.
- Added deterministic smoke checks proving encumbrance changes real movement cost and fuzzy sounds remain near their true source.

## Alpha 0.3C — Tactical Lighting & Secondary Gear — 2026-08-13

### Lighting Overhaul
- Tactical boards now render through a real low-light pass instead of uniform flat brightness.
- Added authored fixed lighting to the 0.3B environments: alley neon/security light, gas-station canopy/store light, house lamps, apartment fluorescents, shop neon/fluorescents, and warehouse flood/warning lights. Drainage washes intentionally remain mostly dark.
- Fixed light color and falloff are data-driven and respect tactical wall/door/obstacle occlusion.
- Neon/fluorescent/warning emitters get subtle low-refresh flicker/glow animation while the more expensive light map only recalculates when tactical state changes, keeping the Web/mobile path lightweight.
- Darkness overlays both environment and characters, while visible light sources add colored wash so pink/cyan neon, warm interiors, cold fluorescents, and flashlights read differently.

### Flashlights / Secondary Slot
- Flashlight moved from the general Tool slot to a new **Secondary** equipment slot, allowing Weapon + Secondary + Tool to coexist.
- The existing slot-driven equipment backend handles Secondary generically, leaving room for future radios, binoculars, detectors, or other field utility items without special-case inventory code.
- Equipped flashlights cast an occluded directional cone from the survivor's facing and retain a +2 tactical view-range benefit.
- Companion flashlights illuminate from the companion's own position/facing too.
- Existing schema-4 saves remain valid; an older survivor who already had Flashlight in Tool is recognized as carrying the light without rewriting the save.
- Flashlights can still be scavenged and are now craftable at a Workbench from Plastic, Scrap Metal, and Hardware.
- Survivor inspection now shows Secondary separately and displays implemented light reach/view data.

### Architecture / Performance
- Added `FFTacticalLighting.gd` as the durable owner for ambient profiles, light-source presets/falloff, Secondary light-item cone math, and glow animation rules.
- `FFTacticalEnvironments.gd` owns authored fixed-light placement; `FFCombat.gd` owns occlusion, recalculation timing, and render integration.
- Save schema remains **4**; Secondary is an optional equipment dictionary key and therefore does not require a reset.

## Alpha 0.3B — Tactical Environments & Escape Routes — 2026-08-13

### Recognizable Tactical Places
- Replaced the three generic board shapes with authored environment families that read as actual places: **Back Alley, Gas Station, Residential House, Apartment, Corner Store, Warehouse Yard, and Drainage Wash**.
- Environments now carry distinct ground treatments, walls, room shapes, recognizable props, entry positions, and zone-appropriate selection pools.
- Gas pumps/storefront, house rooms/furniture, apartment corridor/units, shop aisles, dumpsters/neon, warehouse pallets/machinery, and wash debris now visually identify the location before reading the HUD.
- Tactical **objective and location are separate systems**: rescue, search, and ambush objectives are combined with compatible physical places instead of selecting a generic layout from the objective.

### Universal Escape
- Every tactical environment now declares at least one reachable escape point.
- Some layouts have a single escape route; others have two or three exits.
- Reaching **any EXIT** immediately allows the party to leave, even if a rescue/search objective is unfinished. Survival is always a legitimate choice.
- Leaving before an optional objective completes forfeits that tactical opportunity/reward but does not count as a tactical disaster.
- Exit markers remain readable through fog and the tactical HUD shows the number of available routes.
- Added deterministic CI checks that every authored environment variant has reachable exits from its party spawn.

### Saves
- Save schema remains **4**. New tactical contexts store environment ID/variant, while already-open older schema-4 tactical encounters fall back to equivalent environment families.

## Alpha 0.3A — Tactical Spawn & Expedition Simplification — 2026-08-13

### Tactical Encounter Reliability
- Fixed the starting-zone oversight that made **Camp Perimeter incapable of spawning tactical encounters** even though it is the only zone unlocked in a new run.
- Tactical playtest rates are now 65% Camp Perimeter, 70% Nearby Streets, 75% Residential Blocks, 82% Commercial Fringe, and 90% Industrial Edge.
- Added drought protection: after two consecutive normal field runs without tactical combat, the next normal run is forced tactical.
- Camp Perimeter now has its own explore/ambush scenario mix and perimeter-specific location names instead of falling through to Industrial Edge content.
- A tactical run that reaches its encounter point while another narrative overlay is open now waits there; it can no longer silently complete before the tactical board opens.

### Expedition Dispatch
- Removed **Loot Focus** from the send-out screen. Expedition choice is now survivor, destination, and optional companion.
- Routine scavenging no longer receives Food/Water, Materials, or Gear focus multipliers; each zone's natural loot table is authoritative.
- Empty resource runs now report **returned empty-handed** instead of displaying an unexplained `()`.

### Presentation Policy
- Added a durable project rule that future First Fire art should avoid third-party franchise names/logos/characters unless explicitly requested and appropriate.

## Alpha 0.3A — Encounter, Fatigue & Menu Tuning — 2026-08-13

### Tactical Encounters
- Tactical encounters now roll independently from the temporary legacy text-event chance instead of being double-gated.
- Alpha playtest rates are now 55% on Nearby Streets, 65% in Residential Blocks, 75% on the Commercial Fringe, and 85% at the Industrial Edge.
- Camp Perimeter remains a routine non-tactical scavenging zone.
- Legacy text field events can still occur when a tactical encounter does not fire; they remain temporary pending the planned all-tactical field conversion.

### Fatigue
- Added one central fatigue-gain multiplier in `FFCampLifeRules.gd`.
- Fatigue gained from normal expeditions, tactical encounters, crafting, building, and garden tending is now doubled.
- Automatic idle fatigue recovery is unchanged, so repeated work/runs should now create meaningful exhaustion pressure.

### Main Menu
- Replaced the previous main-menu zombie art with the newly generated darker PG-13 survival-horror zombie background.
- The new art is stored as a Web/mobile-friendly JPEG to keep the browser payload modest.

## Alpha 0.3A — Tactical Character Graphics — 2026-08-13

### Survivors
- Tactical survivors now use persistent modular appearances generated when the survivor is created, including body build, skin tone, hair, clothing palette, accent color, and optional headwear.
- The same survivor keeps the same tactical identity across encounters instead of reverting to a generic colored circle.
- Lead and companion survivors retain distinct selection rings, readable facing, backpacks when equipped, and now render as small top-down people rather than tokens.
- Equipped weapons render as separate silhouettes floating beside the survivor and rotate with facing. Knives, clubs/bats, hammer, spear, crowbar, hatchet, pistol, and shotgun have distinct shapes.

### Infected
- Infected now vary visually across civilian, worker, service/retail, medical, decayed, and heavy silhouettes.
- Zone weighting makes industrial areas favor worker/heavy looks, commercial areas favor service looks, and residential areas favor civilian/decayed looks.
- These are cosmetic families only in 0.3A; zombie combat behavior/stats were not rebalanced.
- Dead infected now remain as visible corpse silhouettes rather than red X markers.

### Combat Feedback
- Melee/firearm hits get a brief impact flash.
- Firearms get a short muzzle-flash effect.
- Companion attacks and infected hits use the same visual feedback language.
- Character art is procedural/vector-style for now, keeping Web/mobile payload small while allowing authored sprite layers later.

### Persistence / Architecture
- Added `FFTacticalVisuals.gd` as the presentation-data owner for survivor appearance, zombie visual families, and weapon silhouettes.
- Survivor appearance is now persistent state, so save schema advanced to **4**. Older Alpha saves are intentionally invalidated rather than migrated.

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
