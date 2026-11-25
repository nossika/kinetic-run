class_name PhysicsSynergyBus
extends RefCounted

const MAX_CHAIN_DEPTH: int = 3
const MAX_OVERLOAD_STACKS: int = 20
const OVERLOAD_STACK_MULT: float = 0.12
const OVERLOAD_IDLE_GRACE: float = 2.5
const OVERLOAD_DECAY_INTERVAL: float = 0.5
const MAX_SINGLE_DISPATCH_DELTA_V: float = 45.0

var stats: StatSheet = StatSheet.new()
var combo_stacks: int = 0
var runtime_counters: Dictionary = {}

var _upgrade_defs: Dictionary = {}
var _upgrade_counts: Dictionary = {}
var _combo_idle_timer: float = 0.0
var _combo_decay_accum: float = 0.0


func reset_all() -> void:
	_upgrade_defs.clear()
	_upgrade_counts.clear()
	runtime_counters.clear()
	combo_stacks = 0
	_combo_idle_timer = 0.0
	_combo_decay_accum = 0.0
	stats.reset_modifiers()


func reset_level_transient() -> void:
	combo_stacks = 0
	_combo_idle_timer = 0.0
	_combo_decay_accum = 0.0


func apply_upgrade(def: UpgradeDefinition) -> void:
	if def == null or def.id == "":
		return
	if not def.stackable and int(_upgrade_counts.get(def.id, 0)) >= 1:
		return
	_upgrade_defs[def.id] = def
	_upgrade_counts[def.id] = int(_upgrade_counts.get(def.id, 0)) + 1
	rebuild_stats()


func get_upgrade_count(upgrade_id: String) -> int:
	return int(_upgrade_counts.get(upgrade_id, 0))


func get_active_upgrades() -> Array[UpgradeDefinition]:
	var result: Array[UpgradeDefinition] = []
	for key in _upgrade_defs.keys():
		result.append(_upgrade_defs[key])
	return result


func rebuild_stats() -> void:
	stats.reset_modifiers()
	for id_key in _upgrade_defs.keys():
		var def: UpgradeDefinition = _upgrade_defs[id_key]
		var count: int = int(_upgrade_counts.get(id_key, 1))
		for stat_k in def.stat_flats.keys():
			stats.add_flat(stat_k, float(def.stat_flats[stat_k]) * float(count))
		for stat_k in def.stat_mults.keys():
			for _i in range(count):
				stats.add_mult(stat_k, float(def.stat_mults[stat_k]))
		for flag_name in def.flags:
			stats.set_flag(flag_name, true)


func get_effective_impulse_mult() -> float:
	var mult := stats.get_stat("impulse_output_mult")
	if stats.has_flag("overload_engine") and combo_stacks > 0:
		mult *= (1.0 + OVERLOAD_STACK_MULT * float(combo_stacks))
	return mult


func _add_overload_stack() -> void:
	if not stats.has_flag("overload_engine"):
		return
	combo_stacks = mini(MAX_OVERLOAD_STACKS, combo_stacks + 1)
	_combo_idle_timer = 0.0
	_combo_decay_accum = 0.0


func on_physics_tick(ctx: PhysicsEventContext, delta: float) -> Dictionary:
	if stats.has_flag("overload_engine") and combo_stacks > 0:
		_combo_idle_timer += delta
		if _combo_idle_timer >= OVERLOAD_IDLE_GRACE:
			_combo_decay_accum += _combo_idle_timer - OVERLOAD_IDLE_GRACE if _combo_idle_timer - delta < OVERLOAD_IDLE_GRACE else delta
			while _combo_decay_accum >= OVERLOAD_DECAY_INTERVAL and combo_stacks > 0:
				combo_stacks -= 1
				_combo_decay_accum -= OVERLOAD_DECAY_INTERVAL
	return _dispatch_event("on_physics_tick", ctx, delta)


func on_land(ctx: PhysicsEventContext) -> Dictionary:
	if ctx.chain_depth == 0:
		_add_overload_stack()
	return _dispatch_event("on_land", ctx, 0.0)


func on_wall_or_bumper_bounce(ctx: PhysicsEventContext) -> Dictionary:
	if ctx.chain_depth == 0:
		_add_overload_stack()
	return _dispatch_event("on_wall_or_bumper_bounce", ctx, 0.0)


func on_smash_target(ctx: PhysicsEventContext) -> Dictionary:
	if ctx.chain_depth == 0:
		_add_overload_stack()
	return _dispatch_event("on_smash_target", ctx, 0.0)


func on_boost_pad(ctx: PhysicsEventContext) -> Dictionary:
	return _dispatch_event("on_boost_pad", ctx, 0.0)


func _dispatch_event(event_name: String, ctx: PhysicsEventContext, delta: float) -> Dictionary:
	var out: Dictionary = {
		"forward_impulse": 0.0,
		"shockwaves": [],
		"bonus_time": 0.0,
	}

	var converter_repeats := 1
	if stats.has_flag("twin_resonance"):
		converter_repeats += maxi(1, get_upgrade_count("twin_resonance"))

	for id_key in _upgrade_defs.keys():
		var def: UpgradeDefinition = _upgrade_defs[id_key]
		if not def.hooks.has(event_name):
			continue
		var count: int = int(_upgrade_counts.get(id_key, 1))
		var runs := converter_repeats if def.layer == "converter" else 1
		var cb: Callable = def.hooks[event_name]
		for _r in range(runs):
			cb.call(ctx, self, count, out, delta)

	if ctx.chain_depth >= MAX_CHAIN_DEPTH:
		(out["shockwaves"] as Array).clear()

	var max_impulse := MAX_SINGLE_DISPATCH_DELTA_V * maxf(0.1, ctx.mass)
	out["forward_impulse"] = clampf(float(out["forward_impulse"]), 0.0, max_impulse)
	return out
