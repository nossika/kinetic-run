class_name WoodenPin
extends RigidBody3D

const ABYSS_LOCAL_Y: float = -28.0
const MAX_SHOCKWAVE_SPEED: float = 32.0

var weight_label: String = "800g"
var min_smash_impulse: float = 1.6
var is_dislodged: bool = false
var has_yielded_smash: bool = false
var _queued_shockwave_dv: float = 0.0


func _init() -> void:
	mass = 0.80
	set_meta("weight_label", weight_label)


func _ready() -> void:
	mass = 0.80
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, -0.10, 0.0)
	physics_material_override = MaterialLibrary.high_friction_physics(0.74, 0.28)
	gravity_scale = 1.0
	linear_damp = 0.10 if is_dislodged else 1.1
	angular_damp = 0.18 if is_dislodged else 1.6
	contact_monitor = true
	max_contacts_reported = 4

	var col := CollisionShape3D.new()
	var cyl_shape := CylinderShape3D.new()
	cyl_shape.radius = 0.28
	cyl_shape.height = 1.56
	col.shape = cyl_shape
	add_child(col)

	_build_pin_visuals()
	MaterialLibrary.attach_weight_labels(self, weight_label, Vector3(0.56, 1.56, 0.56), Color(0.24, 0.16, 0.12))
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _build_pin_visuals() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var wood_mat := MaterialLibrary.make_ceramic_pin_material(Color(0.99, 0.98, 0.95))
	var stripe_mat := MaterialLibrary.make_pin_stripe_material(Color(0.90, 0.18, 0.18))

	var belly_inst := MeshInstance3D.new()
	var belly_mesh := ClayMeshBuilder.make_chamfered_cylinder(0.25, 0.28, 0.88, 0.09, 24)
	ClayMeshBuilder.assign_mesh(belly_inst, belly_mesh, wood_mat)
	belly_inst.position = Vector3(0.0, -0.34, 0.0)
	add_child(belly_inst)

	var neck_inst := MeshInstance3D.new()
	var neck_cyl := CylinderMesh.new()
	neck_cyl.top_radius = 0.15
	neck_cyl.bottom_radius = 0.245
	neck_cyl.height = 0.36
	neck_cyl.radial_segments = 24
	neck_cyl.material = wood_mat
	RenderHelper.attach_mesh(neck_inst, neck_cyl)
	neck_inst.position = Vector3(0.0, 0.26, 0.0)
	add_child(neck_inst)

	var band_inst := MeshInstance3D.new()
	var band_torus := TorusMesh.new()
	band_torus.inner_radius = 0.145
	band_torus.outer_radius = 0.195
	band_torus.rings = 24
	band_torus.ring_segments = 12
	band_torus.material = stripe_mat
	RenderHelper.attach_mesh(band_inst, band_torus)
	band_inst.position = Vector3(0.0, 0.32, 0.0)
	add_child(band_inst)

	var head_inst := MeshInstance3D.new()
	var head_sphere := SphereMesh.new()
	head_sphere.radius = 0.195
	head_sphere.height = 0.40
	head_sphere.radial_segments = 24
	head_sphere.rings = 14
	head_sphere.material = wood_mat
	RenderHelper.attach_mesh(head_inst, head_sphere)
	head_inst.position = Vector3(0.0, 0.58, 0.0)
	add_child(head_inst)


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
	linear_damp = 0.10
	angular_damp = 0.18


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
	if dist > radius or force < 4.0:
		return
	dislodge()
	var falloff := clampf(1.0 - (dist / (radius * 1.15)), 0.25, 1.0)
	var radial := self_pos - origin
	radial.y = 0.0
	var dir := radial.normalized() if radial.length_squared() > 0.001 else Vector3(0.25, 0.0, -1.0).normalized()
	var up_dir := global_transform.basis.y.normalized() if is_inside_tree() else Vector3.UP
	var impulse_vec := (dir + up_dir * 0.48).normalized() * (force * 0.85 * falloff)
	var budget_dv := maxf(0.0, MAX_SHOCKWAVE_SPEED - linear_velocity.length() - _queued_shockwave_dv)
	var clamped_vec := impulse_vec.limit_length(budget_dv * mass)
	if clamped_vec.length_squared() > 0.0001:
		apply_impulse(clamped_vec, up_dir * 0.22)
		_queued_shockwave_dv += clamped_vec.length() / maxf(0.05, mass)
	if linear_velocity.length() > MAX_SHOCKWAVE_SPEED:
		linear_velocity = linear_velocity.normalized() * MAX_SHOCKWAVE_SPEED
	if not has_yielded_smash:
		has_yielded_smash = true
		if ball != null:
			if ball.has_method("notify_obstacle_impact"):
				ball.notify_obstacle_impact(self_pos, chain_depth)
			else:
				ball.notify_smash_target(self_pos, 0.0, chain_depth)
