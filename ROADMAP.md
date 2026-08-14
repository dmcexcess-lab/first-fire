# First Fire — Development Roadmap

First Fire is now **feature-complete at the pillar level**. The core game already exists: camp management, persistent survivors, survival economy, crafting/building, expeditions, relationships, and tactical field encounters.

The remaining roadmap is primarily about **making the existing game deeper, more physical, more readable, and more alive** rather than adding another major game mode.

Version numbers below are directional Alpha milestones, not promises that every item must ship in exactly that release.

---

## Roadmap rule: deepen, do not sprawl

Future features should strengthen an existing First Fire pillar:

- camp life;
- survivor simulation;
- expedition logistics;
- tactical field play;
- persistent world consequences;
- presentation of the settlement.

A proposed feature that requires building an unrelated game inside First Fire should usually be rejected or reduced to a systemic/menu/tactical version that serves the existing loop.

---

## Alpha 0.3 — The Outside World Becomes Tactical

This is the last major structural conversion.

### Remove text-based field encounters

Random text encounters in the outside world will be retired.

**All real-world expedition events become tactical encounters.** If something physically happens outside camp, the player should encounter it on the tactical board rather than resolve it through a detached text popup.

Examples include:

- finding an injured stranger;
- hearing a gunshot;
- discovering a barricade;
- entering a clinic, garage, store, house, trailer, or police vehicle;
- meeting survivors or hostile humans;
- finding an animal;
- investigating a cache or backpack;
- rescue situations;
- ambushes;
- environmental hazards;
- unusual discoveries.

The existing narrative encounter logic should be **translated into physical tactical situations**, not simply deleted. Requirements, alternate outcomes, skill checks, equipment use, recruitment opportunities, trade, information, and persistent consequences still matter; they should be expressed through tactical interaction and contextual choices on the map.

### Text events remain at camp

Text/dialogue event presentation remains appropriate for **camp stories, survivor conversations, relationship events, arguments, politics, leadership issues, morale events, and other primarily social/internal events**.

This creates a clean language for the game:

- **outside world = tactical/physical**
- **camp social life = narrative/dialogue**

### Field encounters pause the settlement simulation

Entering any tactical expedition encounter **pauses normal camp simulation** until the field situation is resolved or escaped.

The player should never lose food, complete construction, advance survivor recovery, or have unrelated camp events fire because they spent time thinking through a tactical turn.

Tactical time and settlement time are separate scales.

### Tactical event quality pass

Improve the current combat/encounter layer rather than replacing it:

- better map generation and authored layout chunks;
- clearer objectives and exits;
- stronger visual distinction between doors, windows, cover, hazards, loot, interactables, survivors, and exits;
- improved facing, vision, sound, stealth, and threat feedback;
- better zombie and survivor presentation;
- more environmental interactions;
- more meaningful alternate routes;
- tactical choices that reflect survivor skills and carried equipment;
- more non-combat resolutions where the physical situation supports them;
- better post-encounter consequence summaries.

The objective remains **survive, accomplish the job, and get out**, not automatically clear the map.

---

## Alpha 0.4 — Tactical Variety and Content Depth

Once every outside event speaks the same tactical language, expand **what can happen inside that language**.

### More of what already works

Add more:

- tactical map layouts;
- location archetypes;
- objective combinations;
- loot situations;
- environmental hazards;
- survivor encounters;
- human threats;
- zombie arrangements;
- doors, glass, obstacles, traps, noise sources, and explosive hazards;
- equipment interactions;
- rare discoveries;
- persistent follow-up situations.

Prefer reusable systems and data-driven variation over one-off scripted maps.

### Encounters should generate stories

Random tactical events should combine circumstances rather than merely select a canned room.

Examples:

- a rescue target is trapped behind a noisy route;
- the safest exit is blocked;
- loot is visible but retrieving it creates sound;
- an injured stranger is surrounded but not yet noticed;
- a hostile survivor controls the useful doorway;
- the party can leave immediately or risk a side objective;
- the map contains a quiet long route and a dangerous short route.

The goal is to make a modest content pool produce many memorable runs.

### Graphics and feedback

Continue upgrading tactical presentation while preserving phone readability:

- survivor/zombie sprites;
- environment tiles/art;
- attack and impact feedback;
- animation where it improves comprehension;
- lighting/fog presentation;
- intent/threat indicators;
- sound visualization;
- damage/wound clarity;
- objective markers that do not overwhelm the map.

### Living camp presentation foundation — started in Alpha 0.3E

The menu now has a persistent 2D camp rendered in the same tactical visual language. It is a **view of simulation state**, not a new control mode: survivors visually walk to crafting/building/garden/recovery stations according to their existing status/task, structures appear as they are built, and survivors outside camp disappear from the scene.

This should grow alongside the simulation: social interactions, pets, vehicles, repairs, eating, resting, and future camp activity can become visible here when those systems have real state worth showing. The renderer can be enlarged or eventually replaced by 3D without changing who owns the simulation.

---

## Alpha 0.5 — Autonomous Camp Life

The settlement should increasingly feel inhabited without asking the player to micromanage everyone socially.

### Automatic survivor interactions

Survivor-to-survivor behavior should happen **autonomously** based on simulation state.

Important inputs include:

- personality;
- relationships;
- stress;
- physical health;
- fatigue;
- injuries;
- recent losses or successes;
- camp resource security;
- crowding/comfort;
- general camp mood or "vibe";
- shared expedition history;
- leadership/political alignment where relevant.

Survivors may naturally:

- talk;
- argue;
- comfort each other;
- avoid each other;
- become friends;
- develop resentment;
- share food or small favors;
- spend time together;
- react to injuries and deaths;
- form opinions about camp decisions;
- care for animals;
- create camp-story events.

The player manages **conditions and consequences**, not conversation schedules.

### Camp stories and politics

This becomes the primary home of text/narrative events.

Camp events can surface the results of the autonomous social simulation and give the player decisions when leadership actually matters.

Routine social behavior should often occur quietly in the background/history rather than demanding a popup every time two people speak.

---

## Alpha 0.6 — Pets / Camp Animals

Pets deepen attachment and camp life without becoming a separate pet-management game.

### Tamagotchi-style state, systemic care

Animals can have lightweight persistent needs such as:

- hunger;
- health;
- stress/security;
- affection/bond;
- trust;
- age or condition where useful.

The player should **not** have to click FEED DOG every few minutes. Survivors autonomously care for pets when food, time, personality, and relationships allow it.

The interesting decisions happen when resources are scarce or circumstances are unusual.

### Relationships with survivors

Pets can bond differently with individual survivors.

Personality matters: one survivor may immediately adopt the dog emotionally, another may tolerate it, another may dislike using scarce food on an animal.

Pets can react to:

- a bonded survivor leaving on an expedition;
- injury;
- death;
- starvation or poor camp conditions;
- new survivors;
- other animals;
- loud/conflict-heavy camp conditions.

This should create emergent camp stories rather than a checklist.

### Possible practical roles

Depending on species and training, animals may eventually:

- improve morale;
- warn of nearby danger;
- accompany expeditions;
- assist with tracking/searching;
- create noise or complications;
- require treatment;
- find or carry small objects.

Any field participation becomes part of the same tactical encounter system.

---

## Alpha 0.7 — Vehicles and Expedition Logistics

Vehicles extend expeditions without turning First Fire into a driving game.

### Vehicles are expedition equipment

Useful vehicle properties may include:

- seats;
- cargo capacity;
- travel speed;
- range;
- fuel;
- mechanical condition;
- noise;
- reliability;
- storage;
- required repair parts/tools.

Different vehicles create different expedition tradeoffs rather than simple upgrades.

### The vehicle is the tactical map's "stairs"

When an expedition uses a vehicle, the vehicle becomes the **physical entry/exit anchor of the tactical encounter**—the equivalent of the stairs/transition point in a dungeon.

The party arrives at the vehicle and ultimately needs to return to it to leave, unless the situation explicitly changes that condition.

This creates natural objectives:

- get back to the car;
- protect the vehicle;
- repair it before escape;
- reach it while pursued;
- retrieve fuel or a missing part;
- abandon it and escape another way;
- move loot back to it;
- rescue someone and get them into an available seat.

A vehicle can therefore be extremely valuable without requiring any real-time driving implementation.

### Vehicles should create risk

Starting an engine, using a horn/alarm, forcing a damaged vehicle to run, or operating a loud truck can create physical sound events on the tactical map/world.

Vehicles make expeditions more capable, but they should also create new things the player can lose.

---

## Beta — Living Camp Presentation / Optional 3D Renderer

Alpha 0.3E establishes the living camp concept in 2D using the tactical renderer. By Beta, deepen that presentation based on what the finished simulation actually needs to display; move to 3D only if it provides a clear gain over the working 2D camp.

The menu remains the primary interface. Any 2D or 3D camp renderer is a living representation of settlement state, not a second Sims-style control mode.

### Visual progression

The background evolves with the real camp:

- sleeping bag and first fire;
- tents/improvised shelters;
- storage and work areas;
- cabin;
- crafting stations;
- defenses;
- larger communal areas;
- vehicles;
- pets;
- a visibly growing survivor population.

### Autonomous life becomes visible

Where practical, the background can show survivors:

- working;
- resting;
- eating;
- talking;
- arguing;
- sitting by the fire;
- caring for pets;
- repairing equipment/vehicles;
- moving through the settlement.

The 3D scene should visualize simulation state rather than secretly owning it.

---

## Beta → 1.0 — Content, Balance, Presentation, Release

No new foundational pillar should be necessary here.

Focus on:

- substantially more content using the finished systems;
- economy and progression balance over long playtests;
- tactical map/content repetition rate;
- survivor personality/relationship tuning;
- camp politics depth;
- equipment/crafting/building variety;
- onboarding and tutorial clarity;
- final art/UI/audio work;
- mobile/browser performance;
- accessibility/readability;
- save stability;
- bug fixing;
- release packaging;
- non-exploitative monetization implementation only after gameplay is stable.

Around Beta, save compatibility transitions from disposable Alpha convenience to an important player promise.

---

## Definition of "complete"

First Fire does **not** need another major mechanic to become a complete game.

The finished form is the current loop made richer:

**Camp → prepare survivors → expedition → physical tactical event → escape → persistent consequences → autonomous camp life → recover/build/craft → repeat.**

Pets, vehicles, deeper relationships, more tactical content, better graphics, and the 3D camp all strengthen that loop without replacing it.
