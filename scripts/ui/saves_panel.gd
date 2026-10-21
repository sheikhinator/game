class_name SavesPanel
extends ScrollContainer
## The 15 save slots as cards. Save mode writes the tapped slot; load mode loads it.

signal saved(slot: int)

var save_mode := false
var _list: VBoxContainer


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_right", 24)
	add_child(margin)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	margin.add_child(_list)
	refresh()


func refresh() -> void:
	if _list == null:
		return
	for c in _list.get_children():
		c.queue_free()
	for i in Game.SAVE_SLOTS:
		_list.add_child(_card(i))


func _card(i: int) -> Control:
	var info := Game.read_save(i)
	var empty := info.is_empty()
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 104)
	b.disabled = empty and not save_mode
	var rest := UIKit.box(Color(1, 1, 1, 0.04), 6)
	var hot := UIKit.box(Color(1, 1, 1, 0.1), 6)
	hot.border_width_left = 5
	hot.border_color = UIKit.ACCENT
	b.add_theme_stylebox_override("normal", rest)
	b.add_theme_stylebox_override("hover", hot)
	b.add_theme_stylebox_override("pressed", hot)
	b.add_theme_stylebox_override("disabled", UIKit.box(Color(1, 1, 1, 0.02), 6))
	var h := HBoxContainer.new()
	UIKit.full_rect(h)
	h.offset_left = 30
	h.offset_right = -30
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 30)
	b.add_child(h)
	var num := UIKit.label("%02d" % (i + 1), 44, UIKit.ACCENT if not empty else UIKit.FAINT, true, 500, 2)
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.custom_minimum_size = Vector2(70, 0)
	h.add_child(num)
	var texts := VBoxContainer.new()
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(texts)
	if empty:
		texts.add_child(UIKit.label("Empty slot" if not save_mode else "Empty slot  ·  tap to save here", 28, UIKit.SUB))
	else:
		var s: Dictionary = info.state
		texts.add_child(UIKit.label("Port Calder  ·  Day %d, %s" % [int(s.day), Game.clock_string(float(s.time_of_day))], 30, UIKit.INK, false, 600))
		texts.add_child(UIKit.label("Saved %s" % str(info.saved_at).replace("T", "  ").left(17), 22, UIKit.SUB))
		var cash := UIKit.label("$" + Game.format_money(int(s.money)), 36, UIKit.MONEY, true, 600, 1)
		cash.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(cash)
	for c in h.find_children("*", "Control", true, false):
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.pressed.connect(_on_slot.bind(i))
	return b


func _on_slot(i: int) -> void:
	if save_mode:
		if Game.save_game(i):
			refresh()
			saved.emit(i)
	else:
		Game.load_game(i)
