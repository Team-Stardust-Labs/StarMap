extends Camera2D


var _target_zoom := 1.0
const MIN_ZOOM: float = 0.15
const MAX_ZOOM: float = 2.0
const ZOOM_INCREMENT: float = 0.1
const ZOOM_RATE: float = 10.0

var _target_position = Vector2()
const PAN_RATE: float = 12.0
const CAMERA_MAP_MARGIN = 0.5 # percent

var can_place_note = true
var node_place_timer = Timer.new()

func _ready():
	_target_position = position
	
	node_place_timer.wait_time = 0.2
	node_place_timer.timeout.connect(allow_place_note)
	node_place_timer.one_shot = true
	add_child(node_place_timer)

func _input(event):
	# panning
	if event is InputEventMouseMotion:
		if event.button_mask == MOUSE_BUTTON_MASK_RIGHT:
			_target_position -= event.relative / zoom 
			set_physics_process(true)
			
	# zooming
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_in()
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom_out()
				
	# placing notes
	if Input.is_action_just_pressed("Create_Note") && can_place_note:

		create_note_at_mouse()
		can_place_note = false
		node_place_timer.start()
		
	# screenshotting
	if Input.is_action_just_pressed("Screenshot"):
		# start screen capture
		$"../Grid".hide()
		await get_tree().create_timer(0.1).timeout
		var image = get_viewport().get_texture().get_image()
		image.save_png("res://screenshots/" + str(round(Time.get_unix_time_from_system())) + ".png")
		print("screenshot saved!")
		$"../Grid".show()
		
			
func zoom_in() -> void:
	_target_zoom = min(_target_zoom + (ZOOM_INCREMENT * zoom.x), MAX_ZOOM)
	set_physics_process(true)
	
func zoom_out() -> void:
	_target_zoom = max(_target_zoom - (ZOOM_INCREMENT * zoom.x), MIN_ZOOM)
	set_physics_process(true)

func allow_place_note():
	can_place_note = true
	print("can place!")

func create_note_at_mouse():
	var mouse_pos = get_global_mouse_position()
	mouse_pos += Vector2(randi_range(-4.0, 4.0)*8.0, randi_range(-4.0, 4.0)*8.0)
	var note = preload("res://placeables/stickynote.tscn").instantiate(PackedScene.GEN_EDIT_STATE_MAIN_INHERITED)
	$"../Notes".add_child(note)
	note.position = mouse_pos
	

	# replicate over network
	if Networking.has_valid_connection():
		var id = str(Time.get_ticks_msec()) +str(Networking.CLIENT_NAME.replace(":", "_"))
		Networking.send_instruction("NOTE:CREATE:" + id + ":" +str(mouse_pos.x)+":"+str(mouse_pos.y))
		note.initialize(id)
	else:
		note.initialize(str(Time.get_ticks_msec()))


func _physics_process(delta) -> void:
	zoom = lerp(zoom, _target_zoom * Vector2.ONE, ZOOM_RATE * delta)
	
	
	position = lerp(position, _target_position, PAN_RATE * delta)
	position.x = clamp(position.x, -8192 * CAMERA_MAP_MARGIN, 8192 * CAMERA_MAP_MARGIN)
	position.y = clamp(position.y, -4608 * CAMERA_MAP_MARGIN, 4608 * CAMERA_MAP_MARGIN)
	
	set_physics_process((not is_equal_approx(zoom.x, _target_zoom)) or (not is_equal_approx(position.x, _target_position.x)) or (not is_equal_approx(position.y, _target_position.y)))
