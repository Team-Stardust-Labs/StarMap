extends Node

var client := WebSocketPeer.new()
var state = WebSocketPeer.STATE_CLOSED
var last_state = WebSocketPeer.STATE_CLOSED

var CLIENT_NAME = ""

signal update_network_state
signal message_available
signal status_code
signal note_instruction

var notes := {}


func _ready():
	set_process(false)
	
	DisplayServer.window_set_size(Vector2i(1000, 800))

func set_client_name(name):
	if name == "":
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		CLIENT_NAME = "ANYM" + str(rng.randi_range(1000, 9999))
	else:
		CLIENT_NAME = name

func has_valid_connection() -> bool:
	if state == WebSocketPeer.STATE_OPEN:
		return true
	else:
		return false

func disconnect_from_server():
	client.close()
	
func connect_to_server(url):
	if state != WebSocketPeer.STATE_CLOSED:
		return
	var err = client.connect_to_url(url)
	if err != OK:
		set_process(false)
		return err
	else:
		set_process(true)
		return OK


func _process(delta):
	client.poll()
	last_state = state
	state = client.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		while client.get_available_packet_count():
			data_received()
	
	if state != last_state:
		emit_signal("update_network_state")
	
func data_received() -> void:
	var payload = client.get_packet().get_string_from_utf8()
	if payload.begins_with("STATUS:"):
		emit_signal("status_code", payload.trim_prefix("STATUS:"))
		print("received a status code")
	elif payload.begins_with("NOTE:"):
		emit_signal("note_instruction", payload.trim_prefix("NOTE:"))
		print("received a note instruction")
	else:
		emit_signal("message_available", payload)
		
	print(payload)
	
func send(msg):
	client.send_text(msg)

func send_chat_message(text):
	var msg = Dictionary()
	msg["message"] = text
	msg = JSON.stringify(msg)
	client.send_text(msg)

func send_create_map(lobby_id):
	var msg = Dictionary()
	msg["CREATE_LOBBY"] = true
	msg["LOBBY_CODE"] = str(lobby_id)
	msg["CLIENT_NAME"] = str(CLIENT_NAME)
	msg = JSON.stringify(msg)
	client.send_text(msg)
	print("MSG TO SEND: " + str(msg))
	
func send_join_map(lobby_id):
	var msg = Dictionary()
	msg["LOBBY_CODE"] = str(lobby_id)
	msg["CLIENT_NAME"] = str(CLIENT_NAME)
	msg = JSON.stringify(msg)
	client.send_text(msg)
	print("MSG TO SEND: " + str(msg))

func send_leave_map():
	var msg = Dictionary()
	msg["LEAVE_LOBBY"] = true
	msg = JSON.stringify(msg)
	client.send_text(msg)
	print("MSG TO SEND: " + str(msg))

func send_instruction(inst):
	var msg = Dictionary()
	msg["INSTRUCTION"] = inst
	msg = JSON.stringify(msg)
	client.send_text(msg)
	print("MSG TO SEND: " + str(msg))

func send_history_request():
	var msg = Dictionary()
	msg["GET_LOBBY_HISTORY"] = true
	msg = JSON.stringify(msg)
	client.send_text(msg)
	print("MSG TO SEND: " + str(msg))

func _exit_tree():
	client.close()

'''
# creating lobbies
{"CREATE_LOBBY" : true, "LOBBY_CODE" : "sampleLobby01", "CLIENT_NAME" : "Gustav" }

# joining lobbies
{"LOBBY_CODE" : "sampleLobby01", "CLIENT_NAME" : "Tobi"}

# sending messages to lobbies
{"message" : "Hallo Leute!"}

# switching lobbies ( lobby must exist! )
{"SWITCH_LOBBY" : true, "NEW_LOBBY_CODE" : "sampleLobby02"}

# leaving lobbies
{ "LEAVE_LOBBY": true }
'''
