extends Control

@onready var start_label: Label = $StartLabel
@onready var music: AudioStreamPlayer2D = $MenuMusic
@onready var start_sound: AudioStreamPlayer = $StartSound
@onready var fade: ColorRect = $Fade

var blink := true

func _ready() -> void:
	fade.modulate.a = 1.0
	var tween = create_tween()
	tween.tween_property(fade, "modulate:a", 0.0,5)
	
	if music:
		music.play()

	blink_text()

func blink_text():
	while true:
		start_label.visible = blink
		blink = !blink
		await get_tree().create_timer(0.6).timeout


var starting := false

func _input(event):
	if starting:
		return
		
	if event.is_pressed():
		starting = true
		
		if start_sound:
			start_sound.play()
			await start_sound.finished
			
		start_game()


func start_game():
	var tween = create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, 0.6)
	await tween.finished
	if music:
		music.stop()
	var path := "res://Scenes/Pokemon Select/pokemon_select.tscn"
	get_tree().change_scene_to_file(path)
