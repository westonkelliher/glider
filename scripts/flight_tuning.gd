class_name FlightTuning
extends Resource
## A named set of flight-feel constants. TEST = gentle accelerations (forces easy
## to see), PLAY = snappy. Exported so presets can be authored as .tres in the
## inspector; the static factories below are the in-code defaults.

@export var display_name := "TEST"

## Ailerons — how fast a surface eases toward target (1/s) and craft turn
## authority per unit of deflection.
# aileron speed
@export var ail_pitch_speed := 3.0
@export var ail_roll_speed := 3.0
@export var ail_yaw_speed := 2.0
# max rotation speeds
@export var pitch_mult := 4.5
@export var roll_mult := 4.5
@export var yaw_mult := 3.5

## Pot-height energy model.
@export var pot_speed_catchup_mult := 4.0
@export var pot_dir_catchup_mult := 0.2
@export var drag := 0.5 


static func test() -> FlightTuning:
	return FlightTuning.new() # defaults above are the TEST preset


static func play() -> FlightTuning:
	var t := FlightTuning.new()
	t.display_name = "PLAY"
	# aileron speeds
	t.ail_pitch_speed = 12.0
	t.ail_roll_speed = 10.0
	t.ail_yaw_speed = 12.0
	# max rotation speeds
	t.pitch_mult = 6.0
	t.roll_mult = 7.0
	t. yaw_mult = 4.5
	t.pot_speed_catchup_mult = 4.0
	t.pot_dir_catchup_mult = 0.25
	t.drag = 0.2
	return t
