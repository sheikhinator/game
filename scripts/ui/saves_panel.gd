class_name SavesPanel
extends ScrollContainer
## List of the 15 save slots. In save mode tapping writes; in load mode tapping loads.

signal saved(slot: int)

var save_mode := false
var _list: VBoxContainer


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	add_child(_list)
	refresh()


func refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	for i in Game.SAVE_SLOTS:
		var desc := Game.describe_save(i)
		var empty := desc == "Empty slot"
		var b := UIKit.menu_button("  %02d   %s" % [i + 1, desc], 30, 80)
		b.disabled = (not save_mode) and empty
		b.pressed.connect(_on_slot.bind(i))
		_list.add_child(b)


func _on_slot(i: int) -> void:
	if save_mode:
		if Game.save_game(i):
			refresh()
			saved.emit(i)
	else:
		Game.load_game(i)
