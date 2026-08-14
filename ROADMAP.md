# First Fire — Beta Candidate Roadmap

First Fire is now in **feature freeze** and shelved for Beta testing/release work. The game loop and its final feature set are decided. Work from here to 1.0 is completion, balance, verification, packaging, and bug fixing—not new pillars.

## Final game loop

**Camp → prepare one survivor → expedition → tactical field situation → escape → persistent consequences → living camp/politics → recover/build/craft → repeat.**

The game has **no scripted ending**. A settlement with every building completed and roughly **15–18 living survivors** is the mature/top-level state; play can continue indefinitely after that.

The hard population ceiling is **18 survivors**.

## Permanently cut scope

These are no longer planned for First Fire:

- 3D camp rendering—the living 2D tactical-style camp is the final camp presentation;
- pets or pet-care systems;
- vehicles or vehicle logistics;
- multi-survivor expeditions;
- tactical companion AI;
- additional foundational game modes or feature pillars.

Removing these is intentional scope control, not deferred work.

## Beta completion work

### Camp life, politics and events

Finish tuning the systems that already exist:

- autonomous relationship/politics-based chatter in the living camp;
- relationship drift from meaningful positive/negative interactions;
- shortages and repeated expedition duty feeding camp opinion;
- coordinator → formal election progression;
- recurring confidence challenges when an elected leader loses support;
- camp events for shelter pressure, duty complaints, food, theft, fights, burnout, perimeter danger, personal requests, shared meals and shortage politics;
- enough event weighting/cooldowns that camp life feels alive without becoming popup spam.

### Tactical field completion

Outside-world events remain physical/tactical. Finish converting or retiring any remaining legacy field-text path so camp narrative is the only routine text-event space.

Keep deepening the existing tactical language rather than adding another combat system:

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

Future work here is balance/art/readability, not introducing a second inventory system.

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

Housing grows additively to the final 18-person ceiling. Utility buildings deepen existing food/water/recovery/security/social/crafting rules rather than creating new minigames.

### Mature settlement state

A settlement becomes **mature** when it has:

- at least 15 living survivors;
- every planned building completed;
- an elected leader.

This produces a milestone event only. It does **not** end the save.

## Beta → Release 1.0 gate

First Fire does **not** become 1.0 because a calendar date or feature count says so. Release happens only when all of these gates are satisfied:

1. **No known release-blocking bugs.** Normal play, save/load, browser lifecycle, tactical encounters, camp simulation, crafting/building, and long-run play must survive Beta testing without known blockers.
2. **All systems and timers are balanced.** Economy, resource use, construction, crafting, recovery, expedition cadence, camp events, politics, recruitment, and progression must feel coherent across early, middle, and mature settlement play.
3. **Final game speed is decided.** The current two-real-minute game day is test tuning, not automatically the shipping answer. Beta determines the final simulation speed and timer scale.
4. **Combat and tactical systems are balanced and reliable.** Action timing, movement, vision, lighting, sound, stealth, melee, firearms, infected behavior, hazards, objectives, loot, exits, and encounter frequency must all work consistently and produce the intended survival/extraction feel.
5. **Ads work under the existing non-exploitative policy.** Advertising/ad-free purchase behavior must function without influencing gameplay systems or progression.
6. **Android APK release build is complete and tested.** The Android package is the release target for 1.0; packaging/device testing is part of the release gate, not an afterthought.

When all six gates pass, that build becomes **First Fire 1.0**. Until then the project remains a Beta candidate / Beta test project with no new feature work.

## Shelved development state

As of this scope lock, First Fire is intentionally shelved while work moves to the next project. Returning to First Fire means **Beta verification against the release gate above**, not reopening the feature roadmap.

Schema 7 is intended as the final deliberate Alpha reset. Once Beta testing begins, save compatibility becomes a player-facing promise and schema changes should be treated much more conservatively.
