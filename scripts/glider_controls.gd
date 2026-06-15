class_name GliderControls
extends RefCounted
## Source-agnostic control sample for a glider. Filled by a controller
## (human input or AI) and consumed by the flight model in glider_body.gd.

var targets := Vector3.ZERO  # (pitch, roll, yaw) in [-1,1]
var braked := false
var boost := false
var slow := 0.0
