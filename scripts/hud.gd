extends CanvasLayer
## Top-left flight readout. Built in code so no scene edit is needed; the glider
## owns one of these and pushes values to it each physics frame via set_readout().

const BINDS := "[binds]\n" \
	+ "pitch/roll: W A S D\n" \
	+ "yaw (pilot): Q E / LB RB\n" \
	+ "air roll (RL): Shift / LB\n" \
	+ "camera: right stick\n" \
	+ "tuning TEST/PLAY: T / Back\n" \
	+ "scheme RL/PILOT: C / Start\n" \
	+ "pause: Esc"

var _pot_label: Label


func _ready() -> void:
	_pot_label = Label.new()
	_pot_label.position = Vector2(12, 8)
	_pot_label.add_theme_font_size_override("font_size", 22)
	add_child(_pot_label)


func set_readout(pot_height: float, tuning_name: String, scheme_name: String) -> void:
	_pot_label.text = "pot height: %.1f m\ntuning: %s\nscheme: %s\n\n%s" \
		% [pot_height, tuning_name, scheme_name, BINDS]
