from pathlib import Path
def rep(path,a,b):
 p=Path(path); t=p.read_text(); assert a in t,(path,a[:100]); p.write_text(t.replace(a,b,1))
rep('game/scripts/FFCampView.gd','    if status == "Recovering":\n        return Vector2i(12, 6) if bool(Game.buildings.get("Cabin", false)) else SLEEP_CELL\n','''    if status == "Recovering":
        return Vector2i(12, 6) if bool(Game.buildings.get("Cabin", false)) else SLEEP_CELL
    var camp_activity: Dictionary = survivor.get("camp_activity", {})
    match str(camp_activity.get("kind", "")):
        "maintain_fire", "watch_fire", "guitar": return FIRE_CELL + Vector2i(0, 1)
        "cards": return building_cell("Communal Table") + Vector2i(0, -1) if bool(Game.buildings.get("Communal Table", false)) else FIRE_CELL + Vector2i(1, 1)
        "rest": return Vector2i(12, 6) if bool(Game.buildings.get("Cabin", false)) else SLEEP_CELL
        "wash": return building_cell("Water Tank") + Vector2i(1, 0) if bool(Game.buildings.get("Water Tank", false)) else building_cell("Rain Catcher") + Vector2i(1, 0)
''')
rep('game/scripts/FFCampView.gd','    draw_circle(center + Vector2(0, -tile * 0.03), tile * 0.16, Color(1.0, 0.34, 0.10, 0.88))\n    draw_circle(center + Vector2(0, -tile * 0.08), tile * 0.09, Color(1.0, 0.82, 0.28, 0.94))\n','    var fire_scale:=clampf(float(Game.fire_level)/100.0,0.10,1.0)\n    draw_circle(center+Vector2(0,-tile*0.03),tile*(0.07+0.12*fire_scale),Color(1.0,0.34,0.10,0.40+0.50*fire_scale))\n    draw_circle(center+Vector2(0,-tile*0.08),tile*(0.04+0.07*fire_scale),Color(1.0,0.82,0.28,0.48+0.48*fire_scale))\n')
rep('game/scripts/FFCampView.gd','    draw_circle(fire_center, tile * 2.25, Color(1.0, 0.36, 0.10, 0.055))\n    draw_circle(fire_center, tile * 1.55, Color(1.0, 0.48, 0.12, 0.085))\n    draw_circle(fire_center, tile * 0.90, Color(1.0, 0.68, 0.20, 0.14))\n','    var fire_strength:=clampf(float(Game.fire_level)/100.0,0.0,1.0)\n    draw_circle(fire_center,tile*(0.8+1.45*fire_strength),Color(1.0,0.36,0.10,0.055*fire_strength))\n    draw_circle(fire_center,tile*(0.6+0.95*fire_strength),Color(1.0,0.48,0.12,0.085*fire_strength))\n    draw_circle(fire_center,tile*(0.4+0.50*fire_strength),Color(1.0,0.68,0.20,0.14*fire_strength))\n')
rep('game/scripts/FFCampView.gd','        var activity := _activity_short(status)\n','        var activity := _activity_short(survivor)\n')
rep('game/scripts/FFCampView.gd','''func _activity_short(status: String) -> String:
    match status:
        "Crafting": return "CRAFT"
        "Building": return "BUILD"
        "Recovering": return "RECOVER"
        "Tending": return "GARDEN"
        _: return ""
''','''func _activity_short(survivor: Dictionary) -> String:
    var status:=str(survivor.get("status","Available"))
    match status:
        "Crafting": return "CRAFT"
        "Building": return "BUILD"
        "Recovering": return "RECOVER"
        "Tending": return "GARDEN"
    var a:Dictionary=survivor.get("camp_activity",{})
    match str(a.get("kind","")):
        "maintain_fire": return "FIRE"
        "watch_fire": return "WATCH FIRE"
        "cards": return "CARDS"
        "guitar": return "GUITAR"
        "rest": return "REST"
        "wash": return "WASH"
    return ""
''')
rep('game/scripts/FFSurvivorPanel.gd','var vitals_labels: Dictionary = {}\n','var vitals_labels: Dictionary = {}\nvar moodlet_labels: Dictionary = {}\n')
rep('game/scripts/FFSurvivorPanel.gd','    vitals_labels.clear()\n','    vitals_labels.clear()\n    moodlet_labels.clear()\n')
rep('game/scripts/FFSurvivorPanel.gd','    vitals_labels[sid] = vitals_label\n\n    var actions','    vitals_labels[sid] = vitals_label\n    var moodlet_label=_make_label("Mood: %s" % " • ".join(Game.survivor_moodlets(survivor)),11)\n    box.add_child(moodlet_label); moodlet_labels[sid]=moodlet_label\n\n    var actions')
rep('game/scripts/FFSurvivorPanel.gd','        if send_buttons.has(sid) and is_instance_valid(send_buttons[sid]):\n','        if moodlet_labels.has(sid) and is_instance_valid(moodlet_labels[sid]):\n            moodlet_labels[sid].text="Mood: %s" % " • ".join(Game.survivor_moodlets(survivor))\n        if send_buttons.has(sid) and is_instance_valid(send_buttons[sid]):\n')
rep('game/scripts/FFSurvivorPanel.gd','    if status == "Available":\n        return "At camp — available"\n','    if status == "Available":\n        var a:Dictionary=survivor.get("camp_activity",{})\n        if not a.is_empty(): return "At camp — %s" % str(a.get("label","available"))\n        return "At camp — available"\n')
rep('game/scripts/FFInspector.gd','const MobileScroll = preload("res://scripts/FFMobileScroll.gd")\n','const MobileScroll = preload("res://scripts/FFMobileScroll.gd")\nconst CampLifeRules = preload("res://scripts/FFCampLifeRules.gd")\n')
rep('game/scripts/FFInspector.gd','    body.add_child(_make_label("Fatigue %.0f / 100  •  Stress %.0f / 100" % [float(survivor.get("fatigue", 0.0)), float(survivor.get("stress", 0.0))], 14))\n','''    body.add_child(_make_label("Fatigue %.0f / 100  •  Stress %.0f / 100" % [float(survivor.get("fatigue", 0.0)), float(survivor.get("stress", 0.0))], 14))
    var needs:Dictionary=CampLifeRules.normalize_needs(survivor.get("needs",{}))
    body.add_child(_make_label("Hunger %.0f  •  Thirst %.0f  •  Sleep %.0f" % [float(needs["hunger"]),float(needs["thirst"]),float(needs["sleep"])],12))
    body.add_child(_make_label("Fun %.0f  •  Safety %.0f  •  Clean %.0f" % [float(needs["fun"]),float(needs["safety"]),float(needs["hygiene"])],12))
    body.add_child(_make_label("Moodlets: %s" % " • ".join(CampLifeRules.moodlets(needs)),13))
    var camp_activity:Dictionary=survivor.get("camp_activity",{})
    if status=="Available" and not camp_activity.is_empty(): body.add_child(_make_label("Now: %s" % str(camp_activity.get("label","At camp")),12))
''')
rep('game/scripts/ci/FFArchitectureSmoke.gd','    var rates := CampLifeRules.idle_recovery_rates(true, false)\n','''    var base_needs:=CampLifeRules.default_needs()
    if not _check(base_needs.has("hunger") and base_needs.has("thirst") and base_needs.has("sleep") and base_needs.has("fun") and base_needs.has("safety") and base_needs.has("hygiene"),"camp six-need model"): return
    var low_needs:=base_needs.duplicate(true); low_needs["hunger"]=30.0; low_needs["fun"]=25.0; low_needs["safety"]=20.0; low_needs["hygiene"]=20.0
    var moods:Array=CampLifeRules.moodlets(low_needs)
    if not _check(moods.has("Hungry") and moods.has("Bored") and moods.has("Afraid") and moods.has("Dirty"),"camp negative moodlets"): return
    if not _check(CampLifeRules.safety_target({"Noise Line":true,"Watch Post":true},2,3,70.0,false)>CampLifeRules.safety_target({},2,3,10.0,false),"camp safety reflects defenses and fire"): return
    var arng:=RandomNumberGenerator.new(); arng.seed=3
    if not _check(str(CampLifeRules.choose_available_activity(base_needs,10.0,2,2,false,false,arng).get("kind",""))=="maintain_fire","fire maintenance chore priority"): return
    var rates := CampLifeRules.idle_recovery_rates(true, false)
''')
rep('ARCHITECTURE.md','### `FFCampLifeRules.gd`\nCamp-life cadence, idle recovery, injury/treatment modifiers, defensive-building risk, rain-catcher output, and chatter timing.\n','### `FFCampLifeRules.gd`\nCamp-life cadence, six survivor needs/moodlets, autonomous downtime/chore selection, fire maintenance tuning, idle recovery, injury/treatment modifiers, defensive-building risk, rain-catcher output, and chatter timing.\n')
rep('README_CONTEXT.md','`FFCampLifeRules.gd` owns camp-life cadence/recovery tuning. The SURVIVORS roster now updates fatigue, stress, condition, activity and expedition countdowns in place on the regular simulation tick, without rebuilding the menu or requiring a tab change. Treatment remains simulation-owned:','`FFCampLifeRules.gd` owns camp-life cadence/recovery tuning plus six survivor needs: hunger, thirst, sleep, fun, safety, and hygiene. Needs produce visible moodlets and feed stress. Available survivors autonomously perform interruptible camp life such as maintaining the fire, resting, washing up, watching the fire, playing cards, or playing guitar while remaining available for player-assigned work. Fire maintenance consumes Wood only when completed, and fire strength affects camp safety and the living-camp glow. The SURVIVORS roster now updates fatigue, stress, condition, activity and expedition countdowns in place on the regular simulation tick, without rebuilding the menu or requiring a tab change. Treatment remains simulation-owned:')
rep('ROADMAP.md','- autonomous relationship/politics-based chatter in the living camp;\n','- autonomous relationship/politics-based chatter in the living camp;\n- survivor moodlets driven by hunger, thirst, sleep, fun, safety, and hygiene, with autonomous interruptible camp chores/leisure rather than manual routine scheduling;\n- fire maintenance as the first persistent camp chore, plus downtime such as watching the fire, cards, and guitar;\n')
p=Path('CHANGELOG.md'); t=p.read_text(); p.write_text('''## Beta Candidate — Camp Needs, Moodlets & Autonomous Downtime — 2026-09-11

- Added six persistent survivor needs: Hunger, Thirst, Sleep, Fun, Safety, and Hygiene. Sleep stays synchronized with existing Fatigue instead of creating a second exhaustion system.
- Added positive/negative moodlets; unmet needs add gradual stress pressure, while existing daily food/water upkeep feeds Hunger/Thirst without duplicating resource consumption.
- Added interruptible autonomous camp life for Available survivors: maintaining the fire, resting, washing up, watching the fire, playing cards, and playing guitar.
- Fire strength now persists, decays with camp time, affects safety and camp glow, and consumes 1 Wood when maintenance completes. Player work/expeditions always override autonomous activity.
- Survivor roster and inspector expose moodlets/needs and current autonomous activity. Existing schema-7 saves receive backward-compatible defaults; schema remains 7.

'''+t)
