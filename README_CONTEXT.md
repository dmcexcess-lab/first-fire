# First Fire — Project Context

> **MANDATORY CONTEXT RULE FOR GPT:** At the start of every new user prompt that requests code or repository changes, fetch and reread both `README_SOPS.md` and this file from current `main`, then inspect the repo state relevant to that prompt. This happens once per coherent prompt/change request.

This file records durable product/design context. `README_SOPS.md` records process, `ARCHITECTURE.md` records module ownership, and `ROADMAP.md` records intended direction. Newest explicit user instruction plus current `main` wins over older context.

## Current game

**First Fire** is a mobile-first Godot 4 / GDScript zombie-apocalypse survivor settlement game combining a living camp-management home screen, extraction-style expeditions, persistent survivor consequences, and portrait turn-based tactical encounters.

Current milestone: **Beta Candidate — Feature Freeze**.

Live Web build: `https://dmcexcess-lab.github.io/first-fire/`

The **living camp is the primary game/menu surface**. The old CAMP / CRAFT / BUILD / SURVIVORS tab bar is retired from active play rather than preserved as parallel navigation. The phone view is intentionally zoomed and pannable instead of shrinking the whole settlement into a minimap; normal management is reached by touching physical camp entities and opening contextual sheets/overlays from them.

Feature-freeze means deepen/unify existing systems rather than add new pillars.

## Design pillars

- **Simulation first.** Drama comes from interacting systems and persistent state.
- **The camp is the Tamagotchi.** The player watches a small settlement live, identifies what it needs, sends survivors out to bring resources home, and sees the camp physically grow and change.
- **Camp is interface.** Survivors, stations, plots, the communal stash, the fire, work board, buildings, and gate are touch targets in the living camp. Detailed panels are contextual views opened from that world, not top-level menu destinations.
- **Survivors are people.** Gear, health, fatigue, stress, relationships, history, wounds, infection, deaths, and a small number of meaningful stats matter.
- **No conventional levels.** Capability comes from three use-based stats, equipment, condition, traits, tactical decisions, and camp infrastructure.
- **Persistent consequences.** Field outcomes feed back into camp/world state.
- **Extraction over extermination.** Survival, rescue, investigation, loot, and escape matter more than clearing every enemy.
- **Low content count, high implementation depth.**
- **Intentional management.** Eating, drinking, sleeping, fun, recovery, and social behavior are systemic where natural; productive chores, maintenance, crafting, building, pet care, treatment choices, quarantine, and expeditions are deliberate assignments/decisions.
- **Phone/Web first.** Touch, portrait layout, browser lifecycle, storage, pause/resume, and mobile Safari are architectural inputs.
- **Original presentation.** Avoid third-party franchise identifiers unless explicitly requested and appropriate.

## Three-stat survivor model

The active survivor progression model contains exactly three stats:

- **Combat** — melee/firearm handling and combat output.
- **Agility** — movement, stealth, sprinting, avoidance, and physical escape.
- **Leadership** — camp influence, social decisions, candidate standing, and politics.

The former **Scavenging, Survival, Medical, Technical, and Social** stats are removed from the active survivor model. Do not recreate them as hidden parallel progression systems. Crafting, treatment, searching, scavenging, and technical interactions should instead use authored rules, tools, resources, traits, infrastructure, condition, and player choices where appropriate.

Backgrounds seed the three current stats rather than six specialist skills. XP/progression is only valid for Combat, Agility, and Leadership.

## Tactical combat

Outside-world danger is tactical/physical. Camp social life/politics remains narrative/dialogue.

Tactical encounters use the actual expedition party: one controlled lead plus an optional AI companion. Current encounter types are **Rescue, Explore Location, and Ambush**. Rescue calls can reveal either a stranded survivor or a stranded camp pet (dog/cat); pets use the same physical reach/contact/escort/extract structure. Wounds, deaths, fatigue, stress, magazine/reload state, carried loot, and successful **Bite** exposure results return to camp state; companion HP/condition and companion bite exposure are also persisted. Active encounters persist across reloads. Tactical play pauses normal settlement simulation.

The active combat layer is intentionally compact:

- **Melee ladder** — fists 3–5 clean hits; Utility Knife 2–3; ordinary 1H melee 2; ordinary 2H melee 1–2; Sledgehammer 1; Hatchet 1. Hatchet is intentionally the rare/expensive one-hit 1H option.
- **Crossbow** — craftable Workbench ranged weapon, one shot before reload, 2–3 hits to kill, and a physical 7-tile medium range.
- **6-Shot Revolver / 12-Shot Automatic** — found-only pistols. Both are strongest at short range but may fire at any visible target; hit chance falls off with distance.
- **Double-Barrel Shotgun** — found-only **one-handed** firearm, 2 shells, 3 projectiles per shot, tighter spread, physical 5-tile pellet range.
- **Pump Shotgun** — found-only, 6 shells, explicit pump action between shots, 5 projectiles per shot, wider spread, physical 4-tile pellet range.
- **Medium Rifle** — found-only, 20-round magazine, medium optimal range, may fire to any visible target with distance falloff.
- **Long Rifle** — found-only, 5-round magazine, long optimal range, may fire to any visible target with distance falloff.
- **Reload model** — there is no camp Ammo resource. Ranged weapons use tactical magazine/chamber state and explicit reload actions; Pump Shotgun additionally requires cycling the pump.
- **Stealth** — Agility-driven quieter crouched movement with positional stealth-attack opportunity; its tactical action cost is deliberately and materially slower than walking.
- **Sprint** — Agility-driven movement with a deliberately and materially lower action cost than walking, louder noise, and improved grab avoidance.
- **Forward** — dedicated touch movement action in the former Guard control slot.
- **Shove** — spacing/stagger action; heavier infected resist it more.
- **Mob pressure** — a lone infected is deliberately weak. Multiple nearby infected improve attack pressure, add only a small damage bump, shorten their attack cadence, and can pull nearby packmates directly into the chase. The danger curve should come primarily from density/positioning rather than inflated individual HP/damage.
- **Scratch / Bite attack split** — infected attempt a Scratch most of the time and a Bite rarely. Scratch has the higher hit chance and low physical damage. Bite has a much lower hit chance, substantially higher physical damage, and is the **only** tactical attack that can expose a survivor to the zombie virus.

**There is no armor mitigation.** Clothing must not cancel or reduce incoming physical damage. Clothing may remain as identity/crafting/utility gear, but it is not an armor stat layer. Equipment weight/size is not a carry or tactical-timing stat; expedition haul is governed by item slots.

Combat and Agility are the only survivor stats that affect tactical fighting/movement. Leadership does not secretly improve attacks. **Weapon tier owns damage/kill count; Combat primarily improves attack reliability rather than scaling raw damage enough to collapse the ladder.** Infected durability is compressed to roughly **7–10 HP** across LIGHT/MED/HEAVY mass classes, with mass affecting shove/attack behavior more than sponge HP.

`FFThreeStatRules.gd` owns the three-stat catalog, weapon classes/profiles, and Agility movement/stealth/sprint math. `FFTacticalBalance.gd` owns tactical tuning using Combat/Agility only. `FFCombatThreeStat.gd` remains the combat-model specialization over the established `FFCombat.gd` board/runtime foundation; active play routes through `FFCombatVirus.gd`, which records successful Bite hits for lead/companion virus exposure without treating Scratch or generic damage as infection events.

## Tactical world

`FFTacticalScenarios.gd` owns objectives/scenario selection. `FFTacticalEnvironments.gd` owns authored places/geometry/props/entries/exits. `FFTacticalLighting.gd` owns tactical lighting rules. `FFTacticalTiles.gd` owns atlas rendering. `FFTacticalTime.gd` owns low-level fatigue/condition/stance/weapon action timing; equipment weight/size is retired. `FFTacticalSound.gd` owns labels/localization helpers. `FFTacticalVisuals.gd` owns survivor/infected/weapon rendering.

Authored environments include back alleys, gas stations, houses, apartments, stores, warehouse yards, and drainage washes. Every map has far-side extraction rather than an exit beside the entry, plus physical loot containers whose contents are only retained after escape. **Very Short and Short are intentionally scarce:** Very Short exposes only **1–2 searchable containers** and Short **2–3**, rising to 3–5 / 4–6 / 5–7 for Medium / Far / Very Far. Authored maps describe plausible search points, but each visit randomly exposes only the route-appropriate subset, so the same Gas Station can present different searchable cars/shelves/ice boxes on different outings. Containers can be genuinely empty, especially near camp and in depleted zones. Every completed search now gives immediate floating map feedback such as **+1 Dirty Water**, **EMPTY**, or **CARRY FULL**, while the existing message log retains detail. Container identity owns a real loot family: food/water containers do not casually yield scrap, while cars/crates/debris favor salvage and cabinets are the medical-capable family. Current zone pressure is carried into tactical generation, so **Rich / Good / Sparse / Picked Over** materially changes physical empty-container odds instead of being a UI-only label. **Named Explore gear is no longer guaranteed near camp:** Camp Perimeter has a 30% special-gear opportunity and Nearby Streets 50%; Medium/Far/Very Far retain a guaranteed named gear opportunity for now. A no-gear Explore becomes a straightforward full scavenging objective. Current authored geometry remains the fixed 20×18 tactical board; actual distance-scaled larger map geometry belongs to the upcoming tactical-environment overhaul rather than fake empty padding. Rescue civilians are protected from infected targeting until first contact, then become vulnerable escorts. On extraction, a contacted living rescue may catch up to a player holding the exit instead of being abandoned solely because the player reached the exit one tactical step first.

Tactical scene lighting uses the actual settlement clock at encounter creation with DAWN / DAY / DUSK / NIGHT phases plus independently powered/unpowered environments. Actual per-cell light shapes the player's vision cone geometry as well as visibility thresholds: darkness contracts and narrows sight, while bright cells and portable/fixed lighting extend and widen it. The active off-hand slot has exactly three tools: **Flashlight, Lock Pick, Firecracker**. Flashlight and Firecracker are found-only; Lock Pick may be found or crafted at the Workbench. Flashlight charge drains while lit and persists; Lock Pick has a random **1–3 successful unlock uses** before breaking; Firecracker is a **single-use** thrown noise lure. Tactical maps may roll locked doors and optional locked containers, with higher lock frequency farther from camp. Off-screen audible events continue to appear as fuzzy **yellow/gold sound callouts** at approximate locations and disappear when the true source becomes directly visible.

## Expedition logistics

`FFExpeditionRules.gd` owns expedition distance bands, fixed route hours, 1–2 survivor party limits, travel-supply costs, the Very Far vehicle gate, zone caps, and expedition logistics.

**Every gate Send Out is tactical.** A normal outing is most often exploration, sometimes a zombie ambush, rarely a stranded survivor, and very rarely a dog/cat rescue. **Very Short / Camp Perimeter exploration is the only expedition tier that can get lucky enough to roll 0–1 infected, with a full range of 0–3.** All longer exploration has a minimum of two infected. Ambushes use exactly **5 infected**, pet rescues exactly **3**, and survivor rescues exactly **5**. All tactical outing families still use physical loot containers, and only loot physically recovered before extraction comes home.

The haul rule is literal: **expedition return never rolls or invents resources, components, or gear**. The only things added to camp inventory are items already recovered from tactical containers, harvested infected corpses, or explicit physical on-map pickups such as the marked Explore gear. Legacy text-field reward paths are no longer entered by production expeditions, including old compatibility travel events and post-tactical special-site reward screens. A rescued stranger can still reveal a location or join the camp, but cannot hand over fallback “bonus loot” that was never carried on the tactical board.

The five route bands map onto the existing zones: **Camp Perimeter = Very Short / 3h**, **Nearby Streets = Short / 5h**, **Residential Blocks = Medium / 8h**, **Commercial Fringe = Far / 12h**, and **Industrial Edge = Very Far / 18h**. Very Short and Short have no travel-supply cost. Medium costs **1 Cooked Food + 1 Clean Water per survivor**; Far costs **2 + 2 per survivor**; Very Far costs **3 + 3 per survivor** and additionally requires the additive **Expedition Vehicle** unlock. Costs scale with party size. Medium and Far are reachable from the start; Very Far is the only route band locked by travel infrastructure.

Expedition parties may contain **one lead plus one companion**. The second survivor is a real tactical actor using the existing companion AI: they follow, fight, can be targeted/injured/killed, persist through tactical reload state, and must reach the extraction area with the lead. The gate exposes lead, optional companion, route, total supply cost, and launch in one phone-safe surface.

Travel supplies are committed at launch, but **route time is not advanced before tactical play**. The tactical map opens immediately at the current camp clock and settlement is hard-paused for the tactical encounter. After the tactical result is acknowledged, the expedition becomes **Away** for its full authored route-duration timer while ordinary camp time resumes. The away survivor(s) remain unavailable until that timer reaches zero; the existing activity/status UI shows the live seconds remaining. Medium/Far/Very Far provisions continue covering the away party while that timer runs.

Physically recovered tactical loot is carried by the expedition during the Away timer and is **not added to communal camp inventory until the party actually returns**. Rescued recruits/pets likewise remain with the return party rather than appearing at camp instantly. If every human returner dies before the timer reaches zero, carried loot/gear and a rescued pet are lost with the expedition; a living rescued recruit counts as a valid returner and can still bring the payload home. Camp pressure events and **new** maintenance incidents require at least one living survivor physically present at First Fire; if everyone is away, nothing new that requires a player choice is generated. Tactical itself still pauses the settlement clock completely.

## Living camp and camp life

The persistent 2D tactical-style living camp is both the final camp presentation **and the primary menu/home screen**. `FFCampView.gd` remains the presentation foundation; active camp rendering and interaction route through `FFCampViewSleepVirus.gd` for authoritative sleep/treatment/quarantine placement plus camp touch targets.

The starter camp is intentionally sparse wilderness rather than a pre-laid settlement: grass/brush/trees around a single First Fire, **shelter capacity for 3**, and communal storage. Visible sleeping gear is resident-driven rather than capacity-driven: the camp renders exactly **one bed/bedroll per living resident**, so a founder-only camp begins with one bed and additional beds appear as people actually join, up to the current 3/7/12/18 shelter cap. **Workbench is progression, not a free starter fixture.** It is deliberately cheap at **2 Wood + 1 Scrap Metal** and has no building prerequisite. Future building locations remain invisible until construction starts; the physical work board is the camp-expansion planner, and active construction is shown at the real destination. These graphics read authoritative `Game` state and do not create separate camp simulation or pathfinding.

The active screen no longer presents the legacy CAMP / CRAFT / BUILD / SURVIVORS tab bar. The camp stays touch-active even while a contextual sheet is open. Current in-world routes are:

- tap a **survivor** → full survivor stats/condition/equipment/inventory inspector;
- tap the **communal chest / Storage Crate** → communal resources, components and gear inventory;
- tap the **First Fire** → default Day-1 Fire Pit crafting; Tavern stages keep using that same physical hearth and progressively expose better cooking, brewing, and social recovery;
- tap a built **Workbench**, **Sewing Table**, or **Infirmary** → recipes for that station only;
- tap a **built structure** → contextual structure information and any active interaction (for example Garden Plot tending);
- tap the **camp work board** → daily duties, maintenance, pet care, and the permanent camp-expansion planner;
- tap the **gate** → survivor/send-out chooser.

The First Fire, communal storage box, and starter shelter capacity for three are the only guaranteed new-game camp fixtures. The camp only renders beds for people who actually live there, so the founder begins with one visible bedroll and later residents add their own bed up to the current shelter limit. Camp growth is a hard-cap progression: **Bedroll Camp (3) → Large Tarp (7) → Barracks (12) → Dormitory (18)**. Recruitment cannot exceed the current shelter tier; a survivor arriving at a full camp is turned away and is **not** retained in a waiting list or nearby-recruit state. The Tavern is its own parallel progression: **First Fire → Tavern → Tavern Kitchen → Tavern Brewery**.
Before the Workbench exists, the only crafting available is **Cook Food, Boil Water, and Bandage at the First Fire**. The first Workbench costs only **2 Wood + 1 Scrap Metal** and has no prerequisite. Tavern Stage 1 adds **Community Stew (2 Raw Food → 5 Cooked Food)** and stronger social downtime. **Tavern Kitchen** requires Tavern + Sewing Table + Garden Plot + Water Tank and adds **Kitchen Supper (3 Raw Food + 1 Clean Water → 8 Cooked Food)** plus another social-recovery step. **Tavern Brewery** requires Tavern Kitchen + Barracks + Water Tank + Garden Plot and adds **Brew Beer (2 Raw Food + 2 Clean Water → 4 Beer)**. Beer is a real camp resource; autonomous Brewery social sessions can consume one Beer for the strongest Tavern mood/stress benefit. Workbench supplies basic tools/weapons/components; **Crossbow, Sledgehammer, Hatchet, Bolt Cutters, and Toolbox require an Armory**; Sewing Table owns clothing/weatherproofing; Infirmary owns Zombie Cure processing. Later infrastructure remains intentionally expensive and dependency-heavy: Infirmary requires Barracks + Workbench + Water Tank, Armory requires Barracks + Workbench + Watch Post, and Dormitory requires Tavern Kitchen as part of its mature support chain.

The top camp HUD is the authoritative clock/resource readout. The map title stays intentionally short (`FIRST FIRE CAMP • DAY N`), the idle `RUNNING` label is hidden, and the secondary status line only appears for meaningful states such as an away survivor, tactical encounter, active work, illness, or pause. Routine expedition returns are promoted from transient toast text into a persistent tap-to-dismiss camp return notice carrying the exact haul/empty-handed result.

Survivors carry floating at-a-glance state in the camp: five need pips remain, while the focused camp adds a compact mood/priority-need/virus badge so hunger, thirst, sleep, fun, safety, stress, and infection are readable without opening a roster panel.

Sleep quality now scales with shelter. Normal sleep is an authored **8 in-game hours**; the same sleep period restores more Fatigue and reduces more Stress at each housing tier, so the **Rested** moodlet is reached faster in a Large Tarp than on exposed bedrolls, faster again in Barracks, and fastest in the Dormitory. Better shelter also improves ordinary idle recovery, making housing a general mood/recovery upgrade rather than population capacity alone.

Sleep is a real availability state rather than a passive visual label. When autonomous sleep triggers, the survivor enters **Sleeping**, receives a timed sleep task, walks to a deterministic bed/sleep slot in the camp view, lies down visually, and is excluded from worker/expedition/equipment assignment until waking. Fatigue is also a work-pressure system: idle time in camp naturally lowers fatigue, while chores/crafting/building/training and expeditions raise it. A survivor who reaches **100 fatigue** enters **Exhausted**, walks to a bed, visibly pouts/rests there for a random **3–5 in-game hours**, and gets back up at **0 fatigue**. Existing productive work, treatment, chores, pet care, crafting, building, garden work, expeditions, quarantine, and severe sickness likewise keep survivors unavailable through authoritative statuses/tasks.

`FFCampLifeRules.gd` owns five survivor needs—Hunger, Thirst, Sleep, Fun, and Safety—plus pet affection/retention/reward rules, fire/maintenance tuning, idle recovery/downtime, exhaustion recovery, and camp cadence. Pets do not consume camp food or water: Bond/Affection falls without attention, PLAY/LOVE restore it, neglected pets can leave camp, and each pet that stays brings back exactly one random material or Raw Food per in-game day. Productive work is player-directed: camp chores/maintenance, crafting/building, treatment, pet care, training, and expeditions require assignment. Eating, drinking, normal sleep, fire-watching, socializing, fun, wandering, and other ordinary camp life remain autonomous. Autonomous needs are real simulation actions rather than end-of-day abstractions: available survivors seek a midday water break, an evening meal, and a real overnight Sleeping task; those actions consume one Clean Water / Cooked Food when available and visibly restore Thirst / Hunger. There is no second hidden midnight ration consumption in the active runtime. **Sleep need and Fatigue are separate axes:** ordinary awake time lowers the Sleep need and drives the nightly sleep routine, while productive work adds Fatigue. Camp maintenance chores have an explicit duration-scaled fatigue hit and every craft costs at least 3 Fatigue, increasing with recipe work time. Expedition return is deliberately much heavier and scales directly with the authored route distance: roughly **22 / 30 / 42 / 58 / 82 Fatigue** for Very Short / Short / Medium / Far / Very Far. Idle/Available survivors who are simply chilling in camp recover **Fatigue slowly**. **Stress remains a separate pressure axis**, but need moodlets now create a small signed comfort/discomfort drift **only while the survivor is genuinely idle**. Each positive moodlet—**Well Fed, Hydrated, Rested, Entertained, Safe**—counts as **+1**; each active negative need moodlet counts as **-1**. The net score scales a tiny constant Stress drift: more +1s make idle Stress fall faster, more -1s make it rise faster, and mixed moodlets offset one another. Warm/friendly autonomous camp chatter may also remove a very small amount of Stress. Stress still rises from explicit bad experiences such as tactical infected presence/damage, missed meals or sleep, illness, and authored camp events. At the starter camp, elevated Stress drives the visible **Watching Fire** idle (the camp's TV-watching equivalent), which removes a larger fixed amount of Stress each completed session. Tavern social/drinking is the stronger later-camp decompression route, and its relief scales upward when multiple survivors are doing it together. Reaching **100 Stress** triggers a timed **Tantrum** breakdown that interrupts ordinary camp work, vents some Stress, and then resumes interrupted work when possible. Normal sleep reduces Fatigue, and hitting 100 Fatigue schedules the separate forced 3–5-hour Exhausted bed rest described above. Assigned work occupies settlement time and can crowd out water, meal, or sleep windows when the player overworks them.

Camp chores are now **irregular timed maintenance problems**, not a daily quota. At most one of **Poke Fire, Chop Wood, Clear Area, Stack Supplies** is active at once. After a problem is resolved or missed, the next one is scheduled roughly **240–540 settlement seconds later** (about 0.8–1.8 game days), and a new problem gives roughly **90–150 settlement seconds** (about 7.2–12 game hours) to respond. The work board shows the live deadline and the exact miss consequence. Poke Fire and Chop Wood failures immediately reduce the First Fire; Clear Area and Stack Supplies failures immediately reduce camp condition. Completing the interaction retains the existing positive chore effects. The minigame still runs over the live camp without pausing settlement, and the assigned NPC visibly performs the work. Existing unresolved maintenance can still expire if its deadline runs out while survivors are away, but **a new maintenance incident is only spawned when at least one living survivor is physically home at camp**. Duty-rotation history remains bounded for social/political use, but nobody is forced to take a chore every day.

Camp condition is persistent settlement state using the existing authoritative `camp_maintenance` score. It degrades naturally through `FFCampLifeRules`, existing cleaning/perimeter work restores it through the same owner, and its derived bands are **Well Kept +1**, **Acceptable 0**, **Neglected -1**, **Poor -2**, and **Severe -3**. The mood effect composes into survivor stress pressure rather than replacing needs. Timed maintenance failures can now cause immediate authored condition/fire losses on top of that background wear, making neglect visible and time-sensitive instead of an end-of-day checkbox penalty.

Camp events provide a second pressure layer through the existing narrative event queue. They are RP choices with **pre-rolled hidden luck** where appropriate, not tactical combat checks. Random zombie breaches can destroy a built leaf structure, ruin stored supplies, Hurt/Wound/kill a present survivor, or directly expose a bitten survivor to the zombie virus. The breach result uses a stored d100 plus camp infrastructure: **Noise Line and Watch Post improve the roll, survivor stats and player combat skill do not**. Other events include questionable/spoiling food or drink, storms that can tear down buildings unless the player spends Hardware to brace them, a one-survivor isolation night, and larger-camp morale/crowding nights with quiet/Tavern/food choices. Events directly change existing Stress/Fun/Safety/condition/resources/buildings instead of creating a separate “event morale” stat. Destroyed buildings revert to unbuilt and must be rebuilt; only built leaf structures are eligible so destruction cannot leave an impossible prerequisite chain.

Each living survivor also carries compact current-day activity accounting plus one bounded previous-day summary. The active runtime records assigned work, expeditions, care, autonomous life, and access to authored meal/sleep windows. Work that occupies at least 60% of the daily meal or sleep opportunity records a missed meal/sleep at rollover and applies consequences through the existing Hunger/Fatigue/Stress axes. Free survivors retain autonomous opportunities; tactical pause prevents these counters and camp degradation from advancing.

Camp events remain an important interaction layer, including later settlement politics. In addition to authored social/political choices, occasional physical camp emergencies can interrupt normal camp life with brief touch-first minigames (for example rapidly containing a spreading camp fire). These events should be uncommon enough to feel consequential rather than constant popup maintenance.

Unassigned survivors remain worth watching: their needs can drive sleep, checking food/water, watching the treeline, wandering, watching the fire, fun, and autonomous social chatter.

Physical trauma and zombie virus are separate health axes.

Physical wound treatment:
- **Hurt:** 1 Bandage; minor recovery capped to 30s.
- **Wounded:** 1 Bandage; timed wound care.
- **Critical:** 1 First Aid Kit; timed emergency stabilization to Wounded, after which normal wound care applies.

Medical supply economy is explicit: **Bandages are crafted** at the First Fire from Cloth + Clean Water for ordinary physical wounds; **First Aid Kits are rare found-only supplies** used for Critical trauma and one-time emergency amputation; **Zombie Cure is the rarest direct medical find and can also be crafted at a built Infirmary from 2 recovered Zombie Corpses**. Zombie corpses are physically recovered from killed infected in tactical play and each recovered corpse uses one expedition carry slot.

Zombie virus:
- **Only a successful Bite can create field exposure. Scratches never roll infection.** Generic physical damage does not create exposure either.
- Every successful Bite gets the same independent **3% exposure roll**. The percentage does not rise, stack, or accumulate because of earlier scratches/bites; multiple bites simply produce multiple separate 3% checks.
- There is **no survivor-to-survivor camp transmission** and no natural-clear roll.
- A new unquarantined exposure gets a hidden **1–2 day turn deadline**. Display stages still progress through Exposed / Infected / Feverish as that deadline approaches; reaching the deadline is terminal.
- **Emergency amputation:** available only in the immediate Exposed window, before quarantine or the first daily virus progression, and only once in that survivor's lifetime. It consumes **1 First Aid Kit**, immediately clears the virus, reduces **Combat by 1 and Agility by 1** (minimum 0), and forces **8 in-game hours / 100 settlement seconds** of recovery.
- **Quarantine:** available for an active case when the survivor is free. Choosing it closes the amputation window, incapacitates the survivor in bed/forced rest, adds the existing quarantine Stress hit, and replaces the virus clock with a fresh **3–4 day** deadline from quarantine. Quarantine buys time; it does not cure.
- **Zombie Cure:** if the camp has one, it can be used immediately at any active stage, including during quarantine or fever, and clears the virus at once. Administration does **not** require an Infirmary; the Infirmary remains the place that can craft a Cure from 2 Zombie Corpses.
- There is no Clean Water/Bandage decontamination and no staged Infirmary emergency-treatment path. The active decision is **amputate now or preserve the limb and buy time while hunting a Zombie Cure**.

Amputation recovery and quarantine are visible forced-rest states in the living camp. Virus state remains separate from the physical wound condition ladder.

Treatment time does not depend on a removed Medical stat. Craft/build duration does not depend on a removed Technical stat.

`FFCampSocial.gd` owns relationships, chatter, candidate standing, and politics. **Leadership** is the active progression stat for social/political capability. Sleeping, quarantined, sick, and otherwise busy survivors are not selected for normal available-survivor chatter.

## Time / economy

Settlement time has one direct authoritative clock with **no secondary speed multiplier**. `DAY_SECONDS := 300.0` means **12.5 real active seconds = 1 in-game hour** and **300 real active seconds / 5 minutes per in-game day**. Camp need decay, idle fatigue recovery, authored work-fatigue gains, sleep/exhaustion duration, fire decay, camp-condition decay, chatter/event cadence, and daily-life action durations are tuned against that clock. Standard expedition travel uses authored in-game hours directly: 3h = 37.5 settlement seconds, 5h = 62.5s, 8h = 100s, 12h = 150s, and 18h = 225s. Tactical turns are a separate frozen time scale. UI refresh and autosave remain real-time responsiveness concerns.

New games begin with three Cooked Food and three Clean Water so the founder has roughly three daily rations before shortages. The founder carries **exactly one starter loot/gear item: the Utility Knife**. A built Workbench can craft basic gear including the Lock Pick; advanced Workbench recipes such as Crossbow/Hatchet/Sledgehammer are Armory-gated. A built Infirmary can craft Zombie Cure from 2 Zombie Corpses; all firearms plus Flashlight/Firecracker remain found-only. Survivors can carry **4 loot items without a pack**; found-only backpacks raise that individual capacity to **6 or 8**, and a two-survivor expedition pools both capacities on the tactical map. Capacity is pure item count: each recovered resource/component unit, including a Zombie Corpse, uses one slot; weight and item size do not change the 4/6/8 cap. Hatchet remains deliberately expensive and does not enter field loot until Commercial Fringe; Sledgehammer joins the same later melee tier. The former shared Ammo resource is retired; tactical reload/chamber state is the only ranged ammunition constraint.

Fire Pit / Tavern conversions:
- **1 Raw Food → 2 Cooked Food** at the starter fire
- **1 Dirty Water → 2 Clean Water** at the starter fire
- **2 Raw Food → 5 Cooked Food** with Tavern / Community Stew
- **3 Raw Food + 1 Clean Water → 8 Cooked Food** with Tavern Kitchen / Kitchen Supper
- **2 Raw Food + 2 Clean Water → 4 Beer** with Tavern Brewery / Brew Beer

Routine scavenging stays constrained by zone caps/depletion, pack capacity, and authored loot distribution rather than a Scavenging stat.

## Saves

Current save schema is **8**.

Schema 8 is the deliberate camp-progression reset: the starter Workbench was removed, old additive housing/building identities were replaced by the tiered Large Tarp/Barracks/Dormitory and Tavern progression, and schema-7 saves are invalidated cleanly rather than ambiguously translating old Cabin/Bunkhouse/Communal Table state. Current survivor-model marker remains **`combat-agility-leadership-v1`** and zombie-virus state remains **`zombie-virus-v1`**.

The filename remains `user://first_fire_alpha01.json` intentionally.

`FFSaveCodec.gd` owns JSON/file transport. `GameThreeStat.gd` retains the three-stat compatibility layer; active runtime orchestration is `GameSleepVirus.gd`, which extends it with the direct five-minute camp day, **live post-tactical Away timers**, authoritative sleep/work availability, survivor training, zombie-virus deadlines/amputation/quarantine/cure use, and tactical exposure integration.

## Canonical technical reality

Canonical Godot source lives directly under `game/`; CI builds that directory directly. Current Web CI uses **Godot 4.7.1** and runs canonical validation, import/parse, architecture smoke, startup smoke, Web export, error-log rejection, Pages artifact upload, and Pages deployment.

The active project seams are:
- `project.godot` autoload → `GameSleepVirus.gd` → `GameThreeStat.gd` → `Game.gd`
- `main.tscn` → `MainSleepVirus.gd` → `MainThreeStat.gd` → `Main.gd`
- active tactical runtime → `FFCombatVirus.gd` → `FFCombatThreeStat.gd` → `FFCombat.gd`
- active survivor inspector → `FFInspectorVirus.gd` → `FFInspectorThreeStat.gd`
- active living camp/menu renderer → `FFCampViewSleepVirus.gd` → `FFCampView.gd`
- zombie-virus pure rules → `FFVirusRules.gd`

`MainSleepVirus.gd` owns the current camp-only routing/layout. The legacy four-tab nav created by `Main.gd` is hidden by the active wrapper. `FFCampViewSleepVirus.gd` emits camp-object intent; `MainSleepVirus.gd` opens contextual station/build/work/gate sheets or existing inspector/inventory/expedition overlays. The renderer remains non-authoritative and `Game` remains the sole owner of simulation/resource mutation.

These wrappers keep the blast radius small while preserving the mature three-stat/camp/tactical foundations. Legacy six-skill strings may remain inside inherited base/legacy event code for compatibility while active runtime exposes only the three current stats. New gameplay must target the active wrapper seam or the correct underlying owner rather than revive the legacy model.

## Frozen scope

Pets, active camp work, authoritative sleep, zombie-virus consequences/treatment, **1–2 survivor tactical expeditions**, and the living camp as the primary menu surface are part of the approved final-system depth. A single Expedition Vehicle unlock exists only to gate Very Far travel; full vehicle driving/fuel simulation, parties larger than two, and 3D camp remain cut. Final population ceiling is **18**. Mature settlement remains **15+ living survivors + every building + an elected leader**, after which play continues indefinitely.

## Source-of-truth order

1. Newest explicit user instruction
2. Current `main`
3. `README_SOPS.md`
4. `README_CONTEXT.md`
5. `ARCHITECTURE.md`
6. `ROADMAP.md`
7. `CHANGELOG.md`
8. Conversation memory only as supporting context

## Required code-change response footer

At the end of every prompt in which code/repository behavior was changed, include:

- Changelog: `https://github.com/dmcexcess-lab/first-fire/blob/main/CHANGELOG.md`
- Play: `https://dmcexcess-lab.github.io/first-fire/`