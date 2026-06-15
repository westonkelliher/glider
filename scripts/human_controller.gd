class_name HumanController
extends RefCounted
## Reads live player input into a GliderControls.

func sample(_glider: Glider, scheme: GliderInput.Scheme) -> GliderControls:
	var ctl := GliderControls.new()
	ctl.targets = GliderInput.read_targets(scheme)
	ctl.braked = GliderInput.read_braked()
	ctl.boost = Input.is_action_pressed("boost")
	ctl.slow = Input.get_action_strength("slow_down")
	return ctl
