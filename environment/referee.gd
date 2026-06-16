extends StaticBody3D
## Goal-scoring referee. Attached to the Arena root node, so the goal Area3D
## nodes are direct children. Detects the ball entering a goal, updates the
## score, and resets the ball + gliders.

@onready var goal_north: Area3D = $GoalNorth   # BLUE goal
@onready var goal_south: Area3D = $GoalSouth   # ORANGE goal

var score_blue := 0     # goals scored INTO the north/blue goal
var score_orange := 0   # goals scored INTO the south/orange goal

var _scoring := false    # guard against double-counting a lingering ball


func _ready() -> void:
	add_to_group("referee")
	goal_north.body_entered.connect(_on_north_entered)
	goal_south.body_entered.connect(_on_south_entered)
	print("[referee] ready, monitoring goals")


func _on_north_entered(body: Node) -> void:
	if _scoring or not body.is_in_group("ball"):
		return
	_scoring = true
	score_blue += 1
	print("GOAL! BLUE  blue=%d orange=%d" % [score_blue, score_orange])
	_reset_after_goal()


func _on_south_entered(body: Node) -> void:
	if _scoring or not body.is_in_group("ball"):
		return
	_scoring = true
	score_orange += 1
	print("GOAL! ORANGE blue=%d orange=%d" % [score_blue, score_orange])
	_reset_after_goal()


func _reset_after_goal() -> void:
	var ball := get_tree().get_first_node_in_group("ball")
	if ball:
		ball.global_position = Vector3(0, 5, 0)
		ball.velocity = Vector3.UP * 15.0 # TODO this 15.0 needs to be a variable cus it exists elsewhere
	# Pick a fresh (mirrored) kickoff spawn for both teams.
	MatchController.place_kickoff(get_tree())
	_scoring = false
	# Re-run the kickoff countdown (freezes the field for 3-2-1-GO).
	var mc := get_tree().get_first_node_in_group("match_controller")
	if mc and mc.has_method("kickoff"):
		mc.kickoff()
