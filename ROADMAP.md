# First Fire — Beta Candidate Roadmap

First Fire is now in **feature freeze**. The game loop and its final feature set are decided. Work from here to Beta/1.0 is completion, conversion, balance, content depth, readability, performance, and bug fixing—not new pillars.

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

The tactical HUD must expose all five equipment slots: Weapon, Secondary, Tool, Clothing and Pack.

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

## Beta → 1.0

Once the above completion work is stable, focus only on:

- long-run economy and progression balance;
- tactical repetition and encounter conversion;
- camp politics/event tuning;
- item/building costs and usefulness;
- onboarding/tutorial clarity;
- final 2D art/UI/audio feedback;
- mobile/browser performance;
- accessibility/readability;
- save stability;
- bug fixing;
- release packaging;
- non-exploitative monetization only after gameplay is stable.

Schema 7 is intended as the final deliberate Alpha reset. Once Beta testing begins, save compatibility becomes a player-facing promise and schema changes should be treated much more conservatively.
