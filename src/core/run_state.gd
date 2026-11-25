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
	run_seed = seed_val if seed_val != 0 else int(Time.get_ticks_usec() & 0x7FFFFFFF)


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
