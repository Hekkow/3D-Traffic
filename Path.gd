extends Path3D

var baked_points = []

func _ready():
	var temp_points = curve.get_baked_points()
	for point in temp_points:
		baked_points.append(to_global(point))
	
	Auto.lanes.append(self)
	
