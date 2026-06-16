extends CanvasLayer
## Flight readout. Built in code so no scene edit is needed; the glider owns one
## of these and pushes values to it each physics frame. Top-left = pot/mode/binds
## (set_readout); top-right = labeled debug stats (set_stats).

# Controller-first; keyboard/mouse is the dimmed secondary line.
const BINDS := "[color=aqua][b]Fly[/b][/color]     L-stick pitch + turn · [color=yellow]LB[/color] air-roll (RL) · LB/RB yaw (Pilot)\n" \
	+ "[color=orange][b]Power[/b][/color]   A launch · B boost · X brake\n" \
	+ "[color=lime][b]Camera[/b][/color]  R-stick aim · R3 free · Y ball / velocity\n" \
	+ "[color=violet][b]Modes[/b][/color]   Back tuning · Start scheme\n" \
	+ "[color=#888888]K&M  WASD + Q/E · Shift air-roll · Space/RMB/LMB · mouse aim · F/Y · T/C · Esc[/color]"

var _pot_label: RichTextLabel
var _stats_label: Label
var _boost_bar: ProgressBar
var _boost_caption: Label


func _ready() -> void:
	_pot_label = RichTextLabel.new()
	_pot_label.bbcode_enabled = true
	_pot_label.fit_content = true
	_pot_label.scroll_active = false
	_pot_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_pot_label.position = Vector2(12, 8)
	_pot_label.custom_minimum_size = Vector2(880, 0)
	_pot_label.add_theme_font_size_override("normal_font_size", 22)
	_pot_label.add_theme_font_size_override("bold_font_size", 22)
	_pot_label.add_theme_stylebox_override("normal", _panel_bg())
	add_child(_pot_label)

	# Top-right, right-aligned so the fixed-decimal values stay pinned to the
	# edge and don't drift as digits change.
	_stats_label = Label.new()
	_stats_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_stats_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_stats_label.offset_top = 8
	_stats_label.offset_right = -12
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stats_label.add_theme_font_size_override("font_size", 18)
	add_child(_stats_label)

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


func set_readout(pot_height: float, tuning_name: String, scheme_name: String) -> void:
	_pot_label.text = "[b]pot height:[/b] %.1f m   [b]tuning:[/b] %s   [b]scheme:[/b] %s\n\n%s" \
		% [pot_height, tuning_name, scheme_name, BINDS]


## Render an ordered name->value map as "name: 0.0" lines, fixed to one decimal
## so on-screen numbers never change width/precision frame to frame.
func set_stats(stats: Dictionary) -> void:
	var lines := PackedStringArray()
	for name: String in stats:
		lines.append("%s: %.1f" % [name, stats[name]])
	_stats_label.text = "\n".join(lines)
