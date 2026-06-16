class_name TutorialController
extends RefCounted
## Human input for the tutorial, but with powers the current stage hasn't taught
## yet masked out. Steering and grip (the right trigger) are always live — those
## are the first things taught — while boost and the hard-brake are gated per
## stage. The manager flips `boost_allowed` / `slow_allowed` as stages unlock.

var boost_allowed: bool = false
var slow_allowed: bool = false


func sample(_glider: Glider, scheme: GliderInput.Scheme) -> GliderControls:
	var ctl: GliderControls = GliderControls.new()
	ctl.targets = GliderInput.read_targets(scheme)
	ctl.hand_brake = GliderInput.read_hand_brake()
	ctl.boost = boost_allowed and Input.is_action_pressed("boost")
	ctl.slow = Input.get_action_strength("slow_down")  # brake is always live
	return ctl
