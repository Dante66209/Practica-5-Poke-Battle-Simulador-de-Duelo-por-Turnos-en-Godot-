extends Object

class_name OpMon

const Type = preload("res://Objects/Enumerations.gd").Type
const Stats = preload("res://Objects/Enumerations.gd").Stats
const Status = preload("res://Objects/Enumerations.gd").Status
const TYPE_EFFECTIVENESS = preload("res://Objects/Enumerations.gd").TYPE_EFFECTIVENESS
const MOVE_ANIMATIONS = preload("res://Objects/Enumerations.gd").MOVE_ANIMATIONS

var stats = [0, 0, 0, 0, 0, 0]
var ev = [0, 0, 0, 0, 0, 0]
var stats_change = [0, 0, 0, 0, 0, 0, 0, 0]

# In-battle stats modificators for basic stats
const mod_stat = [0.25, 0.29, 0.33, 0.40, 0.50, 0.67, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0]
# In-battle stats modificators for accuracy and evasion
const mod_stat_2 = [0.33, 0.38, 0.43, 0.5, 0.6, 0.75, 1.0, 1.33, 1.67, 2.0, 2.33, 2.67, 3.0]

var species: Species
var level: int
# Must contain OpMove objects
var moves = [null, null, null, null]
var nature: Nature
var hp: int: set = set_hp
var status = Status.NOTHING
var nickname = ""

func learn_initial_moves():
	# Asegurarnos de tener el array con 4 slots
	moves = [null, null, null, null]

	if species == null:
		return

	if species.initial_moves == null:
		return

	var slot := 0
	for m in species.initial_moves:
		if m == null:
			continue
		# Crea una OpMove usando el Move resource (m)
		moves[slot] = OpMove.new(m)     # usa el constructor interno que ya existe
		slot += 1
		if slot >= 4:
			break

func save() -> Dictionary:
	var moves_saved := []
	for move in moves:
		if move == null:
			moves_saved.append(null)
		else:
			moves_saved.append(move.save())
	return {
		"stats" : stats,
		"ev" : ev,
		"species" : species.id,
		"level" : level,
		"moves" : moves_saved,
		"nature" : nature.id,
		"hp" : hp,
		"status" : status,
		"nickname" : nickname
	}

func load_save(data: Dictionary):
	stats = data["stats"]
	ev = data["ev"]
	species = PlayerData.res_species[data["species"]]
	level = data["level"]
	var moves_loaded := []
	for move in data["moves"]:
		if move == null:
			moves_loaded.append(null)
		else:
			moves_loaded.append(OpMove.new(PlayerData.res_move[move["move"]], move["power_points"]))
	moves = moves_loaded
	nature = PlayerData.res_nature[data["nature"]]
	hp = data["hp"]
	status = data["status"]
	nickname = data["nickname"]

# Avoids going below zero or above max HP
func set_hp(new_hp: int) -> void:
	hp = new_hp
	if new_hp < 0:
		new_hp = 0
	elif new_hp > stats[Stats.HP]:
		new_hp = stats[Stats.HP]

# Recalculates the stats from the base stats, evs, nature and level
func calc_stats():

	stats.resize(6)

	stats[0] = species.base_hp + level * 2
	stats[1] = species.base_attack + level
	stats[2] = species.base_defense + level
	stats[3] = species.base_special_attack + level
	stats[4] = species.base_special_defense + level
	stats[5] = species.base_speed + level

# p_moves must contain four Move objects
# Default arguments are here to generate a generic object to be loaded with load_save()
# Don’t use an OpMon created with these default arguments
func _init(p_nickname := "", p_species = null, p_level := 5, p_moves := [null, null, null, null], p_nature = null):
	nickname = p_nickname
	species = p_species
	level = p_level
	for i in range(4): # Initializes OpMoves from the raw data of Moves
		if p_moves[i] != null:
			moves[i] = OpMove.new(p_moves[i])
	nature = p_nature
	if species != null and nature != null:
		calc_stats()
	hp = stats[Stats.HP]

# Returns the final statistics of the OpMon, with the in-battle modifications
func get_effective_stats() -> Array:
	var effective_stats = stats.duplicate(true)
	# Accuracy and evasion
	effective_stats.append(100)
	effective_stats.append(100)
	
	for i in range(6):
		effective_stats[i] *= mod_stat[stats_change[i] + 6]
		
	for i in range(6,8):
		effective_stats[i] *= mod_stat_2[stats_change[i] + 6]
	
	return effective_stats

# Completely heals the OpMon
func heal():
	# Restaurar HP
	hp = stats[Stats.HP]
	status = Status.NOTHING

	# Restaurar PP de cada movimiento si existe
	for move in moves:
		if move == null:
			continue
		# move debería ser instancia OpMove; si por cualquier razón no lo es, saltar
		if typeof(move) != TYPE_OBJECT or not move.has_method("save"):
			push_warning("OpMon.heal(): elemento de moves no es OpMove -> ignorado: " + str(move))
			continue
		if move.data == null:
			push_warning("OpMon.heal(): move.data es null para move: " + str(move))
			continue
		move.power_points = move.data.max_power_points
		
func is_ko() -> bool:
	return hp <= 0
	
func get_effective_name() -> String:
	if nickname == "":
		return tr("OPNAME_" + species.id)
	else:
		return nickname

# Parameter: allows to get a hp string for a different hp
func get_hp_string(hp_p := -1) -> String:
	@warning_ignore("shadowed_variable")
	var hp = self.hp if hp_p < 0 else hp_p
	return str(hp) + " / " + str(stats[Stats.HP])

	
# In-battle modification of statistics, capped at ±6
# Returns the actual modification
func change_stat(stat, change) -> int:
	# Checks if the cap is already reached
	if (change > 0 and stats_change[stat] == 6) or (change < 0 and stats_change[stat] == -6):
		return 0
	stats_change[stat] += change
	var overflow = stats_change[stat] - 6
	if overflow > 0:
		stats_change[stat] = 6
		return change - overflow
	var underflow = stats_change[stat] + 6
	if underflow < 0:
		stats_change[stat] = -6
		return change - underflow
	return change

# A Move class representing an OpMon’s move. It uses the data of Move but this class is "living",
# meaning it’s edited to store the power points and other dynamic data of a move.
# It also contains the method that processes the move
class OpMove:
	var power_points: int
	var data: Move
	
	const Stats = preload("res://Objects/Enumerations.gd").Stats
	

	
	func save() -> Dictionary: # Loading directly in OpMon.load_save()
		return {
			"move" : data.id,
			"power_points" : power_points
		}
	
	func _init(p_data: Move, p_power_points := -1):
		data = p_data
		power_points = data.max_power_points if p_power_points == -1 else p_power_points


	func move(battle_scene, user: OpMon, opponent: OpMon):
		print("MOVE:", data.id, "ANIM:", data.move_animation)
		print("EXISTS:", MOVE_ANIMATIONS.has(data.move_animation))

		# --- PP ---
		if power_points <= 0:
			battle_scene.move_failed()
			return
		power_points -= 1

		# --- TEXTO INICIAL ---
		battle_scene.add_dialog([
			user.species.name + " used " + tr("MOVENAME_" + data.id)
		])

		# --- ANIMACIÓN ATAQUE (ENCOLADA) ---
		var is_player = user == battle_scene.player_opmon
		battle_scene._action_queue.append({"method": "_animate_move","parameters": [is_player, "attack"]})

		# --- PRECISIÓN ---
		if not data.never_fails:
			var hit_roll = randf() * 100.0
			if hit_roll > data.accuracy:
				battle_scene.move_failed()
				return

		# --- DAÑO ---
		if data.category != data.Category.STATUS:

			var atk_index = Stats.ATK if data.category == data.Category.PHYSICAL else Stats.ATKSPE
			var def_index = Stats.DEF if data.category == data.Category.PHYSICAL else Stats.DEFSPE

			var atk_val = user.get_effective_stats()[atk_index]
			var def_val = max(1, opponent.get_effective_stats()[def_index])
			var base = data.power

			var dmg_float = (((2.0 * user.level) / 5.0 + 2.0) * base * (float(atk_val) / float(def_val)) / 50.0) + 2.0
			dmg_float *= (0.85 + 0.15 * randf())

			var dmg = max(1, int(round(dmg_float)))

			# aplicar daño
			opponent.hp = max(0, opponent.hp - dmg)

			# --- ANIMACIÓN HURT ---
			var target_is_player = opponent == battle_scene.player_opmon
			battle_scene._action_queue.append({"method": "_animate_move","parameters": [target_is_player, "hurt"]})
			battle_scene.add_dialog([opponent.species.name + " lost " + str(dmg) + " HP!"])
			battle_scene.update_hp_target(target_is_player, opponent.hp)

			# --- KO ---
			if opponent.is_ko():
				battle_scene._action_queue.append({"method": "_animate_move","parameters": [target_is_player, "ko"]})
				battle_scene.add_dialog([ opponent.species.name + " fainted!" ])
				battle_scene._action_queue.append({
					"method": "_ko",
					"parameters": []
				})
				return
############################################################################################################
########################################    EFECTOS DE ATAQUES     ######################################### 
############################################################################################################
		else:
			# STATUS
			battle_scene.add_dialog([ tr("BATTLE_MOVE_USED_STATUS") ])
