class_name UpgradeCatalog
extends RefCounted

var _upgrades: Array[UpgradeDefinition] = []
var _by_id: Dictionary = {}


func _init() -> void:
	_register_initial_12()


func _register(def: UpgradeDefinition) -> void:
	_upgrades.append(def)
	_by_id[def.id] = def


func get_all_upgrades() -> Array[UpgradeDefinition]:
	return _upgrades.duplicate()


func get_upgrade(upgrade_id: String) -> UpgradeDefinition:
	return _by_id.get(upgrade_id, null)


func roll_draft_choices(
	rng: RandomNumberGenerator,
	count: int,
	owned_ids: Array[String]
) -> Array[UpgradeDefinition]:
	var pool: Array[UpgradeDefinition] = []
	for def in _upgrades:
		if not def.stackable and owned_ids.has(def.id):
			continue
		pool.append(def)

	var picked: Array[UpgradeDefinition] = []
	var target_count := mini(count, pool.size())
	for _i in range(target_count):
		var total_w := 0.0
		for candidate in pool:
			total_w += candidate.rarity_weight()
		var ticket := rng.randf_range(0.0, total_w)
		var accum := 0.0
		var chosen_idx := 0
		for idx in range(pool.size()):
			accum += pool[idx].rarity_weight()
			if ticket <= accum:
				chosen_idx = idx
				break
		picked.append(pool[chosen_idx])
		pool.remove_at(chosen_idx)
	return picked


func _register_initial_12() -> void:
	# === Layer 1: Chassis (底盘常数与乘区卡) ===
	_register(
		UpgradeDefinition.new(
			"tungsten_core",
			"实心钨核",
			"common",
			"chassis",
			"质量 ×1.65，冲撞障碍时的前向减速损耗降低 50%（直接放大动量 P 与碾压优势）。"
		)
		.with_mult("mass", 0.65)
		.with_mult("smash_speed_loss_mult", -0.50)
	)

	_register(
		UpgradeDefinition.new(
			"vulcan_rubber",
			"高弹硫化胶",
			"common",
			"chassis",
			"弹性恢复系数 +0.55，落地与擦墙反弹保留更多动能。"
		)
		.with_flat("bounce", 0.55)
	)

	_register(
		UpgradeDefinition.new(
			"maglev_shell",
			"超导磁浮壳",
			"common",
			"chassis",
			"滚动线性阻尼降低 55%，且完全免疫粘液减速带。"
		)
		.with_mult("linear_damp", -0.55)
		.with_flag("immune_slime_damp")
	)

	_register(
		UpgradeDefinition.new(
			"giant_field",
			"巨球力场",
			"rare",
			"chassis",
			"球体半径 ×1.35，基础质量 +0.8kg，同步放大所有衍生冲击波半径。"
		)
		.with_mult("radius", 0.35)
		.with_flat("mass", 0.8)
	)

	# === Layer 2: Converters (物理状态转化器卡) ===
	_register(
		UpgradeDefinition.new(
			"quake_refractor",
			"震地折射器",
			"rare",
			"converter",
			"腾空落地时，将垂直砸地冲量的 55% 折射为前向冲刺，并释放环形震荡波。"
		)
		.with_hook("on_land", _hook_quake_refractor)
	)

	_register(
		UpgradeDefinition.new(
			"kinetic_furnace",
			"动能殉爆炉",
			"rare",
			"converter",
			"强力撞飞路障时按实时动能 √Ek 释放物理爆炸气浪，掀翻周围障碍并顺风推射自身。"
		)
		.with_hook("on_smash_target", _hook_kinetic_furnace)
	)

	_register(
		UpgradeDefinition.new(
			"tail_thruster",
			"侧喷尾流喷口",
			"common",
			"converter",
			"左右侧向推力 ×1.35；按住侧推持续变道时，将横向速度持续转化为前向推力。"
		)
		.with_mult("tilt_lateral_force_mult", 0.35)
		.with_hook("on_physics_tick", _hook_tail_thruster)
	)

	_register(
		UpgradeDefinition.new(
			"tailwind_sail",
			"顺风帆装甲",
			"common",
			"chassis",
			"受到加速带、缓冲桩、顺风/上升风场与爆炸气浪作用时，获得的有利推进力 ×1.75。"
		)
		.with_mult("external_boost_mult", 0.75)
	)

	_register(
		UpgradeDefinition.new(
			"smash_chrono",
			"碎障续秒器",
			"rare",
			"converter",
			"每累计触发 4 次有效破障冲撞，倒计时立即 +1.5 秒并爆发一次前向提速脉冲。"
		)
		.with_hook("on_smash_target", _hook_smash_chrono)
	)

	# === Layer 3: Rule Breakers & Global Multipliers (规则篡改与全局乘区卡) ===
	_register(
		UpgradeDefinition.new(
			"vector_refractor",
			"矢量折射核心",
			"legendary",
			"rule_breaker",
			"【唯一】撞击护栏或缓冲桩反弹时，将法线碰撞冲量的 80% 强制偏转为前向速度。",
			false
		)
		.with_flag("vector_refract_bounce")
		.with_hook("on_wall_or_bumper_bounce", _hook_vector_refractor)
	)

	_register(
		UpgradeDefinition.new(
			"momentum_overload",
			"动量过载引擎",
			"legendary",
			"rule_breaker",
			"【唯一】每次有效撞飞、落地或反弹叠 1 层过载（最高 20 层），每层使所有词条冲量输出 +12%。",
			false
		)
		.with_flag("overload_engine")
	)

	_register(
		UpgradeDefinition.new(
			"twin_resonance",
			"双相共振仪",
			"legendary",
			"rule_breaker",
			"【唯一】所有物理状态转化器触发时额外结算 1 次（转化收益翻倍）。",
			false
		)
		.with_flag("twin_resonance")
	)


static func _hook_quake_refractor(
	ctx: PhysicsEventContext,
	bus: PhysicsSynergyBus,
	count: int,
	out: Dictionary,
	_delta: float
) -> void:
	var mult := bus.get_effective_impulse_mult() * float(count)
	var vertical_j := ctx.mass * ctx.vertical_impact
	out["forward_impulse"] = float(out["forward_impulse"]) + 0.55 * vertical_j * mult
	if ctx.chain_depth < PhysicsSynergyBus.MAX_CHAIN_DEPTH:
		var radius := 4.5 * bus.stats.get_stat("shockwave_radius_mult")
		var force := (12.0 * ctx.mass + 0.35 * vertical_j) * mult
		(out["shockwaves"] as Array).append({
			"origin": ctx.world_pos,
			"radius": radius,
			"force": force,
			"chain_depth": ctx.chain_depth + 1,
		})


static func _hook_kinetic_furnace(
	ctx: PhysicsEventContext,
	bus: PhysicsSynergyBus,
	count: int,
	out: Dictionary,
	_delta: float
) -> void:
	var mult := bus.get_effective_impulse_mult() * float(count)
	var root_ek := sqrt(maxf(0.0, ctx.kinetic_energy))
	var self_push := (4.5 + 0.9 * root_ek) * mult * bus.stats.get_stat("external_boost_mult")
	out["forward_impulse"] = float(out["forward_impulse"]) + self_push
	if ctx.chain_depth < PhysicsSynergyBus.MAX_CHAIN_DEPTH:
		var radius := 5.5 * bus.stats.get_stat("shockwave_radius_mult")
		var force := (12.0 + 2.2 * root_ek) * mult
		(out["shockwaves"] as Array).append({
			"origin": ctx.world_pos,
			"radius": radius,
			"force": force,
			"chain_depth": ctx.chain_depth + 1,
		})


static func _hook_tail_thruster(
	ctx: PhysicsEventContext,
	bus: PhysicsSynergyBus,
	count: int,
	out: Dictionary,
	delta: float
) -> void:
	if absf(ctx.tilt_deg) <= 0.1 or delta <= 0.0:
		return
	var mult := bus.get_effective_impulse_mult() * float(count)
	var thrust := (6.5 + 0.85 * absf(ctx.lateral_speed)) * ctx.mass * delta * mult
	out["forward_impulse"] = float(out["forward_impulse"]) + thrust


static func _hook_smash_chrono(
	ctx: PhysicsEventContext,
	bus: PhysicsSynergyBus,
	count: int,
	out: Dictionary,
	_delta: float
) -> void:
	var hits := int(bus.runtime_counters.get("smash_chrono_hits", 0)) + 1
	if hits >= 4:
		hits -= 4
		out["bonus_time"] = float(out["bonus_time"]) + 1.5 * float(count)
		var mult := bus.get_effective_impulse_mult() * float(count)
		out["forward_impulse"] = float(out["forward_impulse"]) + 10.0 * ctx.mass * mult
	bus.runtime_counters["smash_chrono_hits"] = hits


static func _hook_vector_refractor(
	ctx: PhysicsEventContext,
	bus: PhysicsSynergyBus,
	_count: int,
	out: Dictionary,
	_delta: float
) -> void:
	var mult := bus.get_effective_impulse_mult()
	var normal_speed := maxf(absf(ctx.lateral_speed), ctx.speed * 0.45)
	var refracted_j := 0.80 * normal_speed * ctx.mass * mult
	out["forward_impulse"] = float(out["forward_impulse"]) + refracted_j
