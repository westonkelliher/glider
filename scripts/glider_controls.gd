class_name GliderControls
extends RefCounted
## Source-agnostic control sample for a glider. Filled by a controller
## (human input or AI) and consumed by the flight model in glider_body.gd.

var targets := Vector3.ZERO  # (pitch, roll, yaw) in [-1,1]
var hand_brake := 0.0  # analog [0,1]: cuts air friction for sharp pivots
var throttle := 0.0    # analog [0,1]: right trigger, drives the craft while grounded
var boost := false
var slow := 0.0
