extends Button

signal pokemon_selected(option)

@onready var sprite: TextureRect = $Sprite
@onready var name_label = $NameLabel
@onready var start_sound: AudioStreamPlayer = $StartSound
@onready var cry_sound: AudioStreamPlayer = $CrySound

var species
var starting := false
var float_time := 0.0
var base_y := 0.0

func _ready():
	base_y = position.y

func _process(delta):

	float_time += delta

	position.y = base_y + sin(float_time * 1.5) * 4
	

func setup(data):

	species = data

	print("SETUP LLAMADO PARA:", species.id)

	name_label.text = str(species.id)

	if species.front_texture:
		sprite.texture = species.front_texture
		print("Asignando sprite:", species.front_texture.resource_path)
		
		load_cry()

func load_cry():

	if cry_sound == null:
		return

	var cry_path = "res://Data/Cries/" + species.id.to_lower() + ".wav"

	if ResourceLoader.exists(cry_path):
		cry_sound.stream = load(cry_path)

func _pressed():

	if start_sound:
		start_sound.play()

	if cry_sound and cry_sound.stream:
		cry_sound.play()

	print("Pokemon seleccionado:", species.id)

	emit_signal("pokemon_selected", self)
