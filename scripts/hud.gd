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


func _ready() -> void:
	_pot_label = RichTextLabel.new()
	_pot_label.bbcode_enabled = true
	_pot_label.fit_content = true
	_pot_label.scroll_active = false
	_pot_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_pot_label.position = Vector2(12, 8)
	_pot_label.custom_minimum_size = Vector2(680, 0)
	_pot_label.add_theme_font_size_override("normal_font_size", 18)
	_pot_label.add_theme_font_size_override("bold_font_size", 18)
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
