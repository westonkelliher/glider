extends CanvasLayer
## Flight readout. Built in code so no scene edit is needed; the glider owns one
## of these and pushes values to it each physics frame. Top-center = scoreboard
## (set_score); bottom-center = boost gauge. Controls live in the pause menu.

const BLUE := Color(0.16, 0.45, 0.95)
const ORANGE := Color(1.0, 0.5, 0.12)

var _blue_score: Label
var _orange_score: Label
var _boost_bar: ProgressBar
var _boost_caption: Label


func _ready() -> void:
	# Scoreboard, top-center: two angled team boxes meeting at the middle,
	# blue on the left and orange on the right (Rocket League style).
	_blue_score = _make_score_box(BLUE, true)
	_blue_score.offset_left = -82.0
	_blue_score.offset_right = -1.0
	add_child(_blue_score)

	_orange_score = _make_score_box(ORANGE, false)
	_orange_score.offset_left = 1.0
	_orange_score.offset_right = 82.0
	add_child(_orange_score)

	set_score(0, 0)


# One team's score box: a saturated team-colored panel with a big white number.
func _make_score_box(team: Color, left_side: bool) -> Label:
	var lbl := Label.new()
	lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	lbl.offset_top = 12.0
	lbl.offset_bottom = 60.0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.add_theme_stylebox_override("normal", _score_box_bg(team, left_side))
	return lbl


# Team-colored box: rounded on the outer corner, square where the two boxes meet.
func _score_box_bg(team: Color, left_side: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = team
	sb.border_color = team.lightened(0.25)
	sb.set_border_width_all(2)
	var r := 9
	if left_side:
		sb.corner_radius_top_left = r
		sb.corner_radius_bottom_left = r
	else:
		sb.corner_radius_top_right = r
		sb.corner_radius_bottom_right = r
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 6
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 6
	return sb

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
	if not _blue_score:
		return
	_blue_score.text = str(blue)
	_orange_score.text = str(orange)
