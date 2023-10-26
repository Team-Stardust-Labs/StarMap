extends SubViewportContainer


# Called when the node enters the scene tree for the first time.
func _ready():
	$SubViewport.world_2d = get_world_2d()
