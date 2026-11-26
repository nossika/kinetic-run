class_name RunState
extends RefCounted

const BASE_LEVEL_TIME: float = 30.0
const MAX_LEVEL_TIME: float = 45.0

var current_level: int = 1
var time_remaining: float = BASE_LEVEL_TIME
var owned_upgrade_ids: Array[String] = []
var peak_speed_kmh: float = 0.0
var max_kinetic_energy: float = 0.0
var total_smashed: int = 0
var run_seed: int = 0
var seed_text: String = ""


static func _splitmix32(x: int) -> int:
	var z := (x + 0x9E3779B9) & 0x7FFFFFFF
	z = ((z ^ (z >> 15)) * 0x85EBCA6B) & 0x7FFFFFFF
	z = ((z ^ (z >> 13)) * 0xC2B2AE35) & 0x7FFFFFFF
	z = (z ^ (z >> 16)) & 0x7FFFFFFF
	return maxi(1, z)


static func parse_seed_input(raw_text: String) -> Dictionary:
	var cleaned := raw_text.strip_edges()
	if cleaned == "":
		var auto_seed := 100000 + int(Time.get_ticks_usec() % 900000)
		return {"seed": auto_seed, "text": str(auto_seed)}
	if cleaned.is_valid_int():
		var digits := cleaned.trim_prefix("-").trim_prefix("+").lstrip("0")
		if digits.length() <= 18:
			var val := maxi(1, absi(int(cleaned)) & 0x7FFFFFFF)
			return {"seed": val, "text": cleaned}
	var bytes := cleaned.to_utf8_buffer()
	var h: int = 2166136261
	for b in bytes:
		h = ((h ^ int(b)) * 16777619) & 0x7FFFFFFF
	return {"seed": maxi(1, h), "text": cleaned}


static func derive_track_seed(p_run_seed: int, level: int) -> int:
	var safe_seed := p_run_seed & 0x7FFFFFFF
	var safe_level := maxi(1, level) & 0x7FFFFFFF
	return _splitmix32((safe_seed * 31 + safe_level * 7919 + 0x13572468) & 0x7FFFFFFF)


static func derive_draft_seed(p_run_seed: int, cleared_level: int) -> int:
	var safe_seed := p_run_seed & 0x7FFFFFFF
	var safe_level := maxi(1, cleared_level) & 0x7FFFFFFF
	return _splitmix32((safe_seed * 53 + safe_level * 104729 + 0x24681357) & 0x7FFFFFFF)


static func derive_starter_ball_seed(p_run_seed: int) -> int:
	var safe_seed := p_run_seed & 0x7FFFFFFF
	return _splitmix32((safe_seed * 73 + 0x35791357) & 0x7FFFFFFF)


static func target_length_for_level(level: int) -> float:
	var clamped_lvl := maxi(1, level)
	var step := clamped_lvl - 1
	@warning_ignore("integer_division")
	var milestone_bonus := (step / 3) * 25
	return float(130 + step * 55 + milestone_bonus)


func start_new_run(seed_val: int = 0) -> void:
	current_level = 1
	time_remaining = BASE_LEVEL_TIME
	owned_upgrade_ids.clear()
	peak_speed_kmh = 0.0
	max_kinetic_energy = 0.0
	total_smashed = 0
	if seed_val > 0:
		run_seed = maxi(1, seed_val & 0x7FFFFFFF)
		seed_text = str(run_seed)
	else:
		var parsed := parse_seed_input("")
		run_seed = int(parsed["seed"])
		seed_text = String(parsed["text"])


func start_new_run_from_text(raw_text: String) -> void:
	var parsed := parse_seed_input(raw_text)
	start_new_run(int(parsed["seed"]))
	seed_text = String(parsed["text"])


func begin_level(level: int) -> void:
	current_level = maxi(1, level)
	time_remaining = BASE_LEVEL_TIME


func tick_timer(delta: float) -> bool:
	time_remaining = maxf(0.0, time_remaining - maxf(0.0, delta))
	return time_remaining <= 0.0


func add_bonus_time(seconds: float) -> void:
	if seconds <= 0.0:
		return
	time_remaining = minf(MAX_LEVEL_TIME, time_remaining + seconds)


func record_upgrade(upgrade_id: String) -> void:
	owned_upgrade_ids.append(upgrade_id)


func record_smash(count: int = 1) -> void:
	total_smashed += maxi(0, count)


func record_physics_sample(speed_mps: float, kinetic_energy: float) -> void:
	var kmh := speed_mps * 3.6
	if kmh > peak_speed_kmh:
		peak_speed_kmh = kmh
	if kinetic_energy > max_kinetic_energy:
		max_kinetic_energy = kinetic_energy
