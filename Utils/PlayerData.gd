# res://Utils/PlayerData.gd
extends Node

# This singleton contains player-related data like name, id, or team
# It also contains some resources (OpMon species, moves, natures, items)

var player_name: String = ""

var team: OpTeam = null

# Lists of loaded resources
# Keys: IDs (String)
var res_species: Dictionary = {}
var res_move: Dictionary = {}
var res_nature: Dictionary = {}
var res_item: Dictionary = {}

# Keys: Item ID (String)
# Values: Quantity (int)
var bag: Dictionary = {}

# Loads every resource in a given directory.
# Warning: don’t forget to include "/" at the end of the directory.
func _load_dir(path: String) -> Array[Resource]:
	var dir = DirAccess.open(path)
	var files := dir.get_files()
	var ret: Array[Resource] = []

	for file in files:
		if file.ends_with(".tres"):
			var res = load(path + file)
			if res == null:
				print("ERROR loading: ", path + file)
			else:
				ret.append(res)

	return ret

func _load_resources():
	print("PlayerData: Loading resources...")
	# Asegurar diccionarios limpios
	res_species = {}
	res_move = {}
	res_nature = {}
	res_item = {}

	# --- Species ---
	# --- Species (con get_property_list) ---
	var species_loaded := 0

	for species in _load_dir("res://Data/GodotResources/Species/"):
		if species == null:
			continue

		if species.id == null or species.id == "":
			push_warning("Species sin ID válido: " + str(species.resource_path))
			continue

		res_species[species.id] = species
		species_loaded += 1

	print("Species loaded: %d" % species_loaded)

	# --- Moves ---
	for move in _load_dir("res://Data/GodotResources/Moves/"):
		if move == null:
			continue
		res_move[move.id] = move

	# --- Natures ---
	for nature in _load_dir("res://Data/GodotResources/Natures/"):
		if nature == null:
			continue
		res_nature[nature.id] = nature

	# --- Items ---
	for item in _load_dir("res://Data/GodotResources/Items/"):
		if item == null:
			continue
		res_item[item.id] = item

	print("All resources are now loaded.")
	print("Summary keys: species=%s moves=%s natures=%s items=%s" %
		[res_species.keys(), res_move.keys(), res_nature.keys(), res_item.keys()])

func _ready():
	_load_resources()

	print("Species cargados:")
	for key in res_species.keys():
		print(key)

func save() -> Dictionary:
	return {
		"current_map" : {
			"name" : null, # Filled by MapManager
			"data" : null # Filled by MapManager
		},
		"player_character" : null, # Filled by MapManager
#		"team" : team.save() if team != null else null,
		"player_name" : player_name,
		"bag": bag
	}

# crea un OpMon desde species id (ajusta nivel o moves según quieras)
func make_opmon_from_id(species_id: String, level := 10) -> OpMon:
	var s = res_species.get(species_id, null)
	if s == null:
		return null
	# ejemplo de moves iniciales: toma TACKLE/GROWL/.. si existen
	var m1 = res_move.get("TACKLE", null)
	var m2 = res_move.get("GROWL", null)
	var moves_arr := [m1, m2, null, null]
	return OpMon.new("", s, level, moves_arr, res_nature.get("BOT"))

func load_save(data: Dictionary) -> void:
	team = OpTeam.new()
	team.load_save(data["team"])
	player_name = data["player_name"]
	bag = data["bag"]
