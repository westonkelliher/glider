extends CanvasLayer
## Flight readout. Built in code so no scene edit is needed; the glider owns one
## of these and pushes values to it each physics frame. Top-left = pot/mode/binds
## (set_readout); top-right = labeled debug stats (set_stats).

const BINDS := "[binds]\n" \
	+ "pitch/roll: W A S D\n" \
	+ "yaw (pilot): Q E / LB RB\n" \
	+ "air roll (RL): Shift / LB\n" \
	+ "camera: right stick\n" \
	+ "tuning TEST/PLAY: T / Back\n" \
	+ "scheme RL/PILOT: C / Start\n" \
	+ "pause: Esc"

var _pot_label: Label
var _stats_label: Label


func _ready() -> void:
	_pot_label = Label.new()
	_pot_label.position = Vector2(12, 8)
	_pot_label.add_theme_font_size_override("font_size", 22)
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
	_pot_label.text = "pot height: %.1f m\ntuning: %s\nscheme: %s\n\n%s" \
		% [pot_height, tuning_name, scheme_name, BINDS]


## Render an ordered name->value map as "name: 0.0" lines, fixed to one decimal
## so on-screen numbers never change width/precision frame to frame.
func set_stats(stats: Dictionary) -> void:
	var lines := PackedStringArray()
	for name: String in stats:
		lines.append("%s: %.1f" % [name, stats[name]])
	_stats_label.text = "\n".join(lines)
