extends Control
## Title screen. Pick a mode: a full match against the AI, or the tutorial
## sequence. Builds its own UI so the scene file stays tiny.

const MATCH_SCENE: String = "res://scenes/main.tscn"
const TUTORIAL_SCENE: String = "res://tutorial/tutorial.tscn"


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.07, 0.11)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var col: VBoxContainer = VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER)
	col.anchor_left = 0.5
	col.anchor_right = 0.5
	col.anchor_top = 0.5
	col.anchor_bottom = 0.5
	col.offset_left = -200.0
	col.offset_right = 200.0
	col.offset_top = -160.0
	col.offset_bottom = 160.0
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 22)
	add_child(col)

	var title: Label = Label.new()
	title.text = "GLIDER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 96)
	title.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	col.add_child(title)

	var play: Button = _make_button("Play vs AI")
	play.pressed.connect(_on_play)
	col.add_child(play)
	play.grab_focus()  # so gamepad / keyboard can confirm immediately

	var tut: Button = _make_button("Tutorials")
	tut.pressed.connect(_on_tutorials)
	col.add_child(tut)

	var quit: Button = _make_button("Quit")
	quit.pressed.connect(_on_quit)
	col.add_child(quit)


func _make_button(text: String) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(360.0, 64.0)
	b.add_theme_font_size_override("font_size", 32)
	return b


func _on_play() -> void:
	get_tree().change_scene_to_file(MATCH_SCENE)


func _on_tutorials() -> void:
	get_tree().change_scene_to_file(TUTORIAL_SCENE)


func _on_quit() -> void:
	get_tree().quit()
