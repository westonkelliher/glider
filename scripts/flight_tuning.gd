class_name FlightTuning
extends Resource
## A named set of flight-feel constants. TEST = gentle accelerations (forces easy
## to see), PLAY = snappy. Exported so presets can be authored as .tres in the
## inspector; the static factories below are the in-code defaults.

@export var DISPLAY_NAME := "TEST"

## Ailerons — how fast a surface eases toward target (1/s) and craft turn
## authority per unit of deflection.
# aileron speed
@export var AIL_PITCH_SPEED := 3.0
@export var AIL_ROLL_SPEED := 3.0
@export var AIL_YAW_SPEED := 2.0
# max rotation speeds
@export var PITCH_MULT := 4.5
@export var ROLL_MULT := 4.5
@export var YAW_MULT := 3.5

## Pot-height energy model.
@export var POT_SPEED_CATCHUP_MULT := 4.0
@export var POT_DIR_CATCHUP_MULT := 0.2
@export var DRAG := 0.5 

#
@export var NOSE_PULL_MULT := 0.2


static func test() -> FlightTuning:
	return FlightTuning.new() # defaults above are the TEST preset


static func play() -> FlightTuning:
	var t := FlightTuning.new()
	t.DISPLAY_NAME = "PLAY"
	# aileron speeds
	t.AIL_PITCH_SPEED = 12.0
	t.AIL_ROLL_SPEED = 10.0
	t.AIL_YAW_SPEED = 12.0
	# max rotation speeds
	t.PITCH_MULT = 6.0
	t.ROLL_MULT = 7.0
	t.YAW_MULT = 4.5
	t.POT_SPEED_CATCHUP_MULT = 4.0
	t.POT_DIR_CATCHUP_MULT = 0.25
	t.DRAG = 0.2
	return t
