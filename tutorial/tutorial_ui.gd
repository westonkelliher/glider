class_name TutorialUI
extends CanvasLayer
## All tutorial HUD: header + objective + hint at top, a timer top-right, an
## intro panel, and a centre banner for stage-complete medals. Stages call the
## set_* methods; the manager drives intro()/banner().

var _header: Label = null
var _objective: Label = null
var _hint: Label = null
var _timer: Label = null

var _intro_panel: PanelContainer = null
var _intro_title: Label = null
var _intro_body: Label = null
var _intro_showing: bool = false

var _banner: PanelContainer = null
var _banner_label: Label = null

signal restart_requested
signal skip_requested


func _ready() -> void:
	layer = 10
	_build()


func _make_label(font_size: int, color: Color) -> Label:
	var l: Label = Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	return l


func _build() -> void:
	# Top-centre stack: header / objective / hint
	var top: VBoxContainer = VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.anchor_left = 0.5
	top.anchor_right = 0.5
	top.offset_left = -480.0
	top.offset_right = 480.0
	top.offset_top = 24.0
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(top)

	_header = _make_label(40, Color(0.55, 0.85, 1.0))
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_header)

	_objective = _make_label(26, Color(1, 1, 1))
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(_objective)

	_hint = _make_label(20, Color(0.8, 0.85, 0.5))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(_hint)

	# Timer top-right
	_timer = _make_label(34, Color(1, 1, 1))
	_timer.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_timer.anchor_left = 1.0
	_timer.anchor_right = 1.0
	_timer.offset_left = -260.0
	_timer.offset_right = -24.0
	_timer.offset_top = 24.0
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_timer.visible = false
	add_child(_timer)

	_build_intro()
	_build_banner()
	_build_buttons()


func _make_button(text: String) -> Button:
	var b: Button = Button.new()
	b.text = text
	# No keyboard focus: a focused button would swallow the Space / A used to
	# advance stages. Mouse-click only.
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 22)
	b.custom_minimum_size = Vector2(150.0, 48.0)
	return b


func _build_buttons() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	row.anchor_left = 1.0
	row.anchor_top = 1.0
	row.anchor_right = 1.0
	row.anchor_bottom = 1.0
	row.offset_left = -330.0
	row.offset_top = -72.0
	row.offset_right = -24.0
	row.offset_bottom = -24.0
	row.add_theme_constant_override("separation", 12)
	add_child(row)

	var restart: Button = _make_button("↺ Restart")
	restart.pressed.connect(func() -> void: restart_requested.emit())
	row.add_child(restart)

	var skip: Button = _make_button("Skip ▶")
	skip.pressed.connect(func() -> void: skip_requested.emit())
	row.add_child(skip)


func _build_intro() -> void:
	_intro_panel = PanelContainer.new()
	_intro_panel.set_anchors_preset(Control.PRESET_CENTER)
	_intro_panel.anchor_left = 0.5
	_intro_panel.anchor_right = 0.5
	_intro_panel.anchor_top = 0.5
	_intro_panel.anchor_bottom = 0.5
	_intro_panel.offset_left = -440.0
	_intro_panel.offset_right = 440.0
	_intro_panel.offset_top = -200.0
	_intro_panel.offset_bottom = 200.0
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.06, 0.1, 0.92)
	sb.border_color = Color(0.4, 0.7, 1.0, 0.9)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(34.0)
	_intro_panel.add_theme_stylebox_override("panel", sb)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	_intro_panel.add_child(box)

	_intro_title = _make_label(44, Color(0.6, 0.9, 1.0))
	_intro_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_intro_title)

	_intro_body = _make_label(26, Color(0.95, 0.95, 0.95))
	_intro_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_intro_body)

	var go: Label = _make_label(22, Color(0.85, 0.85, 0.55))
	go.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	go.text = "[ Space / A to begin ]"
	box.add_child(go)

	_intro_panel.visible = false
	add_child(_intro_panel)


func _build_banner() -> void:
	_banner = PanelContainer.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.anchor_left = 0.5
	_banner.anchor_right = 0.5
	_banner.anchor_top = 0.5
	_banner.anchor_bottom = 0.5
	_banner.offset_left = -420.0
	_banner.offset_right = 420.0
	_banner.offset_top = -90.0
	_banner.offset_bottom = 90.0
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.08, 0.9)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(24.0)
	_banner.add_theme_stylebox_override("panel", sb)
	_banner_label = _make_label(46, Color(1, 1, 1))
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.add_child(_banner_label)
	_banner.visible = false
	add_child(_banner)


# ---- Stage-facing API ----

func set_header(text: String) -> void:
	_header.text = text

func set_objective(text: String) -> void:
	_objective.text = text

func set_hint(text: String) -> void:
	_hint.text = text

## Show a timer readout. Pass a negative value to hide it.
func set_timer(seconds: float) -> void:
	if seconds < 0.0:
		_timer.visible = false
		return
	_timer.visible = true
	var mins: int = int(seconds) / 60
	var secs: float = seconds - float(mins * 60)
	_timer.text = "%d:%05.2f" % [mins, secs]


# ---- Manager-facing API ----

func intro(title: String, lines: Array[String]) -> void:
	_intro_title.text = title
	_intro_body.text = "\n".join(lines)
	_intro_panel.visible = true
	_intro_showing = true

func intro_showing() -> bool:
	return _intro_showing

func dismiss_intro() -> void:
	_intro_panel.visible = false
	_intro_showing = false

func banner(text: String, color: Color) -> void:
	_banner_label.text = text
	_banner_label.add_theme_color_override("font_color", color)
	_banner.visible = true

func clear_banner() -> void:
	_banner.visible = false
