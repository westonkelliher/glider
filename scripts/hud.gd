extends CanvasLayer
## Flight readout. Built in code so no scene edit is needed; the glider owns one
## of these and pushes values to it each physics frame. Top-center = scoreboard
## (set_score); bottom-center = boost gauge. Controls live in the pause menu.

var _score_label: Label
var _boost_bar: ProgressBar
var _boost_caption: Label


func _ready() -> void:
	# Scoreboard, top-center.
	_score_label = Label.new()
	_score_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_score_label.offset_left = -200.0
	_score_label.offset_right = 200.0
	_score_label.offset_top = 12.0
	_score_label.offset_bottom = 52.0
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.add_theme_font_size_override("font_size", 28)
	_score_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_score_label.add_theme_constant_override("outline_size", 8)
	_score_label.add_theme_stylebox_override("normal", _panel_bg())
	add_child(_score_label)
	set_score(0, 0)

	# Boost reserve meter, bottom-center.
	_boost_bar = ProgressBar.new()
	_boost_bar.show_percentage = false
	_boost_bar.min_value = 0.0
	_boost_bar.max_value = 1.0
	_boost_bar.value = 1.0
	_boost_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_boost_bar.offset_left = -140.0
	_boost_bar.offset_right = 140.0
	_boost_bar.offset_top = -52.0
	_boost_bar.offset_bottom = -32.0
	_boost_bar.add_theme_stylebox_override("background", _boost_bg())
	_boost_bar.add_theme_stylebox_override("fill", _boost_fill())
	add_child(_boost_bar)

	_boost_caption = Label.new()
	_boost_caption.text = "BOOST"
	_boost_caption.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_boost_caption.offset_left = -140.0
	_boost_caption.offset_right = 140.0
	_boost_caption.offset_top = -74.0
	_boost_caption.offset_bottom = -54.0
	_boost_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boost_caption.add_theme_font_size_override("font_size", 14)
	_boost_caption.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	add_child(_boost_caption)


# Dark rounded panel behind the readout, with padding so text isn't flush.
func _panel_bg() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.55)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_left = 12
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 10
	return sb


func _boost_bg() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.55)
	sb.set_corner_radius_all(5)
	sb.set_border_width_all(2)
	sb.border_color = Color(1.0, 0.7, 0.3, 0.5)
	return sb


func _boost_fill() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.55, 0.12, 0.95)
	sb.set_corner_radius_all(5)
	return sb


## Boost reserve in [0, max] -> fills the bottom bar; dims while empty.
func set_boost(amount: float, max_amount: float) -> void:
	if not _boost_bar:
		return
	_boost_bar.value = amount / max_amount if max_amount > 0.0 else 0.0
	_boost_bar.modulate = Color(1, 1, 1, 1) if amount > 0.01 else Color(1, 1, 1, 0.4)


## Update the top-center scoreboard.
func set_score(blue: int, orange: int) -> void:
	if not _score_label:
		return
	_score_label.text = "BLUE  %d  -  %d  ORANGE" % [blue, orange]
