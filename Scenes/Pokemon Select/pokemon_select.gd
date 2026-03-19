extends Control

@onready var pokemon_list = get_node_or_null("MarginContainer/VBoxContainer/PokemonList")
@onready var confirm_button = get_node_or_null("MarginContainer/VBoxContainer/HBoxContainer/ConfirmButton")

@onready var music: AudioStreamPlayer2D = $SelectMusic

var selected_option = null

func _ready():

	print("DEBUG pokemon_list:", pokemon_list)
	print("DEBUG confirm_button:", confirm_button)

	if music:
		music.play()

	if confirm_button == null:
		push_error("ConfirmButton no encontrado.")
		return

	if pokemon_list == null:
		push_error("PokemonList no encontrado.")
		return

	confirm_button.disabled = true

	load_pokemon()

func load_pokemon():

	var species_list = [
		load("res://Data/GodotResources/Species/NANOLPHIN.tres"),
		load("res://Data/GodotResources/Species/ROSARIN.tres")
	]

	var option_scene = preload("res://Scenes/pokemon_option.tscn")

	for species in species_list:

		if species == null:
			continue

		var option = option_scene.instantiate()

		option.setup(species)

		option.connect("pokemon_selected", Callable(self, "_on_pokemon_selected"))

		pokemon_list.add_child(option)

func _on_pokemon_selected(option):

	selected_option = option

	for child in pokemon_list.get_children():
		child.modulate = Color(1,1,1)

	option.modulate = Color(1,1,0.6)

	confirm_button.disabled = false

func _on_ConfirmButton_pressed():

	if selected_option == null:
		return

	print("Pokemon elegido:", selected_option.species.id)
