# First Fire — Beta Candidate Roadmap

First Fire is now in **feature freeze** and shelved for Beta testing/release work. The game loop and its final feature set are decided. Work from here to 1.0 is completion, balance, verification, packaging, and bug fixing—not new pillars.

## Final game loop

**Watch the living camp → notice needs/shortages → inspect or assign survivors in-world → prepare a one- or two-survivor expedition → choose a distance and commit any party-scaled supplies → tactical field situation immediately → escape with physically recovered resources/rescues → advance the authored route hours on return → come back to a visibly changing camp → repeat.**

The living camp is the primary home/menu surface. The old CAMP / CRAFT / BUILD / SURVIVORS tab bar is retired from active play rather than preserved as parallel navigation. On phones the camp is zoomed and pannable so structures and people remain readable instead of shrinking the full 18×11 settlement into one strip. Normal management starts by touching the camp itself: survivors open inspection and deliberate assignments, the communal stash opens inventory/resources, the First Fire provides survival crafting, the work board owns camp expansion, built crafting stations expose their recipe sets, and the camp edge/gate owns expedition dispatch. The starter scene is mostly wilderness; future construction locations are not shown as empty placeholders until work begins. Contextual sheets may reuse mature underlying UI logic, but they are entered from physical camp objects and return to the camp.

The game has **no scripted ending**. A settlement with every building completed and roughly **15–18 living survivors** is the mature/top-level state; play can continue indefinitely after that.

The hard population ceiling is **18 survivors**.

## Permanently cut scope

These are no longer planned for First Fire:

- 3D camp rendering—the living 2D tactical-style camp is the final camp presentation and home/menu surface;
- full vehicle driving/fuel/maintenance logistics beyond the single Expedition Vehicle unlock used to gate Very Far travel;
- expedition parties larger than two survivors;
- additional foundational game modes or feature pillars.

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
- daily camp duty is capped at exactly 1–2 required chores per settlement day, randomly persisted from **Poke Fire, Chop Wood, Clear Area, Stack Supplies**; each uses the shared touch-first chore interaction **without pausing settlement**, the assigned NPC visibly performs the chore in the living camp while the minigame is played, assignments occupy real camp time, missed chores worsen condition modestly, and a bounded eligibility-aware duty-rotation signal records whether turns are being shared without requiring every survivor to work daily;
- persistent camp condition/cleanliness/maintenance that degrades when neglected, visibly affects the living camp, grants a mood bonus when well kept, is neutral when merely acceptable, and applies escalating negative mood pressure at neglected bands (target 0/-1/-2/-3);
- each survivor should have at least one meaningful daily activity, whether a player-assigned productive action or autonomous life behavior, without turning meals/sleep/fun into manual scheduling;
- occasional touch-first camp emergency minigames (for example containing a spreading camp fire) layered alongside authored camp social/political events, with low enough frequency to avoid popup spam;
- rescued dogs/cats as persistent Tamagotchi-style camp pets whose affection is maintained through PLAY/LOVE assignments; pets consume no camp food/water, can leave if neglected, and each retained pet contributes exactly one random material or Raw Food per day;
- relationship drift from meaningful positive/negative interactions;
- shortages and repeated expedition duty feeding camp opinion;
- coordinator → formal election progression;
- recurring confidence challenges when an elected leader loses support;
- camp events for shelter pressure, duty complaints, food, theft, fights, burnout, perimeter danger, personal requests, shared meals and shortage politics;
- enough event weighting/cooldowns that camp life feels alive without becoming popup spam.

The core presentation goal is **watch, prioritize, assign, prepare, grow**. The player should feel like they are nurturing a small settlement, not operating a spreadsheet with a decorative camp preview.

### Tactical field completion

Outside-world events remain physical/tactical. Standard Send Out is now always a tactical map, including previously discovered special sites; there is no routine passive expedition-result branch. Finish retiring any remaining legacy field-text path so camp narrative is the only routine text-event space.

Keep deepening the existing tactical language rather than adding another combat system.

**Next tactical overhaul slice:** treat combat/stealth, infected AI, sound, tactical environment scale, and presentation as one cohesive pass. Rework melee/firearm/stealth readability and decision quality; deepen infected perception, investigation, pursuit and mob behavior without making lone infected tanky; upgrade sound propagation and player-facing sound feedback; expand actual tactical geometry by expedition distance so farther routes are physically larger rather than merely denser; then raise visual atmosphere/readability with stronger lighting/effects and evaluate restrained bloom/glow where Godot Web/mobile performance supports it. Preserve portrait touch usability and extraction-first play throughout.

Current encounter-population contract is intentionally sparse at the nearest tier: **Very Short exploration rolls 0–3 infected and is the only place that can roll 0 or 1**. Ambushes use 5 infected, pet rescues 3, survivor rescues 5, and every longer exploration has at least 2. Individual infected remain weak; danger scales through mob pressure and higher density instead of sponge HP/damage. Durability is held to roughly **7–10 HP** so the melee ladder stays readable: **fists 3–5 hits → Utility Knife 2–3 → ordinary 1H melee 2 → ordinary 2H melee 1–2 → Sledgehammer 1 → rare/expensive Hatchet 1**. Ranged progression is now magazine/reload based with **no camp Ammo resource**: Crossbow 1-shot reload / 2–3-hit medium range; 6-shot Revolver and 12-shot Automatic with short optimal range but fire-to-vision falloff; **one-handed** 2-shot Double-Barrel Shotgun with 3 tight physical-range projectiles; 6-shot Pump Shotgun with explicit pump action and 5 wider physical-range projectiles; 20-round Medium Rifle; 5-round Long Rifle. Infected attacks split into frequent/high-hit/low-damage **Scratch** and rare/low-hit/high-damage **Bite**. **Only successful Bite can transmit the virus**, with an independent fixed **3% chance per bite** and no stacked/scaling infection percentage. Searchable-container targets start at **3–5 on Very Short** and rise by distance. Tactical locks also scale upward with distance; the **found-or-crafted Lock Pick has 1–3 uses**.

Continue completion work around:
- recognizable locations;
- day/night/power/lighting;
- vision, sound, stealth and action timing;
- doors, windows, hazards and exits;
- rescue/search/ambush objectives;
- equipment interactions and readable consequences;
- mobile readability and performance.

### Items and crafting

Every active `FFData.GEAR` item must be represented in the finished equipment loop. Crafting covers survival gear, the **Crossbow**, and the **Lock Pick**; **all firearms are field-found only**. Flashlight and Firecracker are also field-found only; Lock Pick may be found or crafted and lasts **1–3 unlocks**. Backpacks are **field-found only** and define the carry ladder: **4 loot-item slots with no pack, 6 with common packs, 8 with better packs**; a two-survivor tactical party pools both survivors' capacity. Carry is count-only: one recovered resource/component unit equals one slot, with no weight or item-size calculation. The former Ammo resource is retired; ranged pressure comes from magazine/chamber size, reload time, Pump Shotgun cycling, accuracy falloff, and physical projectile range where authored. Hatchet remains deliberately expensive/late because it is the one-hit 1H melee tier.

The tactical HUD exposes all five equipment slots: Weapon, Secondary, Tool, Clothing and Pack. Explore objectives also place a real named gear pickup on the board; it is only retained after physical recovery and successful escape. Every current gear catalog entry belongs to a zone-tiered field-loot pool.

Crafting is contextual camp interaction, not a standalone navigation mode. **First Fire / Fire Pit is always present from Day 1** and, before a Workbench exists, the only available crafting is Cook Food, Boil Water, and Bandage. The first Workbench is intentionally light at **2 Wood + 1 Scrap Metal** with no building prerequisite; basic tools/weapons/components live there, while **Crossbow, Sledgehammer, Hatchet, Bolt Cutters, and Toolbox require a built Armory**. Tavern upgrades that same hearth and unlocks Community Stew. First Aid Kits are rare found-only medical supplies. Zombie Cure is the rarest direct medical find and can also be crafted at a built Infirmary from **2 Zombie Corpses** physically harvested from killed infected; each corpse costs one expedition carry slot. Built Workbench, Sewing Table, and Infirmary objects expose their own recipe sets when tapped.

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
9. Barracks
10. Infirmary
11. Watch Post
12. Armory
13. Dormitory

The camp grows through readable upgrade lanes instead of additive housing clutter. **Shelter:** Bedroll Camp (3) → Large Tarp (7) → Barracks (12) → Dormitory (18), with an exact hard recruitment cap at every tier. Each shelter upgrade also improves 8-hour sleep recovery, Rested-moodlet gain, Stress recovery, and ordinary idle recovery. **Hearth:** First Fire → Tavern; its presentation evolves from fire + spit + rough benches into tables, cleaner prep surfaces, and a mature counter as related camp infrastructure comes online. **Utility:** cheap first Workbench → Sewing/Water/Garden/Infirmary/Armory dependencies. **Security:** Noise Line → Watch Post, with Watch Post feeding the late Armory gate. Storage remains a baseline camp fixture rather than a build project. Late buildings are deliberately expensive and dependent on earlier infrastructure rather than isolated resource sinks. The physical work board is the construction planner; unbuilt anchors stay hidden, active construction appears at its destination, and completed structures remain tappable.

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