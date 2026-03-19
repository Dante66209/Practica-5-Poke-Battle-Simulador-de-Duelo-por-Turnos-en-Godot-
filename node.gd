# res://Scripts/GameState.gd
extends Node

var selected_pokemon = null
var selected_index = -1

func set_selected(pokemon_data, index = -1):
	selected_pokemon = pokemon_data
	selected_index = index

func clear():
	selected_pokemon = null
	selected_index = -1
