extends Node3D

func _ready():
	for i in 0:
		var car = load("res://Car.tscn").instantiate()
		get_child(randi_range(0, get_child_count()-1)).add_child(car)
		car.base_speed = randf_range(0.01, 0.1)
		await get_tree().create_timer(1).timeout
