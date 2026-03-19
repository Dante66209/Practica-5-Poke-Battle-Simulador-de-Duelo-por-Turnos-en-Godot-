extends ItemEffect
class_name Heal

@export var hp: int

func _init(p_hp := 0):
	hp = p_hp

func apply_opmon_battle(battle_scene: BattleScene, user: OpMon) -> bool:
	user.hp += hp
	battle_scene.heal(user, hp)
	return true
	
func apply_opmon_overworld(_map_manager, user: OpMon) -> bool:
	user.hp += hp
	return true
