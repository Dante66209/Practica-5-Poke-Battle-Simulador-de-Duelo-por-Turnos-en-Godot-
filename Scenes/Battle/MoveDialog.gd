extends Control

var _curpos = 0
var _positions = [Vector2(15,23), Vector2(15, 63), Vector2(233, 23), Vector2(233, 63)]

signal move_chosen(id)

var _moves = [null, null, null, null]

@onready var start_sound: AudioStreamPlayer = $StartSound

@onready var move_labels = [
	$MovesDialog/Move0,
	$MovesDialog/Move1,
	$MovesDialog/Move2,
	$MovesDialog/Move3
]


func set_moves(moves = [null, null, null, null]):
	_moves = moves

func _ready():
	connect("move_chosen", Callable(get_parent(), "move_chosen"))
	for i in range(4):
		if _moves[i] != null:
			move_labels[i].text = tr("MOVENAME_" + _moves[i].data.id)
	print_infobox()
	
func print_infobox():
	if _moves[_curpos] != null:
		$Infobox/PP.text = "PP: " + String.num(_moves[_curpos].power_points) + " / " + String.num(_moves[_curpos].data.max_power_points)
	else:
		$Infobox/PP.text = "PP: -- / --"

func _input(event):
	if self.visible:
		var olcur = _curpos
		if event.is_action_pressed("ui_down") and _curpos % 2 == 0: # If down and in the upper part of box
			_curpos += 1
		elif event.is_action_pressed("ui_up") and _curpos % 2 == 1: # If up and in the lower part of the box
			_curpos -= 1
		elif event.is_action_pressed("ui_right") and _curpos < 2: # If right and in the left part of the box
			_curpos += 2
		elif event.is_action_pressed("ui_left") and _curpos >= 2: # If left and in the right part of the box
			_curpos -= 2
		elif event.is_action_pressed("ui_accept"):
			emit_signal("move_chosen", _curpos)
		if olcur != _curpos: # Update the cursor and the infobox only if the position has changed
			if start_sound:
				start_sound.play()
			$MovesDialog/Arrow.position = _positions[_curpos]
			print_infobox()
