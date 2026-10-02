## Beta Candidate — Tactical Loot Scarcity & Container Identity — 2026-10-02

- Made **Very Short / Camp Perimeter intentionally scarce at 1–2 searchable containers** and **Short / Nearby Streets 2–3**, rising to 3–5 / 4–6 / 5–7 through Medium / Far / Very Far.
- Route scarcity now trims the authored search points on each tactical visit instead of merely adding containers. The same Gas Station can expose a different subset of its car, shelf, ice box, or other plausible search points on different outings.
- Added real empty-container rolls. Baseline empty odds are highest near camp and decrease with distance; repeated zone depletion raises those odds further, making Rich / Good / Sparse / Picked Over materially affect physical tactical scavenging.
- Replaced broad global-container loot mixing with **container-specific loot families**. Fridges/ice boxes/vending favor food-water, cars/crates/debris favor salvage, washers favor cloth, and cabinets are the medical-capable container family. A fridge can no longer casually roll Scrap Metal and a salvage crate cannot roll dinner.
- Reduced extra-item rolls in early zones while allowing farther dangerous zones to produce richer multi-item containers. This preserves the 4/6/8 carry decision while making early expeditions about finding enough rather than automatically filling every slot.
- Existing empty searches already report **“nothing useful”**, so the player receives explicit feedback rather than a silent/no-op search.
- Passed current zone pressure into tactical encounter generation so the depletion system now affects the physical loot path instead of only the retired abstract haul path.
- Save schema remains **8**; tactical pressure/context and loot-generation behavior are additive.

## Beta Candidate — Progressive Tavern — 2026-10-02

- Rebuilt the hearth into a self-contained three-stage progression: **Tavern → Tavern Kitchen → Tavern Brewery**. Later Tavern visuals no longer appear automatically because unrelated housing/water buildings were completed.
- **Tavern** keeps the original fire, adds the roof/spit/rough benches, unlocks Community Stew (**2 Raw Food → 5 Cooked Food**), and improves autonomous social mood recovery.
- **Tavern Kitchen** is a paid upgrade requiring Tavern + Sewing Table + Garden Plot + Water Tank. It adds proper tables/prep space, stronger Tavern social recovery, and Kitchen Supper (**3 Raw Food + 1 Clean Water → 8 Cooked Food**).
- **Tavern Brewery** is a late paid upgrade requiring Tavern Kitchen + Barracks + Water Tank + Garden Plot. It adds brewing vessels/bar presentation, the strongest Tavern social recovery, and **Brew Beer (2 Raw Food + 2 Clean Water → 4 Beer)**.
- Added **Beer** as a real camp resource. When Brewery survivors choose autonomous Tavern social downtime and Beer is available, one Beer is consumed for an enhanced fun/stress-recovery session; if stock is gone before completion, the activity safely falls back to normal Tavern socializing.
- Dormitory now requires Tavern Kitchen as part of its mature-camp dependency chain. Mature settlement completion therefore includes all 15 planned building/upgrade projects.
- Reaffirmed hard shelter rejection: survivors encountered while the current 3/7/12/18 cap is full are turned away and are not stored as waiting recruits.
- Save schema remains **8**; existing schema-8 Taverns remain Stage 1 and the new Kitchen/Brewery/Beer state is additive.

## Beta Candidate — Shelter Quality, Hard Caps & Early Workbench — 2026-10-02

- Set the shelter/population ladder to exact hard caps of **3 → 7 → 12 → 18** for starter bedroll camp → Large Tarp → Barracks → Dormitory. Recruitment no longer allows one survivor beyond shelter; full camps explicitly turn arrivals away.
- Expanded living-camp sleep presentation to three starter bedrolls, seven tarp sleep positions, twelve Barracks positions, and eighteen Dormitory positions.
- Normal autonomous sleep is now **8 in-game hours**. Better housing progressively restores more Fatigue, reduces more Stress, reaches the Rested moodlet faster, and improves ordinary idle recovery.
- Made the first **Workbench** a light no-prerequisite build costing **2 Wood + 1 Scrap Metal**. Before it exists, crafting is limited to First Fire Cook Food, Boil Water, and Bandage.
- Deepened late-building tech dependencies and costs: Infirmary now also requires Water Tank; Armory requires Watch Post; Dormitory requires the mature shelter/social/medical/water chain.
- Tavern remains one building identity but now **visually evolves with camp infrastructure**: initial spit + rough benches, then proper tables, cleaner prep surfaces, and a mature bar/counter as Barracks, Water Tank, and Dormitory come online.
- Save schema remains **8**; this is a compatible balance/progression refinement because the new shelter caps are not below the just-shipped schema-8 capacities in a way that strands existing saves.

## Beta Candidate — Camp Expansion & Building Progression — 2026-10-02

- Rebuilt camp growth around four readable lanes: **Shelter**, **Hearth**, **Utility**, and **Security**. The physical work board is now the permanent construction planner while unbuilt map anchors remain hidden.
- New games now start with only the **First Fire, one sleeping bag, and communal storage**. Workbench is no longer granted for free.
- Replaced additive legacy housing with a tiered shelter path: **Sleeping Bag (1) → Large Tarp (4) → Barracks (10) → Dormitory (18)**. Higher tiers replace the earlier sleeping presentation rather than stacking disconnected housing.
- Added **Tavern** as the First Fire upgrade. It improves autonomous social/fun downtime, enables shared-meal camp events, and unlocks **Community Stew** (2 Raw Food → 5 Cooked Food) at the hearth.
- Workbench remains the basic weapon/tool/component station after construction. **Crossbow, Sledgehammer, Hatchet, Bolt Cutters, and Toolbox now require the Armory**; Lock Pick and other basic Workbench recipes remain available without Armory.
- Retired the active **Makeshift Shelter, Cabin, Communal Table, and Bunkhouse** building identities. Barracks/Tavern absorb their housing/social roles; Storage Crate remains a baseline camp fixture rather than a build project.
- Preserved and clarified utility roles: Rain Catcher produces water, Water Tank doubles its yield and supports hygiene, Garden Plot produces food when tended, Infirmary improves medical recovery and crafts Zombie Cure, Noise Line/Watch Post improve perimeter safety, and Armory unlocks advanced fabrication.
- Added duplicate-safe construction ownership, work-board build progress, upgraded living-camp visuals for tarp/tavern/barracks/dormitory, and deterministic regression coverage for the new progression and recipe gates.
- Save schema advances to **8**. Schema-7 saves are intentionally invalidated instead of mapping old Cabin/Bunkhouse/Communal Table state into the new progression.

## Beta Candidate — Corpse Cure Crafting & Count-Only Carry — 2026-10-02

- Added **Zombie Corpse** as physical tactical loot. A killed infected corpse can be harvested from the board; harvesting persists across tactical reloads and each recovered corpse consumes exactly one pooled expedition carry slot.
- Added **Zombie Cure** crafting at the built Infirmary: **2 Zombie Corpses → 1 Zombie Cure**. The cure remains the rarest direct medical find, so players may find one or manufacture one from dangerous field recovery.
- Expedition hauling is now explicitly **count-only**: 4 slots with no pack, 6 with common packs, 8 with better packs. Removed gear weight/size metadata and removed equipment-load penalties from tactical action timing; weight no longer affects carry or action speed.
- The living-camp Infirmary is now a direct crafting touch target when built.
- Expanded architecture smoke contracts for corpse harvesting/persistence, the corpse-to-cure recipe, Infirmary crafting access, slot-only carry, and load-independent tactical timing.
- Save schema remains **7**; the corpse resource and per-zombie harvested flag are additive.

## Beta Candidate — Medical Supply Rarity Pass — 2026-10-02

- Reworked medical supplies into a clear three-tier economy: **Bandages are crafted** at the First Fire, **First Aid Kits are rare found-only supplies**, and **Zombie Cure is found-only and the rarest medical find**.
- Hurt/Wounded treatment now consumes Bandages; Critical trauma consumes a First Aid Kit.
- Early zombie-virus exposure decontamination uses 1 Clean Water + 1 Bandage. Established infection consumes 1 Zombie Cure, while Feverish emergency care still requires a built Infirmary plus 1 Zombie Cure.
- Tactical resource/container loot now stores medical components directly. First Aid Kits begin appearing rarely on Nearby Streets; Zombie Cure does not enter the loot table until Residential Blocks and remains lower-weight than First Aid Kits.
- Removed First Aid Kit from active gear/crafting pools. Schema-7 saves normalize legacy Medicine into First Aid Kits, Sterile Dressings into Bandages, and old First Aid Kit gear into the new consumable supply without a save wipe.
- Save schema remains **7**.

## Beta Candidate — Camp Fatigue, Live Chores & Carry Capacity — 2026-10-01

- Lock Picks can now be **crafted at the Workbench** for 1 Scrap Metal + 1 Hardware as well as found in the field. Each Lock Pick rolls **1–3 successful unlock uses** before breaking; schema-7 Lock Picks carrying older 4–5-use state are clamped into the new range when equipped/stored.
- Rebuilt expedition resource carry around a clear backpack ladder: **4 items with no pack, 6 with common packs, 8 with better packs**. All backpacks are now **field-found only**; backpack and Pack Frame crafting recipes were removed, and new recruits no longer spawn with a free pack.
- Physical tactical container loot now obeys the pooled carry capacity of the one- or two-survivor expedition party. Overflow resource units are left behind when capacity is full; named field-gear objectives remain separate from resource carry capacity.
- The tactical HUD and survivor inspector now expose current/max expedition carry capacity.
- **Double-Barrel Shotgun is now one-handed** while retaining its 2-shell, 3-projectile, tight-spread physical-range role.
- Daily camp chore minigames no longer pause settlement simulation. The overlay is a lower translucent sheet so the living camp stays visible, and the assigned survivor performs a chore-specific animation at the real camp work location while the player completes the touch interaction.
- Reworked fatigue into a work-pressure loop: **idle camp time naturally reduces fatigue**, while chores, crafting/building/training and expedition return fatigue continue to raise it. Removed the extra fixed tactical-resolution fatigue that previously stacked on top of route fatigue.
- At **100 fatigue**, a survivor enters **Exhausted**, goes to a bed/sleep slot for a random **3–5 in-game hours**, visibly shows a POUTING/rest state, and returns with **0 fatigue / full sleep need**. If work is already underway, its exact task/progress is suspended during the exhaustion rest and resumes afterward so paid materials and chore progress are not lost.
- Expanded architecture smoke and CI source contracts for the 1H Double-Barrel, craftable 1–3-use Lock Pick, found-only 6/8 backpacks, active tactical carry enforcement, non-pausing live chore minigames, idle fatigue recovery, and forced exhaustion rest.
- Save schema remains **7**; these changes use additive normalization/compatibility state.

## Beta Candidate — Firearm Magazines, Found-Only Off-Hand Tools & Tactical Locks — 2026-10-01

- Rebuilt ranged weapons around **magazines/chambers and explicit tactical reloads**. The shared camp `Ammo` resource is retired and is removed from loaded schema-7 saves.
- Firearms are now **field-found only**; firearm Workbench recipes were removed. Crossbow remains the craftable ranged option.
- Added the final firearm lineup:
  - **6-Shot Revolver** — 6 rounds, short optimal range, can fire to any visible target with accuracy falloff.
  - **12-Shot Automatic** — 12 rounds, faster handling, short optimal range, steeper distance falloff.
  - **Double-Barrel Shotgun** — 2 shells, 3 projectiles per shot, tighter spread, **5-tile physical pellet range**.
  - **Pump Shotgun** — 6 shells, explicit **PUMP** action between shots, 5 projectiles per shot, wider spread, **4-tile physical pellet range**.
  - **Medium Rifle** — 20-round magazine, medium optimal range, fire-to-vision distance falloff.
  - **Long Rifle** — 5-round magazine, long optimal range, fire-to-vision distance falloff.
- Crossbow now has a **1-shot chamber**, explicit reload, 7-tile physical range, and retains its 2–3-hit infected kill role.
- Tactical save/resume persists current loaded count and Pump Shotgun chamber/pump state. Reloading uses tactical time but consumes no camp resource.
- Replaced the active off-hand pool with exactly three **found-only** items:
  - **Flashlight** — finite persistent charge; charge drains while the light is on and the light shuts off at zero.
  - **Lock Pick** — starts with a random 3–5 uses and breaks when the final use is spent.
  - **Firecracker** — one use; thrown forward as a loud tactical sound lure, then consumed.
- Added locked tactical doors and optional locked loot containers, with lock frequency rising by expedition distance. Marked exploration objective containers are not locked, preventing an expedition objective from requiring a Lock Pick.
- Lock/off-hand condition persists through tactical saves and returns to the survivor's equipped state when the expedition ends. Unequipping an off-hand item preserves its remaining condition in camp inventory state.
- Legacy generic Pistol/Shotgun/Rifle and retired portable-light entries remain compatibility aliases/data only for existing schema-7 saves; they are not active field/craft content.
- Updated deterministic architecture smoke and CI source contracts for found-only firearms/off-hand items, magazine capacities, pump behavior, physical shotgun range/projectile counts, distance hit falloff, tactical locks, and off-hand durability.

## Beta Candidate — Weapon Kill Ladder & Ranged Roles — 2026-10-01

- Rebuilt tactical weapon damage around the fragile **7–10 HP infected** contract so kill counts are authored by weapon tier instead of silently collapsing from Combat damage scaling.
- Final melee progression:
  - **Bare Hands:** 3–5 clean hits.
  - **Utility Knife:** 2–3 hits.
  - **Kitchen Knife / Hammer / Crowbar:** exactly 2 hits.
  - **Wooden Club / Baseball Bat / Improvised Spear:** 1–2 hits.
  - **Sledgehammer:** 1 hit (new heavy 2H melee tier).
  - **Hatchet:** 1 hit 1H melee; intentionally expensive to craft and moved to later Commercial Fringe field loot.
- Added the **Crossbow** as a normal Workbench craft. It deals 4–5 ranged damage for a 2–3 hit kill, has a hard **7-tile medium range**, is much quieter than firearms, and consumes the existing generic Ammo resource.
- Firearms now have explicit roles and hard max ranges:
  - **Pistol:** 1-hit, 4-tile short range.
  - **Shotgun:** 1-hit, 4-tile short range with a real forward cone that can hit/kill multiple infected in one shot.
  - **Rifle:** 1-hit, 10-tile long range; new Armory-gated late weapon.
- Rifle sighting can extend tactical vision enough to use its authored long range, while darkness/lighting rules still constrain actual visibility.
- Combat now primarily improves attack reliability rather than adding enough raw damage to erase the authored kill-count ladder.
- Added Crossbow, Sledgehammer, and Rifle to gear/crafting/field-loot catalogs and tactical weapon visuals. Crossbow is available without Armory; Pistol/Shotgun/Rifle remain Armory-gated.
- Expanded deterministic smoke and CI contracts for every kill-count tier, hard ranged ranges, shotgun cone behavior, Crossbow craftability, and the Hatchet expense/rarity rule.
- Save schema remains **7**; the new gear entries are additive.

## Beta Candidate — Scratch / Bite Infected Attacks — 2026-10-01

- Split infected attacks into two explicit tactical attacks:
  - **Scratch** — the normal attack (80% of attack attempts), higher hit chance, low physical damage, and **zero virus exposure chance**.
  - **Bite** — rare (20% of attack attempts), substantially lower hit chance, higher physical damage, and the **only** infected attack that can transmit the zombie virus.
- Bite transmission is now a fixed **3% independent roll per successful bite**. The infection percentage never rises or stacks from prior bites or scratches; multiple bites simply create separate 3% checks.
- Removed generic infected-hit accumulation from the active virus pipeline. Tactical runtime now persists successful bite counts for the lead and optional companion, and camp resolution evaluates only those bite events.
- Tuned common infected durability against the starter weak weapon: the Utility Knife now deals **4–5 damage**, while common LIGHT/MED infected use **7–9 / 8–10 HP**, producing a reliable **2–3 clean-hit kill**. HEAVY infected remain somewhat tougher.
- Preserved the weak-single / dangerous-mob direction: mob size can still raise attack pressure and cadence, but it does not turn Scratch into an infection vector.
- Added deterministic CI/smoke contracts for Scratch-vs-Bite hit/damage ordering, fixed per-bite infection probability, bite-only tracking, companion bite exposure, and the starter-knife 2–3-hit relationship.

## Beta Candidate — Weak Infected, Mob Pressure & Rare Virus — 2026-10-01

- Rebalanced individual infected downward: light/medium/heavy HP bands and base damage are lower, and a lone infected now has a substantially lower grab chance than the previous Alpha tuning.
- Added explicit **mob-pressure mechanics**. Nearby infected improve grab accuracy, add only a small damage bump at 3+ attackers, shorten repeated attack cadence, widen local alert radius, and groups of 3+ can pull nearby packmates directly into a chase instead of acting as isolated enemies.
- Kept the distance population curve from the prior tactical patch, so farther exploration still adds infected; the threat now comes primarily from density/positioning rather than inflated single-zombie stats.
- Added distance-scaled searchable-container targets: **Very Short 3–5**, Short 4–6, Medium 5–7, Far 6–8, Very Far 7–9. Existing authored props/obstacles are promoted into additional searchable caches where available, preserving the physical container/search loop.
- Actual larger tactical geometry remains scheduled for the next combat/stealth/environment overhaul; this patch does not fake bigger maps with empty padding.
- Made zombie-virus transmission much rarer: one successful direct infected hit now carries **3%** exposure risk, repeated direct hits rise gradually to a **12% maximum**, Exposed has a **50% natural-clear chance**, and unquarantined camp spread was reduced.
- Expanded deterministic smoke/CI contracts for weak lone infected, mob bonuses, rare exposure, and distance-scaled searchable-container targets.

## Beta Candidate — Sparse Near-Field Infected Counts — 2026-10-01

- Rebalanced tactical infected populations around expedition scenario type and distance.
- **Very Short / Camp Perimeter exploration now rolls 0–3 infected** and is the only expedition tier that can produce a lucky 0- or 1-infected map.
- All longer exploration now has a minimum of **2 infected**; the existing distance curve remains above that floor.
- **Ambushes use exactly 5 infected**, **pet rescues 3**, and **survivor rescues 5**, regardless of expedition distance.
- Removed the old global `quiet_explore = 0 infected` shortcut; quiet longer-distance exploration now reduces pressure without bypassing the 2-infected floor.
- Routed rescue subtype and quiet/explore state through `FFTacticalBalance` as the single owner for tactical population rules.
- Recorded the next planned tactical completion slice in `ROADMAP.md`: combat/stealth feel, infected AI/perception, sound propagation/feedback, and lighting/graphics polish including a Web/mobile-safe bloom/glow evaluation.

## Beta Candidate — Lean Start & Instant Tactical Travel — 2026-10-01

- Reduced founder starting carried loot to **one item total: Utility Knife**. The starter Flashlight and Worn Backpack are no longer granted; the communal starting food/water runway is unchanged.
- Standard expeditions and special-site outings now open the tactical map **immediately** without advancing settlement time first.
- Tactical play still hard-pauses the settlement clock. When the tactical encounter resolves, the expedition's full authored route duration advances the camp in one synchronous jump before the party is returned.
- Reused the persisted `time_cost_paid` flag as the once-only guard, so reloads cannot double-charge route time and older expeditions that already paid travel time remain safe.
- Provisioned Medium/Far/Very Far parties still receive their paid food/water coverage during the return-time jump; travel supplies remain charged at launch.
- Updated gate copy, deterministic architecture smoke, and CI source contracts to enforce immediate tactical launch plus return-time settlement advancement.

## Beta Candidate — Five-Minute Days & Proper Expeditions — 2026-10-01

- Extended the single authoritative camp day from **120 real active seconds to 300 seconds / 5 minutes** with no hidden simulation-speed multiplier. One in-game hour is now **12.5 real active seconds**.
- Retuned camp-life cadence for the longer day so hunger/thirst/fun/hygiene decay, awake fatigue, sleep length, fire decay, camp-condition decay, chatter/event cadence, and autonomous meal/drink/sleep actions keep roughly the same per-in-game-hour behavior rather than running 2.5× too fast.
- Recast the five existing expedition zones as explicit distance bands: **Very Short (Camp Perimeter, 3h)**, **Short (Nearby Streets, 5h)**, **Medium (Residential Blocks, 8h)**, **Far (Commercial Fringe, 12h)**, and **Very Far (Industrial Edge, 18h)**.
- Very Short and Short expeditions have **no travel-supply cost**. Medium costs **1 Cooked Food + 1 Clean Water per survivor**; Far costs **2 + 2 per survivor**; Very Far costs **3 + 3 per survivor**.
- Medium and Far are available without a vehicle. Very Far is the only route gated by the additive **Expedition Vehicle** unlock seam; no full driving/fuel/vehicle-maintenance system was added.
- Expedition parties now support **one or two survivors**. The gate lets the player choose a lead plus an optional companion and previews the total Food/Water cost before launch. Costs multiply directly with party size.
- Reactivated the tactical runtime's existing companion actor for the second expedition survivor: the companion follows the lead, fights infected, can be targeted/injured/killed, persists across tactical saves, and must catch up to extraction before the party can leave.
- Companion tactical HP now returns to persistent survivor condition. Special-site outings use the same party, route-time, supply-cost, and Very Far vehicle rules as normal expeditions.
- Save schema remains **7**. The Expedition Vehicle flag is additive; current saves normalize Medium/Far as reachable and Very Far as locked until that explicit vehicle flag is earned.

## Beta Candidate — Always-Tactical Send Out & Unified Camp Time — 2026-10-01

- Reworked the camp gate so every normal Send Out launches a tactical map after paying its authored travel time once. Previously discovered special sites now also route through tactical play instead of a passive travel-only branch.
- Starting expedition access is exactly **Camp Perimeter (3 in-game hours)** and **Nearby Streets (5 in-game hours)**. Farther zones remain visible but locked behind explicit future long-range-travel unlock flags; repeated expeditions no longer auto-unlock them.
- Rebalanced tactical outing selection to **73% exploration** (40% quiet / 33% infected), **20% zombie ambush**, **5% stranded survivor**, and **2% dog/cat rescue**. Quiet exploration can contain zero infected.
- Ambush, rescue, and exploration maps all retain physical loot containers. Standard tactical outings no longer receive a second invisible abstract loot haul after escape; only physically recovered tactical loot/gear is retained.
- Route travel advances the ordinary settlement simulation before tactical launch. Once the tactical board opens, settlement time is hard-paused and tactical turns consume no camp time.
- Removed the secondary **0.5× simulation multiplier** entirely. The 120-second authored day is once again the only settlement clock: **5 real active seconds per in-game hour / 120 real active seconds per day**.
- Expanded deterministic architecture smoke and CI source gates for the unified clock, exact 3h/5h starting routes, locked long-range routes, always-tactical routing, encounter rarity ordering, quiet exploration, and tactical pause behavior.
- Save schema remains **7**; route-unlock state is additive and existing schema-7 saves normalize to the two starting routes unless an explicit new long-range unlock flag is present.

## Beta Candidate — Camp Time & Autonomous Needs Rebalance — 2026-10-01

- Slowed settlement simulation back to **0.5×**, restoring **10 real active seconds per in-game hour** and roughly **4 real active minutes per in-game day** while keeping existing authored simulation-second task durations coherent.
- Fixed the root sleep bug: Available survivors no longer passively erase Fatigue every tick. Awake time now builds normal sleep pressure, and overnight sleep is a real ~7-hour authoritative Sleeping task that substantially restores Fatigue.
- Replaced invisible end-of-day food/water fulfillment in the active runtime with visible autonomous need actions: survivors seek a midday water break and an evening meal, consume 1 Clean Water / 1 Cooked Food when available, and immediately restore Thirst/Hunger.
- Daily activity now records actual eating, drinking, and meaningful sleep rather than inferring them merely from being free during a window.
- Added a midday water-opportunity window alongside existing meal/sleep pressure. Player-assigned work can now make a survivor miss a water break, meal, or sleep, with those consequences kept separate from true resource shortages.
- Kept schema 7. New daily-activity fields normalize additively for current saves.
- Expanded deterministic smoke coverage for real autonomous water/meal selection, meaningful sleep recovery, shortage penalties, and the slower settlement clock.

## Beta Candidate — Daily Camp Chores & Minigames — 2026-10-01

- Replaced threshold-based active maintenance buttons with a persisted daily work-board loop that rolls exactly **1–2 required chores** from **Poke Fire, Chop Wood, Clear Area, Stack Supplies**.
- Made the physical camp work board visible/clickable and the single active chore entry point; survivor inspectors now point players back to the board instead of exposing a competing chore path.
- Added one reusable portrait/touch chore-minigame overlay. Its deterministic target sequence varies by persisted chore seed/progress, pauses settlement time while the player interacts, and can be safely closed/reopened without rerolling or duplicating rewards.
- Poke Fire restores First Fire without Wood cost; Chop Wood yields exactly +1 Wood; Clear Area restores 12 camp condition; Stack Supplies restores 9. Each unfinished daily chore costs 4 additional camp condition at rollover.
- Chore assignments remain real timed survivor tasks (5.0–10.0 settlement seconds), feed Slice 1 assigned-work meal/sleep pressure, and cannot use unavailable survivors.
- Added bounded five-day duty participation/eligibility state and a read-only fairness snapshot so later camp events can notice repeated overuse while excluding survivors who were not eligible to contribute.
- Kept save schema 7: current chores, progress, completion/reward state, and duty rotation normalize additively and today's chores do not reroll on load.

## Beta Candidate — Camp Condition & Daily Activity Foundation — 2026-10-01

- Promoted the existing persistent camp-maintenance score into the authoritative camp-condition model with derived **Well Kept +1 / Acceptable 0 / Neglected -1 / Poor -2 / Severe -3** mood bands.
- Centralized camp-condition degradation and cleaning/perimeter recovery in `FFCampLifeRules.gd`; the work board now shows condition, mood effect and score directly.
- Added additive schema-7-safe daily survivor activity accounting for assigned work, expeditions, care, autonomous life, and normal meal/sleep opportunities, plus one bounded previous-day summary for future camp events.
- Assigned productive work can now crowd out the authored evening meal and overnight sleep windows. Sustained overlap records missed meals/sleep and feeds consequences back through existing Hunger, Fatigue and Stress rather than creating duplicate needs.
- Tactical pause continues to freeze camp degradation and daily-activity accounting. Existing valid schema-7 saves normalize the new survivor fields without a reset.
- Added deterministic architecture smoke coverage for condition bounds/recovery/bands, daily reset, work-vs-autonomous schedule pressure, and pause-boundary source contracts.

## Beta Candidate — Living Wilderness Camp — 2026-10-01

- Reframed the camp as the Sims-style home screen: a sparse wilderness start with First Fire, one bedroll, communal storage, and a starter Workbench rather than visible future-building placeholders.
- Survivor inspectors now own deliberate camp assignment: Combat/Agility/Leadership training, maintenance work, treatment, and expedition handoff.
- Camp chores and pet care now run as timed survivor activity after assignment instead of repeated WORK-button tapping.
- Added capped survivor training: two sessions per survivor per day, two in-game hours per session, awarding 5 stat XP plus fatigue.
- Expanded autonomous mood-driven camp behavior so unassigned survivors visibly sleep, check rations/water, wash, watch the treeline, wander, watch the fire, and continue social chatter.
- Future build anchors remain code/data only; the starter camp no longer renders empty plot placeholders or a work-board management prop.

## Beta Candidate — Settlement Clock Retune — 2026-09-14

- Retuned settlement time to a direct **5 real seconds = 1 in-game hour** mapping. A full in-game day now takes 120 real active seconds (2 minutes).
- The existing Camp Perimeter trip remains 10 base seconds, which now reads as a 2-hour round trip before the existing Agility travel-time reduction.
- Needs, work/recovery, expeditions, fire/maintenance, camp events, and daily transitions continue to share the same settlement simulation clock.

## Beta Candidate — Camp Return & Crafting Feedback — 2026-09-14

- Routine expedition returns now produce a persistent tap-to-dismiss camp notice with the survivor and exact haul (or empty-handed result), instead of relying only on a transient toast.
- Simplified the camp header: the in-world title now shows only `FIRST FIRE CAMP • DAY N`; the top HUD remains the clock/resource source, idle `RUNNING` is hidden, and the activity line appears only for useful away/work/pause states.
- Disabled crafting recipes now state the exact missing resource/component counts such as `Raw Food 0/1` or `Sterile Dressing 0/1`.

## Beta Candidate — Camp Focus & Problem-Driven Management — 2026-09-14

- Zoomed the living camp for portrait play and added drag panning instead of shrinking the full settlement into a narrow minimap strip.
- Removed persistent BUILD/CRAFT/STASH/WORK/SEND OUT text clutter from the camp; physical objects remain tappable and subtle interaction rings plus problem alerts carry the affordance.
- Camp chores are now problem-driven: fire tending appears below 48%, cleaning below 68% maintenance, and perimeter repair below 42%. The camp view adds visible dirt/damage/alert cues when attention is actually needed.
- Flattened expedition preparation into the physical gate sheet: choose the available survivor, destination, see danger/likely finds, then LEAVE CAMP without entering a second SEND OUT modal. Inspector SEND OUT routes back to the same gate flow.
- Simplified one-survivor worker selection so disabled PREV/NEXT controls no longer clutter early camp tasks.
- Removed the development ad placeholder from active gameplay and compacted the top camp HUD for narrow phones.
- New games now start with 3 Cooked Food and 3 Clean Water, giving the founder roughly three daily rations before scavenging must sustain the settlement.

## Beta Candidate — Authoritative Sleep, Zombie Virus & Slower Camp Time — 2026-09-12

- Sleep is now an authoritative survivor state instead of a passive label. Tired survivors enter a timed **Sleeping** task, move to a real sleeping slot in the living camp, lie down visually, and cannot be assigned to work, expeditions, or equipment changes until they wake.
- Active treatment, crafting, building, garden work, chores, pet care, expeditions, quarantine, and severe illness likewise keep survivors unavailable; the active Game layer now owns the assignment check instead of relying on UI convention.
- Added a separate persistent **zombie-virus** axis without conflating it with physical wounds. Only successful direct infected attacks create field exposure risk; repeated infected hits increase that risk, while generic damage does not.
- Virus progression is **Exposed → Infected → Feverish** if untreated. Exposed cases can use 1 Clean Water + 1 Sterile Dressing for early decontamination; established infection uses 1 Medicine; Feverish emergency care requires a built Infirmary + 2 Medicine. Untreated Feverish infection can become terminal at the next daily transition.
- Added **Quarantine** as a real alternative: the survivor becomes unavailable but cannot spread established/severe infection through close camp contact. Unquarantined infected survivors can expose campmates.
- Settlement simulation now runs at half the previous real-time speed. The 120-second simulation day therefore takes about **4 real active minutes** instead of 2; needs, work/recovery, expeditions, fire/maintenance, camp events, and daily virus progression all use the slower simulation clock.
- Save schema remains 7. Virus state is additive/normalized through the active runtime; the existing three-stat save compatibility boundary remains intact.


## Beta Candidate — Combat Movement & Pet Bond Tuning — 2026-09-12

- Increased tactical danger modestly: infected hit chance is slightly higher and medium/heavy infected can roll one additional point of maximum damage.
- Made active movement pacing explicit and regression-tested: crouch is materially slower than walking and sprint materially faster than walking across the full Agility range, including crouched backpedaling through the shared movement-cost seam.
- Simplified pets to Bond/Affection only. Pets no longer consume Raw/Cooked Food or Clean Water; PLAY and LOVE are the only pet-care assignments.
- Neglected pets can leave First Fire when affection falls too low. Every pet that remains contributes exactly one random material or Raw Food per in-game day.
- Save schema remains 7; existing pet state is normalized down to its existing affection value.


## Camp work and rescued pets

- Added tactical dog/cat rescue candidates using the existing physical rescue/escort/extraction loop; forced survivor-recruit catch-up rescues remain human.
- Added persistent camp pets; current tuning uses Bond/Affection as the pet retention meter, with no pet food/water consumption and one daily material-or-Raw-Food contribution per retained pet.
- Added touch-first pet care assignments (PLAY/LOVE in current tuning) and manual camp chores (stoke fire, clean camp, repair perimeter). Assigned chores require repeated WORK taps, making camp maintenance an active minigame rather than hidden automation.
- Survivor eating/drinking, sleeping and fun remain passive/idle. Productive fire maintenance and washing were removed from autonomous downtime.
- Added persistent camp-maintenance condition that affects camp safety and requires upkeep.

## Beta Candidate — Tactical Map Planning, Physical Loot & Rescue Reliability — 2026-09-11

- Reworked authored extraction so tactical maps no longer place the escape beside the entry; every layout now guarantees a reachable exit at least eight route steps from spawn.
- Added real searchable map containers (dumpsters, shelves, fridges, cabinets, crates, vehicles, washers, carts and debris). Containers roll zone-appropriate supplies, persist through tactical save/resume, and only pay out after a successful escape. Explore objectives now use these physical containers instead of abstract floor search spots.
- Rebalanced infected by objective and zone, added mass-aware HP bands, kept exits/search containers clear of initial spawns, and gave Rescue/Explore more setup space.
- Fixed Rescue civilians being targetable before the player could reach them. They are now protected until first contact, then become vulnerable escorts with slightly improved HP/pacing.
- Improved tactical planning/readability: Rescue SOS stays visible with route distance, the active HUD shows objective/exit distance, and discovered containers are visibly marked as LOOT/OPEN.
- Save schema remains 7; tactical container/runtime fields are additive.

## Beta Candidate — Forward Control & Guard Removal — 2026-09-11

- Removed Guard from the active tactical combat model and from infected hit/damage handling.
- Moved the dedicated FORWARD touch action into Guard's former center-top control slot; the previous forward slot now carries the compact tactical tick/step/kill readout instead of overlapping BACK.
- Shove remains the spacing/stagger action, with infected mass continuing to affect resistance and stagger.
- Existing in-progress tactical runtime discards stale Guard state without changing save schema 7.

## Beta Candidate — Camp Needs, Moodlets & Autonomous Downtime — 2026-09-11

- Added six persistent survivor needs: Hunger, Thirst, Sleep, Fun, Safety, and Hygiene. Sleep stays synchronized with existing Fatigue instead of creating a second exhaustion system.
- Added positive/negative moodlets; unmet needs add gradual stress pressure, while existing daily food/water upkeep feeds Hunger/Thirst without duplicating resource consumption.
- Added interruptible autonomous camp life for Available survivors: maintaining the fire, resting, washing up, watching the fire, playing cards, and playing guitar.
- Fire strength now persists, decays with camp time, affects safety and camp glow, and consumes 1 Wood when maintenance completes. Player work/expeditions always override autonomous activity.
- Survivor roster and inspector expose moodlets/needs and current autonomous activity. Existing schema-7 saves receive backward-compatible defaults; schema remains 7.

## Beta Candidate — Tactical Clock & Portable Light Control — 2026-09-11

- Tactical encounters now use the settlement clock at encounter creation, exposing DAWN / DAY / DUSK / NIGHT instead of an unrelated random day/night roll.
- Dawn and dusk use intermediate ambient/daylight strength, and the tactical location header carries the encounter clock time.
- Equipped Secondary lights now have an explicit touch-safe LIGHT ON / LIGHT OFF control plus an `L` keyboard fallback. Switching a light is immediate, recalculates visibility/detectability, and persists across tactical save/resume without advancing tactical time.
- Portable-light view bonuses and sound-awareness assistance only apply while the light is switched on.
- Save schema remains 7; the added tactical runtime flag is additive.

## Beta Candidate — Live Survivor Vitals & Treatment Feedback — 2026-09-11

- Survivor roster cards now update fatigue, stress, condition, activity/recovery state, expedition countdowns, and SEND OUT availability in place on the normal simulation tick; switching tabs is no longer required to see values change.
- Confirmed the existing TREAT simulation path was functional: Hurt consumes a Sterile Dressing and caps recovery at 30 seconds; Wounded/Critical consumes Medicine and starts a timed recovery task.
- Treatment now gives explicit success toasts/history instead of silently mutating hidden recovery state.
- Survivor inspection now shows injury/treatment time remaining and the treatment resource requirement, including the fact that the inspector pauses camp time while open.
- Save schema remains 7.

## Beta Candidate — Safari SEND OUT Selector Fix — 2026-09-11

- Replaced the SEND OUT zone `OptionButton` popup with explicit touch-safe PREV / NEXT controls and a visible selected-zone detail line.
- Opening SEND OUT now pauses camp simulation; SEND and CANCEL restore the pause state that existed before the modal opened.
- Special-site dispatch uses the same modal close/restore path.
- Added a deterministic architecture smoke guard so the expedition selector cannot silently regress back to a popup `OptionButton`.
- Save schema remains 7; this is UI/input behavior only.

# First Fire — Changelog

## Beta Candidate — Physical Survivor Rescue — 2026-09-10

- Promoted Survivor Rescue from an abstract SOS-cell objective into a physical tactical escort encounter.
- Rescue encounters now generate a real named survivor with a persistent appearance and identity before the board opens.
- The player must reach the survivor and explicitly make contact; the civilian then follows the player but does not fight.
- Infected can see, target, injure, and kill the rescue civilian, so route choice, noise, Guard/Shove use, and extraction timing matter.
- Successful rescue requires the expedition survivor and rescue civilian to reach an exit together; self-extraction remains valid at the cost of the rescue.
- The exact rescued survivor, including tactical injury condition, carries into the post-extraction recruitment offer instead of generating a different person afterward.
- Rescue is now available in Camp Perimeter as well as later zones; rescue encounters run one infected below zone baseline to account for the vulnerable escort.
- Active rescue position, HP, contact state, and escort timing persist across tactical save/resume without changing save schema 7.

## Beta Candidate — Tactical Depth, Exploration & Balance — 2026-09-10

- Added **Guard**: spend tactical time to reduce the next infected grab chance; a guarded hit also loses one damage.
- Added **Shove**: create space without dealing normal damage. Infected mass now matters to shove resistance and stagger duration.
- Differentiated weapons further: knives gain accuracy, the improvised spear reaches two straight-line cells, blunt/pry weapons displace better, and shotguns can damage infected adjacent to the primary impact.
- Rebalanced infected attacks so light/medium/heavy mass produces different damage ranges while existing per-infected pace continues to drive chase timing.
- Expanded Explore into a real sweep: 3–5 search locations depending on zone, one hidden target-gear cache, explicit tactical search time/noise, and persistent searched-state across tactical save/resume.
- Partial Explore retreats now keep a bounded amount of supplies from physically searched caches even when the marked gear was not found.
- Exploration spawns one fewer infected than the zone baseline; ambushes remain one above baseline. This preserves encounter identity instead of scaling every objective the same way.
- Tactical search rewards scale with search depth and Scavenging skill but are capped to avoid stacking into huge loot piles alongside the normal expedition haul.
- A successful Explore no longer also rolls a second random post-expedition gear drop; the physical marked item is the gear reward for that tactical objective.
- Tactical encounter fatigue was reduced from a 6-point base to 4 before the existing fatigue multiplier, while Combat XP now comes from actual attacks/shots/kills instead of receiving a flat participation award.
- Added deterministic smoke contracts for exploration scale/rewards, objective-specific infected counts, Guard, Shove mass resistance, and Scavenging search speed.
- Save schema remains 7; the added tactical runtime fields are additive.

This file tracks player-facing changes to the playable Alpha builds, plus major technical changes that affect development/reliability.

## Beta Candidate — Safari Scroll & Font-Safe Controls — 2026-08-22

### Mobile / Safari Scrolling
- Main Camp/Craft/Build/Survivor content and the survivor/inventory inspector now share a dedicated touch-scroll adapter instead of depending on mouse emulation for the scrollbar thumb.
- Vertical scrollbars use a wider 30 px touch target and respond directly to `InputEventScreenTouch` / `InputEventScreenDrag`, which keeps tactical touch-to-mouse emulation disabled and avoids reintroducing combat double-input risk.
- Added deterministic architecture smoke coverage for the touch target and scrollbar position mapping.

### Missing-Glyph Controls
- Replaced the worker picker's Unicode triangle pseudo-icons with font-safe `PREV` / `NEXT` buttons. The triangles could render as the default font's missing-character box on Web and desktop builds.
- Tactical/camp atlas mappings were inspected during this pass; authored environment prop kinds already map to real atlas regions, so the visible missing-character-style boxes were treated as font glyphs rather than missing sprite assets.
- Save schema remains **7**.

## Beta Candidate — Onboarding & Worker Picker Fix — 2026-08-17

### Craft / Build Worker Selection
- Replaced the Craft/Build worker `OptionButton` popup with direct previous/next survivor controls. This avoids the Web/mobile dropdown path that could leave the Craft screen unresponsive when changing workers.
- Worker switching now defers the content rebuild until the button input callback has completed, avoiding deletion/reconstruction of the active control tree from inside its own signal.

### New-Save Quick Start
- Added a compact four-step first-save tutorial covering camp food/water and time, sending a survivor out, Craft/Build worker assignment, and tactical ticks/vision/sound/escape.
- The simulation pauses while the quick-start overlay is open and restores its prior pause state when the tutorial is finished or skipped.
- New saves persist `tutorial_complete`; existing schema-7 Beta saves without that flag are treated as already onboarded and are not interrupted.
- Save schema remains **7**.

## Beta Candidate — Feature Freeze & Living Camp Politics — 2026-08-13

### Final Scope / Population
- First Fire is now in feature freeze: no new gameplay pillars are planned before Beta.
- Permanently cut 3D camp rendering, pets, vehicles, multi-survivor expeditions, and tactical companion AI.
- Expeditions are now single-survivor dispatches in both UI and simulation APIs.
- Added a hard **18-survivor** population ceiling. Housing now grows additively through the final building tree to exactly 18 beds.
- The mature-settlement milestone now requires **15+ living survivors, every planned building, and an elected leader**. It is a milestone only; the game continues indefinitely.
- Save schema advanced to **7**, intended as the last deliberate Alpha reset before Beta save stability.

### Living Camp Day / Night & Chatter
- Kept the existing clock-driven camp darkness and made the cycle explicit as DAWN / DAY / DUSK / NIGHT, including dawn/dusk tinting plus fire, cabin, infirmary, and watch-post night glow.
- Added autonomous survivor chatter rendered as compact tactical-sound-style callouts over the living camp.
- Chatter is selected from real relationship values, personality, stress, shortages, expedition-duty policy, and opinion of the current coordinator/leader.
- Friendly/hostile/political chatter can make small relationship or stress changes; `FFCampSocial` selects them, `Game` applies consequences, and `FFCampView` remains presentation-only.

### Camp Politics / Events
- Formal leadership is no longer one-and-done. Weak elected leaders can now face recurring confidence votes against the strongest available challenger.
- Added communal-meal and shortage-politics camp events alongside the existing shelter, duty, ration, theft, fight, burnout, perimeter and personal-request events.
- Communal Table improves stress recovery and gives the camp a social gathering event hook.

### Final Building Tree
- Expanded the build tree from 8 to **15 planned structures**: Water Tank, Communal Table, Infirmary, Watch Post, Bunkhouse, Armory and Dormitory join the existing eight.
- Water Tank doubles Rain Catcher output; Infirmary speeds treatment/wound recovery and lowers untreated critical decline; Watch Post reduces camp-perimeter danger; Bunkhouse/Dormitory expand housing; Armory gates firearm construction.
- The living camp visually represents every final building using the existing tactical art language.

### Items / Crafting / Tactical Readability
- Every current `FFData.GEAR` item now has a crafting recipe in the existing Workbench/Sewing Table system; firearms are late-camp Workbench recipes requiring the Armory.
- Tactical HUD now exposes all five equipment slots—Weapon, Secondary, Tool, Clothing and Pack—so every equipped item is visible during field play.
- Explore encounters now place a **real named gear pickup** on the tactical board. The survivor must physically reach it and still escape alive to bring it home. Weapons/portable lights use authored atlas icons; Tool/Clothing/Pack finds use readable slot badges plus the real item name.
- Every current gear item belongs to a zone-tiered physical tactical loot pool, from common perimeter tools/packs through late Commercial/Industrial firearms.
- Added deterministic smoke coverage that every gear catalog entry has both a crafting path and a physical tactical loot path, final building count is complete, social chatter can resolve, and tactical equipment summaries expose all slots.

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
- Removed the active ZIP/patch/Base64 reconstruction chain from the repository tree; Git history retains the old packaging if historical inspection is ever necessary.
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
