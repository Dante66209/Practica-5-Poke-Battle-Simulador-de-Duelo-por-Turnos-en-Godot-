extends Control

class_name BattleScene

@onready var music: AudioStreamPlayer2D = $MenuMusic
const Stats = preload("res://Objects/Enumerations.gd").Stats



var player_team: OpTeam
var opponent_team: OpTeam

var player_opmon: OpMon
var opponent_opmon: OpMon

func _ready():
	
	if music:
		music.play()
	# conecta el dialogo para que al terminar llame a _next_action
	if has_node("TextDialog") and not $TextDialog.is_connected("dialog_over", Callable(self, "_next_action")):
		$TextDialog.connect("dialog_over", Callable(self, "_next_action"))
	# inicializa RNG para la IA
	randomize()

# Elige un movimiento válido del enemigo (índice) o devuelve -1 si no hay movs válidos
func _choose_enemy_move() -> int:
	if opponent_opmon == null:
		return -1
	var available := []
	for i in range(opponent_opmon.moves.size()):
		var mv = opponent_opmon.moves[i]
		if mv != null:
			# si tu OpMove tiene power_points (y está inicializado)
			if mv.power_points > 0:
				available.append(i)
	# si no hay movs con pp, devolver -1 (puedes implementar Struggle después)
	if available.is_empty():
		return -1
	return available[randi() % available.size()]

var move_dialog = null

# Visual events during the battle (animations, dialogs or others) are put in the forms
# or "actions", a dictionnary with the name of a method and the parameters to give it
# The action queue is filled during the calculations and is executed afterward
# The action queue is not meant to be filled manually: methods exist to fill
# automatically the queue. You can see them after the "Methods queuing actions" section.
var _action_queue := []

# True if its the player’s turn being calculated, false if it’s the opponent’s
# turn being calculated. Used in some actions to determine which OpMon is active.
var _player_in_action := true

# True if the hp bar is animated so the player’s HP label can be updated in real time.
var _hp_bar_animated := false

func init(p_team, o_team):
	
	player_team = p_team
	opponent_team = o_team

	var player_mon = player_team.get_opmon(0)
	var enemy_mon = opponent_team.get_opmon(0)
	
	print("PLAYER MON:", player_mon)
	print("ENEMY MON:", enemy_mon)
	
	_load_opmon(player_mon, true)
	_load_opmon(enemy_mon, false)
	
func _enter_tree():
	pass

func _process(_delta):
	if _hp_bar_animated:
		_update_hp_label()

# Loads a new OpMon in the battle
# Used at the beginning of a battle and when changing of OpMon
# start_hp used to keep the HP bar showing pre-calculations HP when
# switching of OpMon
# Reemplaza la función _load_opmon por esta versión segura y con debug.
func _load_opmon(mon, players: bool, start_hp := -1):
	print("LOAD OPMON:", mon)
	print("SPECIES:", mon.species)
	
	if mon == null:
		push_error("Intentando cargar un Pokémon NULL")
		return

	if mon.species == null:
		push_error("El OpMon no tiene species asignada")
		return

	if players:
		player_opmon = mon

		$PlayerOpMon.texture = player_opmon.species.back_texture
		$PlayerInfobox/Name.text = player_opmon.species.name
		$PlayerInfobox/HP.max_value = player_opmon.stats[Stats.HP]
		$PlayerInfobox/HP.value = player_opmon.hp if start_hp < 0 else start_hp
		$PlayerInfobox/Name.text = player_opmon.species.name
		$PlayerInfobox/HPLabel.text = player_opmon.get_hp_string(start_hp)

		$BaseDialog.update_idle_dialog()

	else:
		opponent_opmon = mon

		$OpponentOpMon.texture = opponent_opmon.species.front_texture
		$OpponentInfobox/Name.text = opponent_opmon.species.name
		$OpponentInfobox/HP.max_value = opponent_opmon.stats[Stats.HP]
		$OpponentInfobox/HP.value = opponent_opmon.hp if start_hp < 0 else start_hp
		$OpponentInfobox/HPLabel.text = opponent_opmon.get_hp_string(start_hp)
		
		

# ejemplo simplificado (parte de BattleScene)
func item_selected():
	$BaseDialog.hide()
	$TextDialog.show()
	$TextDialog.reset()

	var potion = load("res://Data/GodotResources/Items/Potion.tres")
	add_dialog([ player_opmon.species.name + " used " + tr("ITEMNAME_" + potion.id) + "!" ])

	for effect in potion.effect_used:
		effect.apply_opmon_battle(self, player_opmon)

	update_hp_target(true, player_opmon.hp)

	# ahora la IA enemiga responde después de que estos diálogos/actualizaciones terminen
	_action_queue.append({"method":"_enemy_take_turn", "parameters":[]})

	_next_action()

# When the move choice has been selected in the base menu
func move_selected():
	$BaseDialog.visible = false
	move_dialog = load("res://Scenes/Battle/MoveDialog.tscn").instantiate()
	move_dialog.set_moves(player_opmon.moves)
	move_dialog.position = $BaseDialog.position
	add_child(move_dialog)

func run_selected():
	emit_signal("closed")

# Called when a move has been chosen in the move selection menu
# Can also be called when an other action has been chosen and a turn starts (then id < 0)
# id: the identifier of the move (-1 for no move)
# action_priority: if the player has to act first (changing OpMon or using an item for example)
func move_chosen(id: int):
	# id == -1 -> no move this turn (skip)
	print("PLAYER MOVE ID:", id)
	print("MOVE DATA:", player_opmon.moves[id])
	if id < 0:
		# nothing to do: end the turn
		_next_action()
		return

	# si no hay movimientos del jugador o enemigo, seguridad
	if player_opmon == null or opponent_opmon == null:
		_next_action()
		return

	# Elegir un movimiento del enemigo "por defecto" (0) solo para comparaciones de prioridad
	var opponent_chosen := 0
	# Calcula prioridad / orden (mismo criterio que antes)
	var player_move_priority = player_opmon.moves[id].data.priority > opponent_opmon.moves[opponent_chosen].data.priority
	var no_move_priority = player_opmon.moves[id].data.priority == opponent_opmon.moves[opponent_chosen].data.priority
	var player_faster = player_opmon.get_effective_stats()[Stats.SPE] >= opponent_opmon.get_effective_stats()[Stats.SPE]

	var player_acts_first: bool = player_move_priority or (no_move_priority and player_faster)

	# Si el jugador actúa primero: ejecutar su move (esto añadirá acciones a la cola),
	# luego añadimos una acción para que el enemigo responda después de que terminen las acciones del jugador.
	if player_acts_first:
		# hide UI menus, mostraremos diálogos en la cola
		$BaseDialog.hide()
		if move_dialog:
			move_dialog.queue_free()
			move_dialog = null

		# Llamada al move del jugador: esto añade a la cola los diálogos/animaciones/updates
		player_opmon.moves[id].move(self, player_opmon, opponent_opmon)

		# Después de que terminen las acciones del jugador, que el enemigo tome su turno (si todavía está vivo)
		_action_queue.append({"method":"_enemy_take_turn", "parameters":[]})

	else:
		# Enemigo actúa primero: elegimos su movimiento usando IA y lo ejecutamos ahora.
		var enemy_move := _choose_enemy_move()
		if enemy_move == -1:
			# no move -> saltar al jugador
			_action_queue.append({"method":"_player_execute_after_enemy", "parameters":[id]})
		else:
			$BaseDialog.hide()
			if move_dialog:
				move_dialog.queue_free()
				move_dialog = null

			opponent_opmon.moves[enemy_move].move(self, opponent_opmon, player_opmon)
			# Luego del ataque enemigo, ejecutamos el ataque del jugador (se añadirá tras las acciones del enemigo)
			_action_queue.append({"method":"_player_execute_after_enemy", "parameters":[id]})

	# Arranca la ejecución de la cola (si no está ya ejecutándose)
	_next_action()
	
# Ejecuta el turno del enemigo (IA). Se llama por la cola después de terminar las acciones previas.
func _enemy_take_turn():
	print("ENEMY TURN STARTED")

	if opponent_opmon == null or player_opmon == null:
		return

	if opponent_opmon.is_ko() or player_opmon.is_ko():
		return

	var enemy_move := _choose_enemy_move()

	if enemy_move == -1:
		return
	
	
	_player_in_action = false
	opponent_opmon.moves[enemy_move].move(self, opponent_opmon, player_opmon)

	# 🔥 Esto faltaba
	_next_action()

# Ejecuta el movimiento del jugador tras un ataque previo del enemigo
func _player_execute_after_enemy(player_move_id: int):
	# chequeos de seguridad
	if player_opmon == null or opponent_opmon == null:
		return
	if player_opmon.is_ko() or opponent_opmon.is_ko():
		return

	# Ejecuta el movimiento del jugador (se añadirá a la cola)
	_player_in_action = true
	player_opmon.moves[player_move_id].move(self, player_opmon, opponent_opmon)



# Calls the next action to show, and ends the turn if there is no more actions to show
func _next_action():
	if _action_queue.is_empty():
		call_deferred("show_base_dialog")
	else:
		var action = _action_queue.pop_front()
		callv(action["method"], action["parameters"])

func show_base_dialog():
	$BaseDialog.visible = true

func _update_hp_label():
	# Player HP label
	$PlayerInfobox/HPLabel.text = str(int($PlayerInfobox/HP.value)) + " / " + str(player_opmon.stats[Stats.HP])

	# Enemy HP label
	$OpponentInfobox/HPLabel.text = str(int($OpponentInfobox/HP.value)) + " / " + str(opponent_opmon.stats[Stats.HP])
	
	
func ko():

	if player_opmon.is_ko():

		add_dialog([player_opmon.species.name + " fainted!"])

		if player_team.next_available() != null:
			_load_opmon(player_team.next_available(), true)
		else:
			_action_queue.append({"method": "_ko", "parameters":[]})

	else:

		add_dialog([opponent_opmon.species.name + " fainted!"])

		if opponent_team.next_available() != null:
			_load_opmon(opponent_team.next_available(), false)
		else:
			_action_queue.append({"method": "_ko", "parameters":[]})


###################
###################
# Methods queuing actions
###################
###################


# The "text" parameter must be an array of Strings where one element is printed on one dialog.
# Make sure the text is not too long to be shown.
func add_dialog(text: Array):
	_action_queue.append({"method": "_dialog", "parameters": [text]})
	$TextDialog.show()
	await $TextDialog.dialog_over 
	
# is_self: if the updated hp has to be the acting opmon’s bar (true) or the opponent’s one (false)
# new value: the new value of the hp bar.
# Reemplaza la antigua función update_hp(...)
# Ahora recibe target_is_player: si true -> actualiza barra del jugador, si false -> del oponente
func update_hp_target(target_is_player: bool, new_value: int):
	_action_queue.append({"method": "_update_hp", "parameters": [target_is_player, new_value]})
		
const stat_names = {
	Stats.ATK : "STAT_CHANGE_ATK",
	Stats.DEF : "STAT_CHANGE_DEF",
	Stats.ATKSPE : "STAT_CHANGE_ATKSPE",
	Stats.DEFSPE : "STAT_CHANGE_DEFSPE",
	Stats.SPE : "STAT_CHANGE_SPE",
	Stats.EVA : "STAT_CHANGE_EVA",
	Stats.HP : "STAT_CHANGE_HP",
	Stats.ACC : "STAT_CHANGE_ACC"
}

# Note: good idea to add lines for every possible changes
# but you forgot to take into account the fact that
# it can change from -12 to +12 if the stats
# has already been modified
# Todo: take this into account later
# const change_texts = {
#	-6 : "reached rock bottom",
#	-5 : "completely dropped",
#	-4 : "has drastically lowered",
#	-3 : "has hugely lowered",
#	-2 : "has highly lowered",
#	-1 : "has lowered",
#	0 : "is inchanged",
#	1 : "has increased",
#	2 : "has highly increased",
#	3 : "has hugely increased",
#	4 : "has drastically increased",
#	5 : "has exploded",
#	6 : "breached the roof"
#}

func stat_changed(target: OpMon, stat: Stats, change: int) -> void:
	var changed_string = tr("STAT_CHANGE_DIALOG").replace("{opmon}", target.species.name).replace("{stat}", tr(stat_names[stat])).replace("{change}", tr(("STAT_CHANGE_LOWER" if change < 0 else "STAT_CHANGE_HIGHER")))
	add_dialog([changed_string])

func heal(target: OpMon, hp_gained: int) -> void:
	var heal_string = ""
	if target.hp == target.stats[Stats.HP]:
		heal_string = tr("HEAL_FULL_DIALOG").replace("{opmon}", target.species.name)
	else:
		heal_string = tr("HEAL_PARTIAL_DIALOG").replace("{opmon}", target.species.name).replace("{hp}", String.num(hp_gained))	
	add_dialog([heal_string])

func move_failed():
	add_dialog([tr("BATTLE_MOVE_FAILED")])

const effectiveness_texts = {
	0.0 : "MOVE_EFFECTIVENESS_NONE",
	0.25 : "MOVE_EFFECTIVENESS_VERYLOW",
	0.5 : "MOVE_EFFECTIVENESS_LOW",
	2.0 : "MOVE_EFFECTIVENESS_HIGH",
	4.0 : "MOVE_EFFECTIVENESS_VERYHIGH"
}

func effectiveness(factor: float):
	if factor != 1.0:
		add_dialog([tr(effectiveness_texts[factor])])


func animate_move(transforms: Array):
	for transform in transforms:
		_action_queue.append({
			"method": "_animate_move",
			"parameters": [_player_in_action, transform.duplicate()]
		})

func close():
	_action_queue.append({"method": "_close", "parameters": []})

func switch_opmon(new_opmon: int):
	var old_opmon_name = player_opmon.species.name if _player_in_action else opponent_opmon.species.name
	var team = player_team if _player_in_action else opponent_team
	add_dialog([tr("BATTLE_OPMON_CHANGE").replace("{opmon1}", old_opmon_name).replace("{opmon2}", team.get_opmon(new_opmon).species.name)])
	_action_queue.append({"method": "_switch_opmon", "parameters": [_player_in_action, new_opmon, team.get_opmon(new_opmon).hp]})

###################
###################
# Methods executing actions
# Every action must, by one way or another, call back _next_action to continue the chain
###################
###################


# Calls _next_action via $TextDialog whose signal "dialog_over" is connected to _next_action
func _dialog(text):
	print("SHOWING DIALOG:", text)
	$BaseDialog.hide()
	$TextDialog.show()
	$TextDialog.reset()
	$TextDialog.set_dialog_lines(text)
	$TextDialog.go()
	
func _animate_move(player: bool, animation_name: String):

	var anim_player: AnimationPlayer

	if player:
		anim_player = $PlayerOpMon/AnimationPlayer
	else:
		anim_player = $OpponentOpMon/AnimationPlayer

	if not anim_player.has_animation(animation_name):
		print("Animación no existe:", animation_name)
		_next_action()
		return

	anim_player.play(animation_name)
	await anim_player.animation_finished

	_next_action()

# Calls _next_action via the animation player whose signal "animation_finished" is connected to "_health_bar_stop"
func _update_hp(player: bool, new_value: int):
	var hpbar:TextureProgressBar = $PlayerInfobox/HP if player else $OpponentInfobox/HP
	
	var tween := create_tween()
	tween.tween_property(hpbar, "value", new_value, 1)
	tween.tween_callback(Callable(self, "_health_bar_stop"))
	
	_hp_bar_animated = true
	tween.play()
	
# Calls _next_action for _update_hp
func _health_bar_stop():
	_hp_bar_animated = false
	_next_action()
	
# Always the last action by construction since added after the calculations
# and stops them if added
func _ko():

	if player_team.is_ko() or opponent_team.is_ko():
		emit_signal("closed")
		return

	if opponent_opmon.is_ko():
		var next_enemy = opponent_team.next_available()

		if next_enemy != null:
			add_dialog(["Enemy sent out " + next_enemy.species.name + "!"])
			_load_opmon(next_enemy, false)

	_next_action()

func _close():
	emit_signal("closed")
