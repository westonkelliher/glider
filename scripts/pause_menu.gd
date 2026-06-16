extends CanvasLayer
## Esc-toggled pause overlay. Owns its own pause state and mouse mode. Toggling
## tuning/controls is delegated to the glider it was given; the menu only reads
## back display strings to label its buttons.

var glider: Node # must expose toggle_tuning(), toggle_control(), menu_labels()

# Controls reference, shown only while paused. Controller-first; keyboard/mouse
# is the dimmed secondary line.
const BINDS := "[color=aqua][b]Fly[/b][/color]     L-stick pitch + turn · [color=yellow]LB[/color] air-roll (RL) · LB/RB yaw (Pilot)\n" \
	+ "[color=orange][b]Power[/b][/color]   B boost · X brake\n" \
	+ "[color=lime][b]Camera[/b][/color]  R-stick aim · R3 free · Y ball / velocity\n" \
	+ "[color=violet][b]System[/b][/color]  Start pause · Back reset · tuning/scheme in pause menu (T/C)\n" \
	+ "[color=#888888]K&M  WASD + Q/E · Shift air-roll · Space/RMB/LMB · mouse aim · F/Y · T/C · R reset · Esc[/color]"

var is_open := false
var _root: Control
var _tuning_btn: Button
var _control_btn: Button
# Stage-select section, populated lazily the first time the menu opens inside a
# tutorial (the TutorialManager isn't built yet when this menu is constructed).
var _stage_box: VBoxContainer
var _stages_built := false


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS # clickable / toggleable while paused
	_build()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP # eat clicks behind the menu
	_root.visible = false
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_tuning_btn = _make_button("")
	_tuning_btn.pressed.connect(_on_tuning_pressed)
	vbox.add_child(_tuning_btn)

	_control_btn = _make_button("")
	_control_btn.pressed.connect(_on_control_pressed)
	vbox.add_child(_control_btn)

	# Tutorial-only stage jump buttons (filled in on first open if applicable).
	_stage_box = VBoxContainer.new()
	_stage_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_stage_box.add_theme_constant_override("separation", 6)
	vbox.add_child(_stage_box)

	var resume := _make_button("Resume")
	resume.pressed.connect(close)
	vbox.add_child(resume)

	var to_menu := _make_button("Quit to Main Menu")
	to_menu.pressed.connect(_on_quit_to_menu)
	vbox.add_child(to_menu)

	# Controls reference, only visible while the menu is up.
	var binds := RichTextLabel.new()
	binds.bbcode_enabled = true
	binds.fit_content = true
	binds.scroll_active = false
	binds.autowrap_mode = TextServer.AUTOWRAP_OFF
	binds.custom_minimum_size = Vector2(880, 0)
	binds.add_theme_font_size_override("normal_font_size", 20)
	binds.add_theme_font_size_override("bold_font_size", 20)
	binds.text = BINDS
	vbox.add_child(binds)

	refresh_labels()


# Big menu button, matching the title-screen look.
func _make_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(360.0, 56.0)
	b.add_theme_font_size_override("font_size", 28)
	return b


func _unhandled_input(event: InputEvent) -> void:
	# Start button or Esc (the "pause" action) toggles the menu.
	if event.is_action_pressed("pause"):
		toggle()


func toggle() -> void:
	if is_open: close()
	else: open()


func open() -> void:
	is_open = true
	_ensure_stage_select()
	_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_tuning_btn.grab_focus()  # so gamepad / keyboard can navigate immediately


# Build a "Jump to stage" list the first time we open inside a tutorial. A plain
# match has no TutorialManager, so this stays empty there.
func _ensure_stage_select() -> void:
	if _stages_built:
		return
	var mgr: Node = get_tree().get_first_node_in_group("tutorial_manager")
	if mgr == null or not mgr.has_method("stage_titles"):
		return
	_stages_built = true
	var header := Label.new()
	header.text = "Jump to stage"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	_stage_box.add_child(header)
	var titles: Array = mgr.stage_titles()
	for i in titles.size():
		var b := Button.new()
		b.text = "%d. %s" % [i + 1, titles[i]]
		b.custom_minimum_size = Vector2(360.0, 38.0)
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(_on_stage_pressed.bind(i))
		_stage_box.add_child(b)


func _on_stage_pressed(index: int) -> void:
	var mgr: Node = get_tree().get_first_node_in_group("tutorial_manager")
	if mgr and mgr.has_method("jump_to_stage"):
		mgr.jump_to_stage(index)
	close()


func close() -> void:
	is_open = false
	_root.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_quit_to_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func refresh_labels() -> void:
	var labels: Dictionary = glider.menu_labels()
	_tuning_btn.text = "Tuning: %s" % labels["tuning"]
	_control_btn.text = "Controls: %s" % labels["control"]


func _on_tuning_pressed() -> void:
	glider.toggle_tuning()
	refresh_labels()


func _on_control_pressed() -> void:
	glider.toggle_control()
	refresh_labels()
