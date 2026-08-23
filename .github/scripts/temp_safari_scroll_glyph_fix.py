from pathlib import Path

ROOT = Path('.')


def replace_once(path: str, old: str, new: str) -> None:
    p = ROOT / path
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected exactly one match, found {count}: {old!r}')
    p.write_text(text.replace(old, new, 1))


mobile_scroll = '''extends RefCounted
class_name FFMobileScroll

# Global touch-to-mouse emulation stays disabled because tactical combat owns
# touch separately. Scrollbars therefore get their own narrow touch adapter.
const TOUCH_BAR_WIDTH := 30.0
const TOUCH_DEADZONE := 6

static func configure(scroll: ScrollContainer) -> void:
    scroll.scroll_deadzone = TOUCH_DEADZONE
    var bar: VScrollBar = scroll.get_v_scroll_bar()
    bar.custom_minimum_size.x = TOUCH_BAR_WIDTH
    if bool(bar.get_meta("ff_mobile_scroll_configured", false)):
        return
    bar.set_meta("ff_mobile_scroll_configured", true)
    bar.gui_input.connect(func(event): _handle_bar_input(scroll, bar, event))

static func touch_scroll_value(touch_y: float, track_height: float, min_value: float, max_value: float, page: float) -> int:
    var height := maxf(1.0, track_height)
    var last_value := maxf(min_value, max_value - page)
    var ratio := clampf(touch_y / height, 0.0, 1.0)
    return int(round(lerpf(min_value, last_value, ratio)))

static func _handle_bar_input(scroll: ScrollContainer, bar: VScrollBar, event: InputEvent) -> void:
    var touch_y := -1.0
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if not touch.pressed:
            return
        touch_y = touch.position.y
    elif event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        touch_y = drag.position.y
    else:
        return
    scroll.scroll_vertical = touch_scroll_value(touch_y, bar.size.y, bar.min_value, bar.max_value, bar.page)
    bar.accept_event()
'''
(ROOT / 'game/scripts/FFMobileScroll.gd').write_text(mobile_scroll)

replace_once(
    'game/scripts/Main.gd',
    'const CampView = preload("res://scripts/FFCampView.gd")\n',
    'const CampView = preload("res://scripts/FFCampView.gd")\nconst MobileScroll = preload("res://scripts/FFMobileScroll.gd")\n',
)
replace_once(
    'game/scripts/Main.gd',
    '    content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED\n    content_scroll.clip_contents = true\n',
    '    content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED\n    content_scroll.clip_contents = true\n    MobileScroll.configure(content_scroll)\n',
)
replace_once(
    'game/scripts/Main.gd',
    '    previous.text = "◀"\n    previous.custom_minimum_size = Vector2(54, 48)\n',
    '    previous.text = "PREV"\n    previous.custom_minimum_size = Vector2(64, 48)\n',
)
replace_once(
    'game/scripts/Main.gd',
    '    next.text = "▶"\n    next.custom_minimum_size = Vector2(54, 48)\n',
    '    next.text = "NEXT"\n    next.custom_minimum_size = Vector2(64, 48)\n',
)

replace_once(
    'game/scripts/FFInspector.gd',
    'const D = preload("res://scripts/FFData.gd")\n',
    'const D = preload("res://scripts/FFData.gd")\nconst MobileScroll = preload("res://scripts/FFMobileScroll.gd")\n',
)
replace_once(
    'game/scripts/FFInspector.gd',
    '    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED\n    body = VBoxContainer.new()\n',
    '    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED\n    MobileScroll.configure(scroll)\n    body = VBoxContainer.new()\n',
)

replace_once(
    'game/scripts/ci/FFArchitectureSmoke.gd',
    'const TacticalVisuals = preload("res://scripts/FFTacticalVisuals.gd")\n',
    'const TacticalVisuals = preload("res://scripts/FFTacticalVisuals.gd")\nconst MobileScroll = preload("res://scripts/FFMobileScroll.gd")\n',
)
replace_once(
    'game/scripts/ci/FFArchitectureSmoke.gd',
    '    if not _check(CampSocial.relationship_label(70) == "Close", "social relationship bands"): return\n',
    '    if not _check(CampSocial.relationship_label(70) == "Close", "social relationship bands"): return\n    if not _check(MobileScroll.TOUCH_BAR_WIDTH >= 28.0, "mobile scrollbar touch target"): return\n    if not _check(MobileScroll.touch_scroll_value(50.0, 100.0, 0.0, 100.0, 20.0) == 40, "mobile scrollbar touch mapping"): return\n',
)

changelog = ROOT / 'CHANGELOG.md'
text = changelog.read_text()
marker = 'This file tracks player-facing changes to the playable Alpha builds, plus major technical changes that affect development/reliability.\n\n'
if marker not in text:
    raise SystemExit('CHANGELOG insertion marker missing')
entry = '''## Beta Candidate — Safari Scroll & Font-Safe Controls — 2026-08-22

### Mobile / Safari Scrolling
- Main Camp/Craft/Build/Survivor content and the survivor/inventory inspector now share a dedicated touch-scroll adapter instead of depending on mouse emulation for the scrollbar thumb.
- Vertical scrollbars use a wider 30 px touch target and respond directly to `InputEventScreenTouch` / `InputEventScreenDrag`, which keeps tactical touch-to-mouse emulation disabled and avoids reintroducing combat double-input risk.
- Added deterministic architecture smoke coverage for the touch target and scrollbar position mapping.

### Missing-Glyph Controls
- Replaced the worker picker's Unicode triangle pseudo-icons with font-safe `PREV` / `NEXT` buttons. The triangles could render as the default font's missing-character box on Web and desktop builds.
- Tactical/camp atlas mappings were inspected during this pass; authored environment prop kinds already map to real atlas regions, so the visible missing-character-style boxes were treated as font glyphs rather than missing sprite assets.
- Save schema remains **7**.

'''
changelog.write_text(text.replace(marker, marker + entry, 1))

# The workflow commits the actual source changes, not this patch helper.
Path('.github/scripts/temp_safari_scroll_glyph_fix.py').unlink()
print('FIRST_FIRE_SAFARI_SCROLL_GLYPH_FIX_OK')
