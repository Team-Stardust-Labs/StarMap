extends Control

var in_lobby = false

# Called when the node enters the scene tree for the first time.
func _ready():
	hide_menus()
	Networking.connect("update_network_state", self._on_connection_established)
	Networking.connect("status_code", self._handle_status_codes)
	Networking.connect("note_instruction", self._handle_note_instructions)
	Networking.set_client_name("")
	allow_leave_map(false)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

@onready var Menu = $Menus/Menu

func _on_menu_button_pressed():
	$Menus/MenuAnimPlayer.play("showMenu", -1, 1.5)

func _on_menu_close_requested():
	hide_menus()

func _on_create_map_pressed():
	$Menus/Menu/CreateMap.popup()

func _on_create_map_close_requested():
	$Menus/Menu/CreateMap.hide()

func _on_join_map_pressed():
	$Menus/Menu/JoinMap.popup()

func _on_join_map_close_requested():
	$Menus/Menu/JoinMap.hide()



# ATTEMPT CONNECTING TO A STARMAP SERVER
func _on_connect_url_pressed():
	var url = $Menus/Menu/Vbox/SocketURL.text
	Networking.disconnect_from_server()
	var err = Networking.connect_to_server(url)
	if err != OK:
		$Menus/Menu/Vbox/StatusLabel.text = "Connection ERR: " + str(err)
		allow_create_join_map(false)
		return
	$Menus/Menu/Vbox/StatusLabel.text = "Connecting..."

func _on_connection_established():
	if Networking.state != WebSocketPeer.STATE_OPEN:
		$Menus/Menu/Vbox/StatusLabel.text = "No connection to server"
		allow_create_join_map(false)
		return
	$Menus/Menu/Vbox/StatusLabel.text = "Connected to StarMap Server"
	allow_create_join_map(true)


func _on_client_name_text_changed(name):
	Networking.set_client_name(name)

# creating a starmap
func _on_create_star_map_pressed():
	if Networking.has_valid_connection():
		var lobby_id = $Menus/Menu/CreateMap/Vbox/MapName.text
		if lobby_id == "":
			$Menus/Menu/CreateMap/Vbox/StatusLabel.text = "Codes can't be empty"
			return
		Networking.send_create_map(lobby_id)

# joining a starmap
func _on_join_star_map_pressed():
	if Networking.has_valid_connection():
		var lobby_id = $Menus/Menu/JoinMap/Vbox/MapName.text
		if lobby_id == "":
			$Menus/Menu/JoinMap/Vbox/StatusLabel.text = "Codes can't be empty"
			return
		Networking.send_join_map(lobby_id)

# leave a starmap
func _on_leave_map_pressed():
	if Networking.has_valid_connection():
		Networking.send_leave_map()

func hide_menus() -> void:
	$Menus/MenuAnimPlayer.play("showMenu", -1, -1.5, true)
	$Menus/Menu/CreateMap.hide()
	$Menus/Menu/JoinMap.hide()

func allow_create_join_map(allowed):
	$Menus/Menu/Vbox/CreateMap.disabled = !allowed
	$Menus/Menu/Vbox/JoinMap.disabled = !allowed

func allow_leave_map(allowed):
	$Menus/Menu/Vbox/LeaveMap.disabled = !allowed


func _handle_status_codes(code):
	match code:
		"LOBBY_CREATED_OK":
			hide_menus()
			in_lobby = true
			allow_leave_map(true)
			allow_create_join_map(false)
		"LOBBY_JOINED_OK":
			hide_menus()
			in_lobby = true
			allow_leave_map(true)
			allow_create_join_map(false)
			
			if Networking.has_valid_connection():
				Networking.send_history_request()
			
		"LOBBY_LEAVE_OK":
			hide_menus()
			in_lobby = false
			allow_leave_map(false)
			allow_create_join_map(true)
			
	
func _handle_note_instructions(raw: String):
	var inst = raw.split(":")
	print(raw)
	match inst[0]:
		"CREATE":
			var id = inst[1]
			var pos_x = inst[2]
			var pos_y = inst[3]
			var note = preload("res://placeables/stickynote.tscn").instantiate(PackedScene.GEN_EDIT_STATE_MAIN_INHERITED)
			$Notes.add_child(note)
			note.position = Vector2(float(pos_x), float(pos_y))
			note.initialize(id)
		"MOVE":
			var id = inst[1]
			var pos_x = inst[2]
			var pos_y = inst[3]
			if Networking.notes.has(id):
				Networking.notes[id].position = Vector2(float(pos_x), float(pos_y))
		"CHANGE_TEXT":
			var id = inst[1]
			var new_text = inst[2]
			if Networking.notes.has(id):
				Networking.notes[id].set_label_text(new_text)
			
