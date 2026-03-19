extends Resource
class_name ItemEffect

var dialog = null

func apply_overworld(_map_manager) -> bool:
	return false

func apply_opmon_overworld(_map_manager, _user) -> bool:
	return false
