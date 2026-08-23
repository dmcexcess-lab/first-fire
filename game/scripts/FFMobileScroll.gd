extends RefCounted
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
