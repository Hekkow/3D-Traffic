extends PathFollow3D

@onready var area: Area3D = $Area3D
var currently_on_lane: Path3D
@export var base_speed: float = 0.05
@onready var speed = base_speed
enum {WAITING_FOR_SWAP, SWAPPING, DRIVING}
var state = DRIVING
var substate
var swapping_to_position: Vector3
var swapping_to_lane: Path3D
var swapping_to_rotation: Vector3
var raycast_distance = 1
var lower_speed_start_time = INF
var lane_swap_time = 1
@export var patience: float = 1
var fps = 60
var velocity
var allowed_forward_amount = 0.9

func _ready():
	set_physics_process(false)
	await get_tree().create_timer(0.1).timeout
	set_physics_process(true)
	currently_on_lane = get_closest_lanes()[0]
	#area.area_entered.connect()
	pass
func lane_swap(lane: Path3D):
	speed = base_speed
	swapping_to_lane = lane
	swapping_to_position = get_swap_position(lane)
	swapping_to_rotation = lane.curve.sample_baked_with_rotation(progress + get_forward_distance()).basis.get_euler()
	substate = null
	state = SWAPPING

func get_swappable_lanes():
	return get_closest_lanes().filter(func (lane): return lane != currently_on_lane).filter(func (lane): return lane_swappable(lane))

func lane_swappable(lane: Path3D):
	var cars = area.get_overlapping_areas().map(func(area): return area.get_parent())
	var cars_on_other_lanes = cars.filter(func (car): return car.currently_on_lane == lane && (car.global_position - global_position).normalized().dot(-transform.basis.z.normalized()) <= allowed_forward_amount)
	
	prints("HERE", cars, cars_on_other_lanes)
	return len(cars_on_other_lanes) == 0

func get_forward_distance():
	# distance = speed * time, speed is measured in units/second so gotta multiply by fps
	# add sideways speed as well so that speed stays the same going forward
	return (speed + (cos(0) * speed) * fps) * lane_swap_time

func get_swap_position(lane: Path3D):
	var forward_distance_intervals = get_forward_distance() / lane.curve.bake_interval
	var index = get_closest_point_index(lane) + forward_distance_intervals
	if len(lane.baked_points) <= index:
		index = len(lane.baked_points) - 1
	
	return lane.baked_points[index]
	
func get_closest_point_index(lane):
	var closest_distance = INF
	var closest_index
	for i in len(lane.baked_points):
		var distance = lane.baked_points[i].distance_to(global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_index = i
	return closest_index
	
func get_closest_lanes():
	var lanes = Auto.lanes
	lanes.sort_custom(lane_sort)
	return lanes

func lane_sort(a, b):
	if a.baked_points[get_closest_point_index(a)].distance_to(global_position) < b.baked_points[get_closest_point_index(b)].distance_to(global_position):
		return true
	return false

func _physics_process(_delta):
	if state == SWAPPING:
		velocity = (swapping_to_position - global_position).normalized() * base_speed
		global_position += velocity
		look_at(swapping_to_position)
		if (global_position.distance_to(swapping_to_position) < base_speed):
			var closest_offset = swapping_to_lane.curve.get_closest_offset(swapping_to_lane.to_local(global_position))
			var new_progress = closest_offset / swapping_to_lane.curve.get_baked_length()
			reparent.call_deferred(swapping_to_lane)
			currently_on_lane = swapping_to_lane
			state = DRIVING
			speed = base_speed
			await get_tree().physics_frame
			progress_ratio = new_progress
	elif state == DRIVING:
		if (speed < base_speed && Time.get_ticks_msec() - lower_speed_start_time >= patience * 1000 ) || substate == WAITING_FOR_SWAP:
			if lane_swap_if_possible():
				return
		var space_state = get_world_3d().direct_space_state
		var end_position = global_position - transform.basis.z * raycast_distance
		var query = PhysicsRayQueryParameters3D.create(global_position, end_position)
		#DebugDraw3D.draw_line(global_position, end_position, Color(1, 1, 0))
		var result = space_state.intersect_ray(query)
		if result:
			if speed > result.collider.get_parent().speed:
				speed = result.collider.get_parent().speed
				lower_speed_start_time = Time.get_ticks_msec()
		else:
			speed = base_speed
			
		progress += speed
	elif state == WAITING_FOR_SWAP:
		lane_swap_if_possible()
		
func lane_swap_if_possible():
	var possible_lanes = get_swappable_lanes()
	prints(name, state, possible_lanes)
	if len(possible_lanes) > 0:
		lane_swap(possible_lanes[0])
		return true
	else:
		substate = WAITING_FOR_SWAP
		return false
#var box = CSGBox3D.new()
#get_parent().add_child.call_deferred(box)
#box.set_deferred("global_position", swapping_to_position)
