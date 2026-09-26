extends Node2D

var ship: RigidBody2D
var trail: GPUParticles2D
var ticks := 0

func _ready() -> void:
	var s: Node = load("res://scenes/test.tscn").instantiate()
	add_child(s)
	ship = s.get_node("Ship")
	trail = ship.get_node("Trail")
	print("trail resolved in ship: ", ship.trail)

func _physics_process(_d: float) -> void:
	ticks += 1

	if ticks == 40:
		print("[t40 idle]      sleeping=", ship.sleeping, " emitting=", trail.emitting)
		Input.action_press("up")
	if ticks == 45:
		print("[t45 holding W] sleeping=", ship.sleeping, " emitting=", trail.emitting)
		Input.action_release("up")
	if ticks == 60:
		print("[t60 released]  sleeping=", ship.sleeping, " emitting=", trail.emitting,
			" vel=", ship.linear_velocity.length())
	if ticks == 200:
		print("[t200 coasting] sleeping=", ship.sleeping, " emitting=", trail.emitting,
			" vel=", ship.linear_velocity.length())
		get_tree().quit()
