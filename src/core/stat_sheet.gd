class_name StatSheet
extends RefCounted

const BASE_RADIUS: float = 0.55

const STAT_DEFS: Dictionary = {
	"mass": {"base": 1.5, "min": 0.5, "max": 15.0},
	"radius": {"base": 0.55, "min": 0.35, "max": 1.6},
	"bounce": {"base": 0.25, "min": 0.0, "max": 1.0},
	"linear_damp": {"base": 0.35, "min": 0.02, "max": 5.0},
	"forward_drive_mult": {"base": 1.0, "min": 0.2, "max": 6.0},
	"max_tilt_deg": {"base": 35.0, "min": 20.0, "max": 55.0},
	"tilt_lateral_force_mult": {"base": 1.0, "min": 0.5, "max": 4.0},
	"air_gravity_scale": {"base": 1.0, "min": 0.25, "max": 3.0},
	"smash_speed_loss_mult": {"base": 1.0, "min": 0.0, "max": 1.0},
	"external_boost_mult": {"base": 1.0, "min": 0.5, "max": 5.0},
	"impulse_output_mult": {"base": 1.0, "min": 0.2, "max": 12.0},
	"shockwave_radius_mult": {"base": 1.0, "min": 0.5, "max": 5.0},
}

var _base_overrides: Dictionary = {}
var _flats: Dictionary = {}
var _mults: Dictionary = {}
var _flags: Dictionary = {}


func reset_modifiers() -> void:
	_base_overrides.clear()
	_flats.clear()
	_mults.clear()
	_flags.clear()


func set_base_override(key: String, value: float) -> void:
	if not STAT_DEFS.has(key):
		push_warning("Unknown stat key: %s" % key)
		return
	var def: Dictionary = STAT_DEFS[key]
	_base_overrides[key] = clampf(value, float(def["min"]), float(def["max"]))


func clear_base_overrides() -> void:
	_base_overrides.clear()


func add_flat(key: String, amount: float) -> void:
	if not STAT_DEFS.has(key):
		push_warning("Unknown stat key: %s" % key)
		return
	_flats[key] = float(_flats.get(key, 0.0)) + amount


func add_mult(key: String, ratio: float) -> void:
	if not STAT_DEFS.has(key):
		push_warning("Unknown stat key: %s" % key)
		return
	if not _mults.has(key):
		_mults[key] = []
	var list: Array = _mults[key]
	list.append(ratio)


func set_flag(flag: String, enabled: bool = true) -> void:
	if enabled:
		_flags[flag] = true
	else:
		_flags.erase(flag)


func has_flag(flag: String) -> bool:
	return bool(_flags.get(flag, false))


func get_stat(key: String) -> float:
	if not STAT_DEFS.has(key):
		push_warning("Unknown stat key: %s" % key)
		return 0.0

	var def: Dictionary = STAT_DEFS[key]
	var base_val: float = float(_base_overrides.get(key, def["base"]))
	var raw_val: float = base_val + float(_flats.get(key, 0.0))
	if _mults.has(key):
		var list: Array = _mults[key]
		for ratio in list:
			raw_val *= maxf(0.0, 1.0 + float(ratio))

	if key == "shockwave_radius_mult":
		var current_radius := get_stat("radius")
		raw_val *= sqrt(current_radius / BASE_RADIUS)

	return clampf(raw_val, float(def["min"]), float(def["max"]))
