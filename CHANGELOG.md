# First Fire — Changelog

This file tracks player-facing changes to the playable Alpha builds.

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

### Compatibility
- Save filename remains unchanged.
- New encounter state is additive so existing Alpha saves should remain usable.

## Alpha 0.1 — First Playable Build

- Playable Godot 4 build with persistent save data.
- Core navigation: **Camp / Craft / Build / Survivors**.
- Active-time game clock with pause-on-background behavior.
- Expeditions, scavenging, loot, fatigue, stress, injury, skills, crafting, building, survivor histories, relationships, and early camp politics.
- Initial progression from one survivor, a sleeping bag, and a fire pit toward a five-person cabin settlement.
- Alpha menu art and pause-screen artwork added.
- Phone-width layout fixes and fixed four-button bottom navigation.
- Web export and GitHub Pages deployment added for browser/iPhone playtesting.
