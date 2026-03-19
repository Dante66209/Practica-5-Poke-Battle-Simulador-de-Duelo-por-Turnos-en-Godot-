extends Resource
class_name Item

var id = ""
var applies_to_opmon = false
var consumes = false
var effect_used: Array = []

func _init(p_id = "", p_applies_to_opmon = false, p_consumes = false, p_effect_used: Array = []):
	id = p_id
	applies_to_opmon = p_applies_to_opmon
	consumes = p_consumes
	effect_used = p_effect_used

func apply_overworld(_map_manager) -> bool:
	return false

func apply_opmon_overworld(_map_manager, _user) -> bool:
	return false
