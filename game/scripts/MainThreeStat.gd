extends "res://scripts/Main.gd"

const CombatThree = preload("res://scripts/FFCombatThreeStat.gd")
const InspectorThree = preload("res://scripts/FFInspectorThreeStat.gd")

func _build_inspector_overlay():
    inspector_overlay = InspectorThree.new()
    inspector_overlay.send_survivor.connect(_on_inspector_send)
    add_child(inspector_overlay)

func _build_combat_overlay():
    combat_overlay = CombatThree.new()
    combat_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    combat_overlay.visible = false
    combat_overlay.encounter_finished.connect(_on_combat_finished)
    add_child(combat_overlay)
