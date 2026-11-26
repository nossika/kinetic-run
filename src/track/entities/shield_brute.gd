class_name ShieldBrute
extends RigidBody3D

const ABYSS_LOCAL_Y: float = -28.0
const MAX_SHOCKWAVE_SPEED: float = 32.0

var weight_label: String = "20kg"
var min_smash_impulse: float = 4.5
var is_dislodged: bool = false
var has_yielded_smash: bool = false
var _queued_shockwave_dv: float = 0.0


func _init() -> void:
	mass = 20.0
	set_meta("weight_label", weight_label)


func _ready() -> void:
	mass = 20.0
	physics_material_override = MaterialLibrary.high_friction_physics(0.86, 0.12)
	gravity_scale = 1.0
	linear_damp = 0.16 if is_dislodged else 1.2
	angular_damp = 0.28 if is_dislodged else 1.8
	contact_monitor = true
	max_contacts_reported = 4

	var col := CollisionShape3D.new()
	var cyl_shape := CylinderShape3D.new()
	cyl_shape.radius = 0.72
	cyl_shape.height = 1.40
	col.shape = cyl_shape
	add_child(col)

	_build_weight_visuals()
	MaterialLibrary.attach_weight_labels(self, "20kg", Vector3(1.45, 1.45, 1.45), Color(0.96, 0.93, 0.86))
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _build_weight_visuals() -> void:
	ClayMeshBuilder.attach_clay_eyes(self, Vector3(0.0, 0.06, 0.68), 0.28, 0.068, true)
	if DisplayServer.get_name() == "headless":
		return
	var iron_mat := MaterialLibrary.make_cast_iron_material(Color(0.36, 0.38, 0.44))

	# Smooth 28-segment plump roly-poly clay-iron kettlebell body (replaces harsh 8-sided octagon)
	var base_inst := MeshInstance3D.new()
	var base_mesh := ClayMeshBuilder.make_chamfered_cylinder(0.64, 0.73, 0.84, 0.18, 28)
	ClayMeshBuilder.assign_mesh(base_inst, base_mesh, iron_mat)
	base_inst.position = Vector3(0.0, -0.28, 0.0)
	add_child(base_inst)

	var dome_inst := MeshInstance3D.new()
	var dome_sphere := SphereMesh.new()
	dome_sphere.radius = 0.58
	dome_sphere.height = 0.78
	dome_sphere.radial_segments = 28
	dome_sphere.rings = 14
	dome_sphere.material = iron_mat
	RenderHelper.attach_mesh(dome_inst, dome_sphere)
	dome_inst.position = Vector3(0.0, 0.08, 0.0)
	add_child(dome_inst)

	var grip_inst := MeshInstance3D.new()
	var grip_torus := TorusMesh.new()
	grip_torus.inner_radius = 0.13
	grip_torus.outer_radius = 0.25
	grip_torus.rings = 24
	grip_torus.ring_segments = 14
	var grip_mat := MaterialLibrary.make_silicone_soft_material(Color(0.92, 0.78, 0.52))
	grip_torus.material = grip_mat
	RenderHelper.attach_mesh(grip_inst, grip_torus)
	grip_inst.position = Vector3(0.0, 0.52, 0.0)
	grip_inst.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	add_child(grip_inst)


func _physics_process(_delta: float) -> void:
	_queued_shockwave_dv = 0.0
	if not is_dislodged and (linear_velocity.length_squared() > 0.35 or angular_velocity.length_squared() > 0.45):
		dislodge()
	if get_parent() is Node3D and position.y < ABYSS_LOCAL_Y:
		queue_free()


func dislodge() -> void:
	if is_dislodged:
		return
	is_dislodged = true
	sleeping = false
	linear_damp = 0.16
	angular_damp = 0.28


func on_ball_physical_impact(impulse_mag: float) -> bool:
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
	if on_ball_physical_impact(impulse_est):
		var self_pos := global_position if is_inside_tree() else position
		var saved_pre := ball._saved_velocity_pre_step
		ball._saved_velocity_pre_step = ball.linear_velocity
		ball.notify_smash_target(self_pos, 0.0, 0)
		ball._saved_velocity_pre_step = ball.linear_velocity if ball.linear_velocity.length() > saved_pre.length() else saved_pre


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
	dislodge()
	var falloff := clampf(1.0 - (dist / (radius * 1.15)), 0.25, 1.0)
	var radial := self_pos - origin
	radial.y = 0.0
	var dir := radial.normalized() if radial.length_squared() > 0.001 else Vector3(0.25, 0.0, -1.0).normalized()
	var up_dir := global_transform.basis.y.normalized() if is_inside_tree() else Vector3.UP
	var impulse_mag := force * 0.85 * falloff
	var impulse_vec := (dir + up_dir * 0.42).normalized() * impulse_mag
	var budget_dv := maxf(0.0, MAX_SHOCKWAVE_SPEED - linear_velocity.length() - _queued_shockwave_dv)
	var clamped_vec := impulse_vec.limit_length(budget_dv * mass)
	if clamped_vec.length_squared() > 0.0001:
		apply_impulse(clamped_vec, up_dir * 0.18)
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
