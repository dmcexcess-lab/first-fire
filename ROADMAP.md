# First Fire — Extraction + Base Sim Roadmap

The October 26, 2026 user direction supersedes the former Beta feature freeze for field combat. First Fire is becoming an extraction-shooter + base-sim hybrid while preserving useful camp simulation. Ship one coherent solo loop before widening scope.

## Turn-based neighborhood — implemented

- Solo raids use two AP per turn in a connected 60×54 neighborhood built from nine authored locations. Near/middle/deep bands contain progressively more pre-existing zombies and richer physical loot.
- Tap to preview and confirm movement or an attack; pan/zoom, sound/threat previews, crouch/sprint, reload, use, shove, tools, end turn and extraction are available on the portrait interface.
- Zombies respond after the player turn, investigate sound locations, pursue on sight and can move twice or move once and attack. Noise attracts existing actors; it does not spawn a horde.
- Entry has a known exit; other exits are discovered. Extracting costs two AP and a hit during the zombie phase interrupts it.
- Physical items, including marked gear, use the finite pack capacity. Leftover container items can be swapped with carried items for one AP. Ammo and gear persist; actual return deposits the haul.
- Camp systems and schema-8 saves remain intact; a legacy real-time encounter can continue on its original map under the turn controller.

## Next bounded passes

1. Playtest actual phone and mobile Safari controls, sound readability, zombie pacing and extraction difficulty; tune with player evidence.
2. Deepen the connected neighborhood with more authored paths, meaningful obstacles and route/exit variation while preserving reachable fallback exits.
3. Investigate world streaming and cross-raid location persistence before scaling substantially beyond the current bounded grid.

Human hostile factions, PvP, vehicles, companions and conventional character levels are outside this slice.

## Current game loop

**Watch the living camp → notice needs/shortages → inspect or assign survivors in-world → prepare a single-survivor raid → choose a distance and commit any route supplies → turn-based field raid immediately → escape with physically recovered resources/rescues → advance the authored route hours on return → come back to a visibly changing camp → repeat.**

The living camp is the primary home/menu surface. The old CAMP / CRAFT / BUILD / SURVIVORS tab bar is retired from active play rather than preserved as parallel navigation. On phones the camp is zoomed and pannable so structures and people remain readable instead of shrinking the full 18×11 settlement into one strip. Normal management starts by touching the camp itself: survivors open inspection and deliberate assignments, the communal stash opens inventory/resources, the First Fire provides survival crafting, the work board owns camp expansion, built crafting stations expose their recipe sets, and the camp edge/gate owns expedition dispatch. The starter scene is mostly wilderness; future construction locations are not shown as empty placeholders until work begins. Contextual sheets may reuse mature underlying UI logic, but they are entered from physical camp objects and return to the camp.

The game has **no scripted ending**. A settlement with every building completed and roughly **15–18 living survivors** is the mature/top-level state; play can continue indefinitely after that.

The hard population ceiling is **18 survivors**.

## Permanently cut scope

These are no longer planned for First Fire:

- 3D camp rendering—the living 2D tactical-style camp is the final camp presentation and home/menu surface;
- full vehicle driving/fuel/maintenance logistics beyond the single Expedition Vehicle unlock used to gate Very Far travel;
- multi-survivor raids and tactical companion AI;
- unrelated foundational modes beyond the approved extraction/base-sim direction.

Removing these is intentional scope control, not deferred work.

## Beta completion work

### Camp life, interaction and politics

Finish tuning the systems that already exist:

- make the living camp itself carry the normal management/navigation load: survivor taps open stats/inventory plus training/maintenance/treatment assignments, the First Fire and Workbench open their physical crafting surfaces, built structures expose contextual details, the communal stash opens inventory/resources, and the gate opens a send-out chooser;
- keep the legacy four-tab navigation hidden in the active UI and continue removing assumptions that Craft/Build/Survivors are standalone destinations;
- keep mood/need/virus state glanceable on the camp through compact floating indicators rather than forcing routine roster-panel inspection;
- autonomous relationship/politics-based chatter in the living camp;
- survivor moodlets driven by hunger, thirst, sleep, fun, safety, and hygiene; eating/drinking/sleep/fun remain autonomous idle behavior while productive labor is player-assigned;
- an active camp work loop covering camp chores/maintenance, crafting/building, treatment, pet care, training and expeditions; eating, drinking, normal sleep, fire-watching, socializing and fun remain autonomous; **idle camp time lowers fatigue, productive work/expeditions raise it, and 100 fatigue forces a 3–5 in-game-hour Exhausted bed rest that resets fatigue to 0**; assigned work can still make survivors miss normal meal/sleep windows if the player overworks them;
- camp duty is **not a daily quota**: at most one random timed maintenance problem from **Poke Fire, Chop Wood, Clear Area, Stack Supplies** is active, problems are spaced roughly 240–540 settlement seconds apart, and each gives roughly 90–150 seconds to respond; the work board exposes the countdown plus a specific fire/condition consequence for missing it; the shared touch-first interaction still runs **without pausing settlement**, the assigned NPC visibly performs the work, and bounded duty-rotation history remains available for social/political reactions;
- persistent camp condition/cleanliness/maintenance that degrades when neglected, visibly affects the living camp, grants a mood bonus when well kept, is neutral when merely acceptable, and applies escalating negative mood pressure at neglected bands (target 0/-1/-2/-3);
- each survivor should have at least one meaningful daily activity, whether a player-assigned productive action or autonomous life behavior, without turning meals/sleep/fun into manual scheduling;
- authored **camp pressure events** layered alongside social/political events, with low enough frequency to avoid popup spam: zombie breaches use a hidden luck roll plus Noise Line/Watch Post infrastructure rather than survivor stats/player combat skill and can destroy buildings, ruin supplies, wound/kill/expose survivors; weather/spoilage events use stored hidden rolls plus RP/resource choices; one-survivor isolation events and larger-camp morale events keep the event pool relevant across population tiers;
- rescued dogs/cats as persistent Tamagotchi-style camp pets whose affection is maintained through PLAY/LOVE assignments; pets consume no camp food/water, can leave if neglected, and each retained pet contributes exactly one random material or Raw Food per day;
- relationship drift from meaningful positive/negative interactions;
- shortages and repeated expedition duty feeding camp opinion;
- coordinator → formal election progression;
- recurring confidence challenges when an elected leader loses support;
- camp events for shelter pressure, duty complaints, food, theft, fights, burnout, perimeter danger, personal requests, shared meals, shortage politics, and **positive survivor-arrival stories whose frequency increases with a stable, maintained, happy, developed camp, with a two-full-in-game-day post-accept cooldown preventing back-to-back passive recruits**;
- enough event weighting/cooldowns that camp life feels alive without becoming popup spam.

The core presentation goal is **watch, prioritize, assign, prepare, grow**. The player should feel like they are nurturing a small settlement, not operating a spreadsheet with a decorative camp preview.

### Tactical field completion

Outside-world events remain physical/tactical. Standard Send Out is now always a tactical map, including previously discovered special sites; there is no routine passive expedition-result branch. Finish retiring any remaining legacy field-text path so camp narrative is the only routine text-event space.

Deepen the implemented turn-based tactical language rather than adding another combat system.

**Next tactical pass:** playtest turn cadence, readable noise/threat feedback and navigation on mobile; then expand authored route and exit variety without compromising the settlement pause or extraction-first design.

Current neighborhood population is initialized once with at least 5/10/15 regular infected across near/middle/deep depth bands, plus the inherited scenario seed. Noise attracts existing zombies; it does not create new ones. Individual infected remain weak and crowding creates pressure. The weapon ladder, finite ammunition, bite-only virus exposure, physical loot families, zone depletion and Lock Pick durability remain owned by their existing systems. Up to 5/8/12 searchable authored containers are retained across the three bands, with richer loot tables deeper in the neighborhood.

Continue completion work around:
- recognizable locations;
- day/night/power/lighting;
- vision, sound, stealth and action timing;
- doors, windows, hazards and exits;
- rescue/search/ambush objectives;
- equipment interactions and readable consequences;
- mobile readability and performance.

### Items and crafting

Every active `FFData.GEAR` item must be represented in the finished equipment loop. Crafting covers survival gear, the **Crossbow**, and the **Lock Pick**; **all replacement firearms are field-found only**. Flashlight and Firecracker are also field-found only; Lock Pick may be found or crafted and lasts **1–3 unlocks**. Backpacks are **field-found only** and define the carry ladder: **4 loot-item slots with no pack, 6 with common packs, 8 with better packs**; solo raids use the selected survivor's capacity. Carry is count-only: one recovered resource/component unit equals one slot, with no weight or item-size calculation. The shared Ammo resource remains retired; ranged pressure now includes finite loaded/spare rounds carried persistently on each gun and Workbench resupply for 1 Scrap Metal, alongside reload time, pump cycling and authored range/falloff. Hatchet remains deliberately expensive/late because it is the one-hit 1H melee tier.

**No expedition has an abstract post-run haul.** Standard runs, legacy-compatible runs, and resolved tactical special sites must not roll extra resources/gear after extraction. Camp inventory changes only from tactical container/corpse/on-map pickup results that were physically recovered and carried out. Narrative field events may reveal information or people, not mint scavenged supplies outside the tactical board.

Tactical encounters open immediately and **pause settlement time**. Once tactical resolves, the party does not teleport home or fast-forward the camp: it remains **Away** for the route's 3h/5h/8h/12h/18h timer while normal camp simulation resumes. Physically recovered haul remains attached to that expedition and only enters communal storage on actual return. Camp pressure events/fresh maintenance require someone home to receive them.

The tactical HUD exposes all five equipment slots: Weapon, Secondary, Tool, Clothing and Pack. Container searches produce immediate floating feedback over the searched object (**+resource**, **EMPTY**, or **CARRY FULL**) in addition to the message log. Explore objectives can place a real named gear pickup on the board, but this is intentionally uncommon near camp: Camp Perimeter has a 30% special-gear opportunity and Nearby Streets 50%, while Medium and farther currently guarantee one. No-gear Explore runs are pure scavenging objectives. Any named gear is only retained after physical recovery and successful escape. Every current gear catalog entry belongs to a zone-tiered field-loot pool.

Crafting is contextual camp interaction, not a standalone navigation mode. **First Fire / Fire Pit is always present from Day 1** and, before a Workbench exists, the only available crafting is Cook Food, Boil Water, and Bandage. The first Workbench is intentionally light at **2 Wood + 1 Scrap Metal** with no building prerequisite; basic tools/weapons/components live there, while **Crossbow, Sledgehammer, Hatchet, Bolt Cutters, and Toolbox require a built Armory**. The same physical hearth progresses through **Tavern → Tavern Kitchen → Tavern Brewery**: Community Stew improves early raw-food conversion, Kitchen Supper improves it again, and the Brewery converts abstract fermentable Raw Food + Clean Water into **Beer**, which can be consumed by autonomous Tavern social sessions for a stronger mood/stress benefit. First Aid Kits are rare found-only medical supplies. Zombie Cure is the rarest direct medical find and can also be crafted at a built Infirmary from **2 Zombie Corpses** physically harvested from killed infected; each corpse costs one expedition carry slot. Built Workbench, Sewing Table, and Infirmary objects expose their own recipe sets when tapped.

### Final building tree

The final build list is:

1. Large Tarp
2. Rain Catcher
3. Workbench
4. Noise Line
5. Tavern
6. Sewing Table
7. Garden Plot
8. Water Tank
9. Tavern Kitchen
10. Barracks
11. Infirmary
12. Watch Post
13. Tavern Brewery
14. Armory
15. Dormitory

The camp grows through readable upgrade lanes instead of additive housing clutter. **Shelter:** Bedroll Camp (3) → Large Tarp (7) → Barracks (12) → Dormitory (18), with an exact hard recruitment cap at every tier; rejected recruits are simply gone. Each shelter upgrade also improves 8-hour sleep recovery, Rested-moodlet gain, Stress recovery, and ordinary idle recovery. **Hearth:** First Fire → Tavern → Tavern Kitchen → Tavern Brewery. Each Tavern stage is a paid construction project with its own visual upgrade and progressively stronger social recovery; the Kitchen adds proper food-production gains and the Brewery adds Beer. **Utility:** cheap first Workbench → Sewing/Water/Garden/Infirmary/Armory dependencies. **Security:** Noise Line → Watch Post, with Watch Post feeding the late Armory gate. Storage remains a baseline camp fixture rather than a build project. Late buildings are deliberately expensive and dependent on earlier infrastructure rather than isolated resource sinks. The physical work board is the construction planner; unbuilt anchors stay hidden, active construction appears at its destination, and completed structures remain tappable.

### Mature settlement state

A settlement becomes **mature** when it has:

- at least 15 living survivors;
- every planned building completed;
- an elected leader.

This produces a milestone event only. It does **not** end the save.

## Beta → Release 1.0 gate

First Fire does **not** become 1.0 because a calendar date or feature count says so. Release happens only when all of these gates are satisfied:

1. **No known release-blocking bugs.** Normal play, save/load, browser lifecycle, living-camp interaction, tactical encounters, camp simulation, crafting/building, and long-run play must survive Beta testing without known blockers.
2. **All systems and timers are balanced.** Economy, resource use, construction, crafting, recovery, expedition cadence, camp events, politics, recruitment, and progression must feel coherent across early, middle, and mature settlement play.
3. **Final game speed is decided.** The current direct **300-real-second / five-minute game day** is the active Beta tuning. There is no secondary simulation-speed multiplier; remaining Beta work may tune individual authored durations without reintroducing a hidden global speed layer.
4. **Combat and tactical systems are balanced and reliable.** Action timing, movement, vision, lighting, sound, stealth, melee, firearms, infected behavior, hazards, objectives, loot, exits, and encounter frequency must all work consistently and produce the intended survival/extraction feel.
5. **Ads work under the existing non-exploitative policy.** Advertising/ad-free purchase behavior must function without influencing gameplay systems or progression.
6. **Android APK release build is complete and tested.** The Android package is the release target for 1.0; packaging/device testing is part of the release gate, not an afterthought.

When all six gates pass, that build becomes **First Fire 1.0**. Until then the project remains a Beta candidate / Beta test project with no new feature work.

## Shelved development state

As of this scope lock, First Fire is intentionally shelved while work moves to the next project. Returning to First Fire means **Beta verification against the release gate above**, not reopening the feature roadmap.

Schema **8** is the deliberate camp-progression reset created by replacing the old additive Cabin/Bunkhouse/Communal Table tree and removing the free starter Workbench. Once Beta testing begins from this structure, save compatibility becomes a player-facing promise and further schema changes should be treated much more conservatively.