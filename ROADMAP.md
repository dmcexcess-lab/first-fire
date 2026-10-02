# First Fire — Beta Candidate Roadmap

First Fire is now in **feature freeze** and shelved for Beta testing/release work. The game loop and its final feature set are decided. Work from here to 1.0 is completion, balance, verification, packaging, and bug fixing—not new pillars.

## Final game loop

**Watch the living camp → notice needs/shortages → inspect or assign survivors in-world → prepare a one- or two-survivor expedition → choose a distance and commit any party-scaled supplies → tactical field situation immediately → escape with physically recovered resources/rescues → advance the authored route hours on return → come back to a visibly changing camp → repeat.**

The living camp is the primary home/menu surface. The old CAMP / CRAFT / BUILD / SURVIVORS tab bar is retired from active play rather than preserved as parallel navigation. On phones the camp is zoomed and pannable so structures and people remain readable instead of shrinking the full 18×11 settlement into one strip. Normal management starts by touching the camp itself: survivors open inspection and deliberate assignments, the communal stash opens inventory/resources, the First Fire and starter Workbench provide physical crafting, built structures expose contextual interactions, and the camp edge/gate owns expedition dispatch. The starter scene is mostly wilderness; future construction locations are not shown as empty placeholders. Contextual sheets may reuse mature underlying UI logic, but they are entered from physical camp objects and return to the camp.

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
- an active camp work loop covering camp chores/maintenance, crafting/building, treatment or forced rest, pet care, training and expeditions; eating, drinking, normal sleep, fire-watching, socializing and fun remain autonomous, while assigned work can make survivors miss normal meal/sleep windows if the player overworks them;
- daily camp duty is capped at exactly 1–2 required chores per settlement day, randomly persisted from **Poke Fire, Chop Wood, Clear Area, Stack Supplies**; each uses the shared touch-first chore interaction, assignments occupy real camp time, missed chores worsen condition modestly, and a bounded eligibility-aware duty-rotation signal records whether turns are being shared without requiring every survivor to work daily;
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

Current encounter-population contract is intentionally sparse at the nearest tier: **Very Short exploration rolls 0–3 infected and is the only place that can roll 0 or 1**. Ambushes use 5 infected, pet rescues 3, survivor rescues 5, and every longer exploration has at least 2. Individual infected remain weak; danger scales through mob pressure and higher density instead of sponge HP/damage. Searchable-container targets now start at **3–5 on Very Short** and rise by distance. Virus transmission is intentionally uncommon (3% after one direct infected hit, capped at 12% per encounter from repeated direct hits).

Continue completion work around:
- recognizable locations;
- day/night/power/lighting;
- vision, sound, stealth and action timing;
- doors, windows, hazards and exits;
- rescue/search/ambush objectives;
- equipment interactions and readable consequences;
- mobile readability and performance.

### Items and crafting

Every current `FFData.GEAR` item must be represented in the finished equipment loop. All existing gear is craftable through the Fire Pit/Workbench/Sewing Table tree as appropriate; firearms are late-camp Workbench recipes gated by the Armory.

The tactical HUD exposes all five equipment slots: Weapon, Secondary, Tool, Clothing and Pack. Explore objectives also place a real named gear pickup on the board; it is only retained after physical recovery and successful escape. Every current gear catalog entry belongs to a zone-tiered field-loot pool.

Crafting is contextual camp interaction, not a standalone navigation mode. **First Fire / Fire Pit is always present from Day 1** and supplies the default Cook Food, Boil Water, and Sterile Dressing recipes. Built Workbench and Sewing Table objects expose their own recipe sets when tapped.

### Final building tree

The final build list is:

1. Rain Catcher
2. Makeshift Shelter
3. Storage Crate
4. Workbench
5. Sewing Table
6. Garden Plot
7. Noise Line
8. Cabin
9. Water Tank
10. Communal Table
11. Infirmary
12. Watch Post
13. Bunkhouse
14. Armory
15. Dormitory

Housing grows additively to the final 18-person ceiling. Utility buildings deepen existing food/water/recovery/security/social/crafting rules rather than creating new minigames. Future construction anchors remain data/code only for now; the wilderness camp does not show empty build placeholders. Built structures remain tappable for contextual information and active interactions.

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

Schema 7 is intended as the final deliberate Alpha reset. Once Beta testing begins, save compatibility becomes a player-facing promise and schema changes should be treated much more conservatively.