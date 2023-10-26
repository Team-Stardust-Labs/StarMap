extends Control

var client := WebSocketPeer.new()
var url = "ws://localhost:5000"

func _ready():
	Networking.connect("message_available", print_message)

func print_message(message) -> void:
	$VBOX/Text.text += str(message) + "\n"
	
func _input(event):
	if Input.is_key_pressed(KEY_ENTER):
		_on_send_button_pressed()

func _on_send_button_pressed():
	if !Networking.has_valid_connection():
		$VBOX/Text.text += "ERROR: No connection to StarMap Server \n"
		return
	var msg = $VBOX/HBOX/ChatBox.text
	if msg != "":
		Networking.send_chat_message(msg)
		$VBOX/Text.text += "YOU: " + str(msg) + "\n"
		$VBOX/HBOX/ChatBox.text = ""
