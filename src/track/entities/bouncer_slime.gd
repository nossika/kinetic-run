class_name BouncerSlime
extends RigidBody3D

const ABYSS_LOCAL_Y: float = -28.0
const MAX_SHOCKWAVE_SPEED: float = 32.0
const DISLODGE_IMPULSE: float = 2.2

var weight_label: String = "3kg"
var patrol_half_width: float = 2.8
var patrol_speed: float = 2.6
var is_patrolling: bool = true
var is_dislodged: bool = false
var has_yielded_smash: bool = false
var min_smash_impulse: float = 3.2

var _origin_pos: Vector3 = Vector3.ZERO
var _origin_captured: bool = false
var _patrol_x: float = 0.0
var _patrol_y: float = 0.0
var _dir: float = 1.0
var _anim_time: float = 0.0
var _bounce_squash: float = 0.0
var _visual_root: Node3D = null
var _queued_shockwave_dv: float = 0.0


func _init() -> void:
	mass = 3.0
	physics_material_override = MaterialLibrary.high_friction_physics(0.45, 0.88)
	set_meta("weight_label", weight_label)


func _ready() -> void:
	_origin_pos = position
	_patrol_x = position.x
	_patrol_y = position.y
	_origin_captured = true

	mass = 3.0
	physics_material_override = MaterialLibrary.high_friction_physics(0.45, 0.88)
	freeze = false
	can_sleep = false
	lock_rotation = is_patrolling
	gravity_scale = 0.0 if is_patrolling else 1.0
	linear_damp = 0.0 if is_patrolling else 0.12
	angular_damp = 0.20
	contact_monitor = true
	max_contacts_reported = 4

	var col := CollisionShape3D.new()
	var s_shape := SphereShape3D.new()
	s_shape.radius = 0.66
	col.shape = s_shape
	add_child(col)

	_build_slime_visuals()
	MaterialLibrary.attach_weight_labels(self, "3kg", Vector3(1.32, 1.18, 1.32), Color(0.24, 0.44, 0.32))
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _build_slime_visuals() -> void:
	_visual_root = Node3D.new()
	_visual_root.name = "VisualRoot"
	add_child(_visual_root)
	ClayMeshBuilder.attach_clay_eyes(_visual_root, Vector3(0.0, 0.08, 0.56), 0.25, 0.065, true, false, self)
	if DisplayServer.get_name() == "headless":
		return

	var outer_inst := MeshInstance3D.new()
	outer_inst.name = "OuterJelly"
	var outer_sphere := SphereMesh.new()
	outer_sphere.radius = 0.65
	outer_sphere.height = 1.14
	outer_sphere.radial_segments = 28
	outer_sphere.rings = 16
	outer_sphere.material = MaterialLibrary.make_jelly_outer_material(Color(0.14, 0.82, 0.42))
	RenderHelper.attach_mesh(outer_inst, outer_sphere)
	_visual_root.add_child(outer_inst)

	var core_inst := MeshInstance3D.new()
	core_inst.name = "InnerCore"
	var core_sphere := SphereMesh.new()
	core_sphere.radius = 0.36
	core_sphere.height = 0.64
	core_sphere.radial_segments = 20
	core_sphere.rings = 12
	core_sphere.material = MaterialLibrary.make_jelly_core_material(Color(0.40, 0.96, 0.58))
	RenderHelper.attach_mesh(core_inst, core_sphere)
	_visual_root.add_child(core_inst)


func _physics_process(delta: float) -> void:
	_queued_shockwave_dv = 0.0
	_anim_time += delta
	_bounce_squash = maxf(0.0, _bounce_squash - delta * 4.5)

	if _visual_root != null:
		var breathe := sin(_anim_time * 5.2) * 0.06
		var pulse := sin(_bounce_squash * PI * 3.0) * _bounce_squash * 0.34
		var sy := clampf(1.0 + breathe - pulse, 0.62, 1.35)
		var sxz := 1.0 / sqrt(sy)
		_visual_root.scale = Vector3(sxz, sy, sxz)

	if not _origin_captured:
		_origin_pos = position
		_patrol_x = position.x
		_patrol_y = position.y
		_origin_captured = true

	if is_patrolling:
		var horiz_impulse := mass * Vector2(linear_velocity.x, linear_velocity.z).length()
		if horiz_impulse >= DISLODGE_IMPULSE or mass * linear_velocity.length() >= 2.6:
			_bounce_squash = 1.0
			dislodge()
		else:
			if position.y > _patrol_y and (position.y - _origin_pos.y) < 0.08:
				_patrol_y = position.y
			if patrol_half_width > 0.1:
				_patrol_x += _dir * patrol_speed * delta
				if _patrol_x > _origin_pos.x + patrol_half_width:
					_patrol_x = _origin_pos.x + patrol_half_width
					_dir = -1.0
				elif _patrol_x < _origin_pos.x - patrol_half_width:
					_patrol_x = _origin_pos.x - patrol_half_width
					_dir = 1.0
			position = Vector3(_patrol_x, _patrol_y, _origin_pos.z)
			linear_velocity = Vector3.ZERO
			angular_velocity = Vector3.ZERO

	if get_parent() is Node3D and position.y < ABYSS_LOCAL_Y:
		queue_free()


func dislodge() -> void:
	if is_dislodged and not is_patrolling:
		return
	is_patrolling = false
	is_dislodged = true
	lock_rotation = false
	gravity_scale = 1.0
	linear_damp = 0.12
	angular_damp = 0.20
	sleeping = false


func on_ball_physical_impact(impulse_mag: float) -> bool:
	_bounce_squash = 1.0
	if impulse_mag >= DISLODGE_IMPULSE:
		dislodge()
	if not has_yielded_smash and impulse_mag >= min_smash_impulse:
		has_yielded_smash = true
		return true
	return false


func _on_body_entered(body: Node) -> void:
	if not (body is PlayerBall3D):
		return
	var ball := body as PlayerBall3D
	if ball.is_respawning or ball.has_method("notify_obstacle_impact"):
		return
	var pre_vel := ball._saved_velocity_pre_step if ball._saved_velocity_pre_step.length_squared() > 0.001 else ball.linear_velocity
	var post_vel := ball.linear_velocity
	var impulse_est := ball.mass * (post_vel - pre_vel).length()
	if impulse_est < 0.05:
		var mu := (ball.mass * mass) / maxf(0.1, ball.mass + mass)
		impulse_est = mu * (pre_vel - linear_velocity).length()
	if ball.synergy_bus != null:
		var loss_mult := ball.synergy_bus.stats.get_stat("smash_speed_loss_mult")
		if loss_mult < 0.999:
			var fwd_dir := -ball.get_track_basis().z.normalized()
			var dv_fwd := pre_vel.dot(fwd_dir) - post_vel.dot(fwd_dir)
			if dv_fwd > 0.2:
				var restored := post_vel + fwd_dir * (dv_fwd * (1.0 - clampf(loss_mult, 0.0, 1.0)))
				var max_spd := pre_vel.length()
				if restored.length() > max_spd and max_spd > 0.001:
					restored = restored.normalized() * max_spd
				ball.linear_velocity = restored
	var self_pos := global_position if is_inside_tree() else position
	var ball_pos := ball.global_position if ball.is_inside_tree() else ball.position
	if on_ball_physical_impact(impulse_est):
		var saved_pre := ball._saved_velocity_pre_step
		ball._saved_velocity_pre_step = ball.linear_velocity
		ball.notify_smash_target(self_pos, 0.0, 0)
		ball._saved_velocity_pre_step = ball.linear_velocity if ball.linear_velocity.length() > saved_pre.length() else saved_pre
	if (post_vel - pre_vel).length() >= 3.2:
		var diff := ball_pos - self_pos
		var n := diff.normalized() if diff.length_squared() > 0.0001 else Vector3.BACK
		ball.notify_wall_or_bumper_bounce(n, self_pos, 0.0)


func apply_shockwave(
	origin: Vector3,
	radius: float,
	force: float,
	chain_depth: int,
	ball: PlayerBall3D
) -> void:
	var self_pos := global_position if is_inside_tree() else position
	var dist := self_pos.distance_to(origin)
	if dist > radius or force < 6.0:
		return
	_bounce_squash = 1.0
	dislodge()
	var falloff := clampf(1.0 - (dist / (radius * 1.15)), 0.25, 1.0)
	var radial := self_pos - origin
	radial.y = 0.0
	var dir := radial.normalized() if radial.length_squared() > 0.001 else Vector3(0.25, 0.0, -1.0).normalized()
	var up_dir := global_transform.basis.y.normalized() if is_inside_tree() else Vector3.UP
	var impulse_mag := force * 0.85 * falloff
	var impulse_vec := (dir + up_dir * 0.45).normalized() * impulse_mag
	var budget_dv := maxf(0.0, MAX_SHOCKWAVE_SPEED - linear_velocity.length() - _queued_shockwave_dv)
	var clamped_vec := impulse_vec.limit_length(budget_dv * mass)
	if clamped_vec.length_squared() > 0.0001:
		apply_impulse(clamped_vec, up_dir * 0.16)
		_queued_shockwave_dv += clamped_vec.length() / maxf(0.05, mass)
	if linear_velocity.length() > MAX_SHOCKWAVE_SPEED:
		linear_velocity = linear_velocity.normalized() * MAX_SHOCKWAVE_SPEED
	if not has_yielded_smash and impulse_mag >= min_smash_impulse:
		has_yielded_smash = true
		if ball != null:
			if ball.has_method("notify_obstacle_impact"):
				ball.notify_obstacle_impact(self_pos, chain_depth)
			else:
				ball.notify_smash_target(self_pos, 0.0, chain_depth)
