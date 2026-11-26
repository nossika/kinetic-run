class_name CrateObstacle
extends RigidBody3D

const ABYSS_LOCAL_Y: float = -28.0
const MAX_SHOCKWAVE_SPEED: float = 32.0

var weight_tier: String = "light"
var weight_label: String = "500g"
var min_smash_impulse: float = 1.6
var is_dislodged: bool = false
var has_yielded_smash: bool = false
var _queued_shockwave_dv: float = 0.0


func _init() -> void:
	configure_tier("light")


func configure_tier(tier: String) -> void:
	if tier == "medium":
		weight_tier = "medium"
		mass = 2.00
		min_smash_impulse = 2.6
		weight_label = "2kg"
	else:
		weight_tier = "light"
		mass = 0.50
		min_smash_impulse = 1.6
		weight_label = "500g"
	set_meta("weight_label", weight_label)


func _ready() -> void:
	configure_tier(weight_tier)

	var is_heavy := (weight_tier == "medium")
	var box_size := Vector3(1.20, 1.20, 1.20) if is_heavy else Vector3(0.96, 0.96, 0.96)
	physics_material_override = (
		MaterialLibrary.high_friction_physics(0.78, 0.16)
		if is_heavy
		else MaterialLibrary.high_friction_physics(0.72, 0.24)
	)
	gravity_scale = 1.0
	can_sleep = false
	linear_damp = 0.12 if is_dislodged else 1.2
	angular_damp = 0.22 if is_dislodged else 1.8
	contact_monitor = true
	max_contacts_reported = 4

	var col := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = box_size
	col.shape = box_shape
	add_child(col)

	_build_crate_visuals(box_size, is_heavy)

	var label_color := Color(0.99, 0.92, 0.68) if is_heavy else Color(0.24, 0.14, 0.06)
	MaterialLibrary.attach_weight_labels(self, weight_label, box_size, label_color)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _build_crate_visuals(box_size: Vector3, is_heavy: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mesh_inst := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = box_size
	box_mesh.material = MaterialLibrary.make_wood_crate_material(is_heavy)
	RenderHelper.attach_mesh(mesh_inst, box_mesh)
	add_child(mesh_inst)

	if is_heavy:
		_build_heavy_trim_bands(box_size)


func _build_heavy_trim_bands(box_size: Vector3) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var trim_mat := MaterialLibrary.make_cast_iron_material(Color(0.20, 0.18, 0.17))

	for sy in [-1.0, 1.0]:
		var band_inst := MeshInstance3D.new()
		var band_mesh := BoxMesh.new()
		band_mesh.size = Vector3(box_size.x + 0.025, 0.085, box_size.z + 0.025)
		band_mesh.material = trim_mat
		RenderHelper.attach_mesh(band_inst, band_mesh)
		band_inst.position = Vector3(0.0, sy * box_size.y * 0.38, 0.0)
		add_child(band_inst)

	var post_offset_x := box_size.x * 0.5 - 0.035
	var post_offset_z := box_size.z * 0.5 - 0.035
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.09, box_size.y + 0.02, 0.09)
	post_mesh.material = trim_mat
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var post_inst := MeshInstance3D.new()
			RenderHelper.attach_mesh(post_inst, post_mesh)
			post_inst.position = Vector3(sx * post_offset_x, 0.0, sz * post_offset_z)
			add_child(post_inst)


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
	linear_damp = 0.12
	angular_damp = 0.22


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
	var impulse_vec := (dir + up_dir * 0.42).normalized() * (force * 0.85 * falloff)
	var budget_dv := maxf(0.0, MAX_SHOCKWAVE_SPEED - linear_velocity.length() - _queued_shockwave_dv)
	var clamped_vec := impulse_vec.limit_length(budget_dv * mass)
	if clamped_vec.length_squared() > 0.0001:
		apply_impulse(clamped_vec, up_dir * 0.18)
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
