class_name AerialBlocker
extends RigidBody3D

const ABYSS_LOCAL_Y: float = -28.0
const MAX_SHOCKWAVE_SPEED: float = 32.0

var blocker_type: String = "soft_balloon"
var initial_phase: float = 0.0
var weight_label: String = "250g"
var min_smash_impulse: float = 0.8
var untether_impulse: float = 0.5
var is_tethered: bool = true
var is_dislodged: bool = false
var has_yielded_smash: bool = false

var _elapsed: float = 0.0
var _origin_pos: Vector3 = Vector3.ZERO
var _origin_captured: bool = false
var _mag_ring: MeshInstance3D = null
var _queued_shockwave_dv: float = 0.0


func _init() -> void:
	configure_type("soft_balloon", 0.0)


func configure_type(p_type: String, p_phase: float = 0.0) -> void:
	initial_phase = p_phase
	if p_type == "mag_iron":
		blocker_type = "mag_iron"
		mass = 12.0
		weight_label = "12kg"
		min_smash_impulse = 4.5
		untether_impulse = 4.5
		physics_material_override = MaterialLibrary.high_friction_physics(0.82, 0.16)
	else:
		blocker_type = "soft_balloon"
		mass = 0.25
		weight_label = "250g"
		min_smash_impulse = 0.8
		untether_impulse = 0.5
		physics_material_override = MaterialLibrary.high_friction_physics(0.35, 0.92)
	set_meta("weight_label", weight_label)


func _ready() -> void:
	configure_type(blocker_type, initial_phase)
	_origin_pos = position
	_origin_captured = true

	freeze = false
	can_sleep = false
	lock_rotation = is_tethered
	if is_tethered:
		gravity_scale = 0.0
		linear_damp = 0.0
		angular_damp = 0.24 if blocker_type == "mag_iron" else 0.35
	elif blocker_type == "mag_iron":
		gravity_scale = 1.0
		linear_damp = 0.14
		angular_damp = 0.24
	else:
		gravity_scale = 0.28
		linear_damp = 0.48
		angular_damp = 0.35

	contact_monitor = true
	max_contacts_reported = 4

	var col := CollisionShape3D.new()
	if blocker_type == "mag_iron":
		var b_shape := BoxShape3D.new()
		b_shape.size = Vector3(1.25, 1.25, 1.25)
		col.shape = b_shape
		add_child(col)
		_build_mag_iron_visuals()
		MaterialLibrary.attach_weight_labels(self, "12kg", Vector3(1.25, 1.25, 1.25), Color(0.96, 0.97, 1.0))
	else:
		var s_shape := SphereShape3D.new()
		s_shape.radius = 0.72
		col.shape = s_shape
		add_child(col)
		_build_balloon_visuals()
		MaterialLibrary.attach_weight_labels(self, "250g", Vector3(1.45, 1.45, 1.45), Color(0.99, 0.97, 0.92))

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _build_mag_iron_visuals() -> void:
	ClayMeshBuilder.attach_clay_eyes(self, Vector3(0.0, 0.08, 0.63), 0.28, 0.062, false)
	if DisplayServer.get_name() != "headless":
		var cube_inst := MeshInstance3D.new()
		var rbox := ClayMeshBuilder.make_rounded_box(Vector3(1.25, 1.25, 1.25), 0.22, 3)
		var mat := MaterialLibrary.make_cast_iron_material(Color(0.40, 0.43, 0.50))
		ClayMeshBuilder.assign_mesh(cube_inst, rbox, mat)
		add_child(cube_inst)

	_mag_ring = MeshInstance3D.new()
	_mag_ring.name = "MagRing"
	_mag_ring.position = Vector3(0.0, -0.78, 0.0)
	_mag_ring.visible = is_tethered
	if DisplayServer.get_name() != "headless":
		var mag_torus := TorusMesh.new()
		mag_torus.inner_radius = 0.54
		mag_torus.outer_radius = 0.78
		mag_torus.rings = 28
		mag_torus.ring_segments = 14
		mag_torus.material = MaterialLibrary.make_frosted_acrylic_material(Color(0.62, 0.84, 0.96, 0.76))
		RenderHelper.attach_mesh(_mag_ring, mag_torus)
	add_child(_mag_ring)


func _build_balloon_visuals() -> void:
	ClayMeshBuilder.attach_clay_eyes(self, Vector3(0.0, 0.06, 0.70), 0.24, 0.058, true)
	if DisplayServer.get_name() == "headless":
		return
	var balloon_inst := MeshInstance3D.new()
	var balloon_mesh := SphereMesh.new()
	balloon_mesh.radius = 0.72
	balloon_mesh.height = 1.44
	balloon_mesh.radial_segments = 28
	balloon_mesh.rings = 16
	balloon_mesh.material = MaterialLibrary.make_silicone_soft_material(Color(0.98, 0.64, 0.50))
	RenderHelper.attach_mesh(balloon_inst, balloon_mesh)
	add_child(balloon_inst)

	var knot_inst := MeshInstance3D.new()
	var knot_torus := TorusMesh.new()
	knot_torus.inner_radius = 0.04
	knot_torus.outer_radius = 0.13
	knot_torus.rings = 16
	knot_torus.ring_segments = 10
	knot_torus.material = MaterialLibrary.make_silicone_soft_material(Color(0.94, 0.54, 0.40))
	RenderHelper.attach_mesh(knot_inst, knot_torus)
	knot_inst.position = Vector3(0.0, -0.74, 0.0)
	add_child(knot_inst)


func _physics_process(delta: float) -> void:
	_queued_shockwave_dv = 0.0
	if not _origin_captured:
		_origin_pos = position
		_origin_captured = true

	if is_tethered:
		if mass * linear_velocity.length() >= untether_impulse:
			untether()
		else:
			_elapsed += delta
			var phase := _elapsed + initial_phase
			var sway_x := sin(phase * 1.8) * 0.45
			var bob_y := sin(phase * 2.7) * 0.28
			position = Vector3(_origin_pos.x + sway_x, _origin_pos.y + bob_y, _origin_pos.z)
			linear_velocity = Vector3.ZERO
			angular_velocity = Vector3.ZERO

	if get_parent() is Node3D and position.y < ABYSS_LOCAL_Y:
		queue_free()


func untether() -> void:
	if not is_tethered and is_dislodged:
		return
	is_tethered = false
	is_dislodged = true
	lock_rotation = false
	sleeping = false
	if blocker_type == "mag_iron":
		gravity_scale = 1.0
		linear_damp = 0.14
		angular_damp = 0.24
		if _mag_ring != null:
			_mag_ring.visible = false
	else:
		gravity_scale = 0.28
		linear_damp = 0.48
		angular_damp = 0.35


func dislodge() -> void:
	untether()


func on_ball_physical_impact(impulse_mag: float) -> bool:
	if impulse_mag >= untether_impulse:
		untether()
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
		var mu := (ball.mass * mass) / maxf(0.05, ball.mass + mass)
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
	var req_force := 6.0 if blocker_type == "mag_iron" else 4.0
	if dist > radius or force < req_force:
		return
	untether()
	var falloff := clampf(1.0 - (dist / (radius * 1.15)), 0.25, 1.0)
	var radial := self_pos - origin
	radial.y = 0.0
	var dir := radial.normalized() if radial.length_squared() > 0.001 else Vector3(0.25, 0.0, -1.0).normalized()
	var up_dir := global_transform.basis.y.normalized() if is_inside_tree() else Vector3.UP
	var impulse_mag := force * 0.85 * falloff
	var impulse_vec := (dir + up_dir * 0.38).normalized() * impulse_mag
	var budget_dv := maxf(0.0, MAX_SHOCKWAVE_SPEED - linear_velocity.length() - _queued_shockwave_dv)
	var clamped_vec := impulse_vec.limit_length(budget_dv * mass)
	if clamped_vec.length_squared() > 0.0001:
		apply_impulse(clamped_vec, up_dir * 0.14)
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
