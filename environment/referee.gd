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
		ball.velocity = Vector3.UP * 24.0
	for glider in get_tree().get_nodes_in_group("glider"):
		if glider.has_method("reset_to_spawn"):
			glider.reset_to_spawn()
	_scoring = false
