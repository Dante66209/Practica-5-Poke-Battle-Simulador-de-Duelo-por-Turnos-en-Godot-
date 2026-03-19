extends Control

signal dialog_over

@onready var label = $NinePatchRect/Text
@onready var start_sound: AudioStreamPlayer = $StartSound

var lines : Array = []
var index := 0
var just_opened := false


func reset():
	lines.clear()
	index = 0
	label.text = ""


func set_dialog_lines(p_lines):
	lines = p_lines
	index = 0


func go():
	if lines.size() == 0:
		emit_signal("dialog_over")
		return

	just_opened = true
	show_line()


func show_line():
	if start_sound:
		start_sound.play()
	if index >= lines.size():
		emit_signal("dialog_over")
		return

	label.text = str(lines[index])


func _input(event):

	if not visible:
		return

	if event.is_pressed():

		# 🔥 IGNORA EL PRIMER INPUT
		if just_opened:
			just_opened = false
			return

		index += 1

		if index < lines.size():
			show_line()
		else:
			hide()
			emit_signal("dialog_over")
