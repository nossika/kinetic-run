class_name UpgradeDefinition
extends RefCounted

var id: String = ""
var title: String = ""
var rarity: String = "common" # common | rare | legendary
var layer: String = "chassis" # chassis | converter | rule_breaker
var description: String = ""
var stackable: bool = true
var stat_flats: Dictionary = {}
var stat_mults: Dictionary = {}
var flags: Array[String] = []
var hooks: Dictionary = {}


func _init(
	p_id: String = "",
	p_title: String = "",
	p_rarity: String = "common",
	p_layer: String = "chassis",
	p_desc: String = "",
	p_stackable: bool = true
) -> void:
	id = p_id
	title = p_title
	rarity = p_rarity
	layer = p_layer
	description = p_desc
	stackable = p_stackable


func with_flat(stat_key: String, amount: float) -> UpgradeDefinition:
	stat_flats[stat_key] = float(stat_flats.get(stat_key, 0.0)) + amount
	return self


func with_mult(stat_key: String, ratio: float) -> UpgradeDefinition:
	stat_mults[stat_key] = float(stat_mults.get(stat_key, 0.0)) + ratio
	return self


func with_flag(flag_name: String) -> UpgradeDefinition:
	if not flags.has(flag_name):
		flags.append(flag_name)
	return self


func with_hook(event_name: String, callback: Callable) -> UpgradeDefinition:
	hooks[event_name] = callback
	return self


func rarity_weight() -> float:
	match rarity:
		"common":
			return 60.0
		"rare":
			return 30.0
		"legendary":
			return 12.0
		_:
			return 20.0
