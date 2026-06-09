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
@export var AIL_ROLL_SPEED := 3.5
@export var AIL_YAW_SPEED := 2.0
# aileron acc
@export var AIL_ACC := 0.15 # dont go to 0 even though we interp
@export var AIL_DAMP_ZONES_SIZE := 0.4 # as a fraction of total aileron range (for each zone)
# max rotation speeds
@export var PITCH_MULT := 4.5
@export var ROLL_MULT := 5.5
@export var YAW_MULT := 3.5

## Pot-height energy model.
@export var POT_SPEED_CATCHUP_MULT := 0.8
@export var POT_DIR_CATCHUP_MULT := 0.1
@export var DRAG := 0.3

#
@export var NOSE_PULL_MULT := 2.0

## Heavy dive (hold heavy) — full-ballistic altitude-to-speed conversion.
@export var MAX_SPEED := 30.0
@export var HEAVY_GRAV_MULT := 2.4
@export var HEAVY_MAX_SPEED := 48.0 # pot-speed cap during the post-release grace
# release boost — pop applied the frame the dive ends
@export var RELEASE_BOOST_RATIO := 0.12
@export var RELEASE_BOOST_FLAT := 1.5
@export var RELEASE_LIFT := 2.5


static func test() -> FlightTuning:
	return FlightTuning.new() # defaults above are the TEST preset


static func play() -> FlightTuning:
	var t := FlightTuning.new()
	t.DISPLAY_NAME = "PLAY"
	# aileron speeds
	t.AIL_PITCH_SPEED = 8.0
	t.AIL_ROLL_SPEED = 7.0
	t.AIL_YAW_SPEED = 4.0
	t.AIL_DAMP_ZONES_SIZE = 0.5
	t.AIL_ACC = 2.0
	# max rotation speeds
	t.PITCH_MULT = 4.5
	t.ROLL_MULT = 5.5
	t.YAW_MULT = 3.5
	t.POT_SPEED_CATCHUP_MULT = 1.5
	t.POT_DIR_CATCHUP_MULT = 0.2
	t.DRAG = 0.2
	# heavy dive — punchier than TEST
	t.MAX_SPEED = 32.0
	t.HEAVY_GRAV_MULT = 2.6
	t.HEAVY_MAX_SPEED = 52.0
	t.RELEASE_BOOST_RATIO = 0.14
	t.RELEASE_BOOST_FLAT = 2.0
	t.RELEASE_LIFT = 3.0
	return t
