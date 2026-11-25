class_name PhysicsEventContext
extends RefCounted

var speed: float = 0.0
var lateral_speed: float = 0.0
var tilt_deg: float = 0.0
var mass: float = 1.5
var momentum: float = 0.0
var kinetic_energy: float = 0.0
var vertical_impact: float = 0.0
var impact_normal: Vector3 = Vector3.UP
var world_pos: Vector3 = Vector3.ZERO
var combo_stacks: int = 0
var chain_depth: int = 0


static func create(
	p_speed: float,
	p_lateral_speed: float,
	p_tilt_deg: float,
	p_mass: float,
	p_vertical_impact: float = 0.0,
	p_impact_normal: Vector3 = Vector3.UP,
	p_world_pos: Vector3 = Vector3.ZERO,
	p_combo_stacks: int = 0,
	p_chain_depth: int = 0
) -> PhysicsEventContext:
	var ctx := PhysicsEventContext.new()
	ctx.speed = maxf(0.0, p_speed)
	ctx.lateral_speed = p_lateral_speed
	ctx.tilt_deg = p_tilt_deg
	ctx.mass = maxf(0.1, p_mass)
	ctx.momentum = ctx.mass * ctx.speed
	ctx.kinetic_energy = 0.5 * ctx.mass * ctx.speed * ctx.speed
	ctx.vertical_impact = absf(p_vertical_impact)
	ctx.impact_normal = p_impact_normal.normalized() if p_impact_normal.length_squared() > 0.0001 else Vector3.UP
	ctx.world_pos = p_world_pos
	ctx.combo_stacks = maxi(0, p_combo_stacks)
	ctx.chain_depth = maxi(0, p_chain_depth)
	return ctx
