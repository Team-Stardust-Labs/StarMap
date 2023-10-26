extends Control

var ID = ""

func initialize(id):
	ID = id
	Networking.notes[ID] = self

func _on_panel_gui_input(event):
	if event is InputEventMouseMotion:
		if event.button_mask == MOUSE_BUTTON_MASK_LEFT:
			position += event.relative
			
			# replicate over network
			if Networking.has_valid_connection():
				Networking.send_instruction("NOTE:MOVE:" + ID + ":"+str(position.x)+":"+str(position.y))
			
	if event is InputEventMouseButton:
		if Input.is_action_just_pressed("Delete_Note"):
			$noteAnim.play("delete")

func _on_label_gui_input(event):
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == MOUSE_BUTTON_MASK_LEFT:
				if $Label.text != "Sticky Note!":
					$Panel/Popup/Vbox/Text.text = $Label.text
				$Panel/Popup.show()
				$Panel/Popup/Vbox/Text.grab_focus()
				
func set_label_text(text):
	$Label.text = text
	refresh_panel_size()

func refresh_panel_size():
	$Panel.size = $Label.size + Vector2(32, 48)
	$Panel.position = (-$Panel.size/2)

func _on_text_text_changed():
	$Label.text = $Panel/Popup/Vbox/Text.text
	refresh_panel_size()
	
	# replicate over network
	if Networking.has_valid_connection():
		Networking.send_instruction("NOTE:CHANGE_TEXT:" + ID + ":"+$Label.text)



func _on_popup_close_requested():
	$Panel/Popup.hide()


func _on_popup_focus_exited():
	$Panel/Popup.hide()


func _on_apply_pressed():
	_on_text_text_changed()
	$Panel/Popup.hide()

func _exit_tree():
	Networking.notes.erase(ID)
