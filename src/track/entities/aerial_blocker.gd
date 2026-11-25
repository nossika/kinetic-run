class_name AerialBlocker
extends Node3D

const SOFT_SMASH_MOMENTUM: float = 18.0
const SOFT_SPEED_LOSS: float = 0.06
const IRON_SMASH_MOMENTUM: float = 36.0
const IRON_SPEED_LOSS: float = 0.14

var blocker_type: String = "soft_balloon"
var initial_phase: float = 0.0
var is_smashed: bool = false
var weight_label: String = "2kg"
var smash_momentum: float = SOFT_SMASH_MOMENTUM
var speed_loss_ratio: float = SOFT_SPEED_LOSS

var _elapsed: float = 0.0
var _origin_pos: Vector3 = Vector3.ZERO
var _fly_vel: Vector3 = Vector3.ZERO
var _ttl: float = 0.0
var _hit_cooldown: float = 0.0
var _sensor: Area3D = null


func _init() -> void:
	configure_type("soft_balloon", 0.0)


func configure_type(p_type: String, p_phase: float = 0.0) -> void:
	initial_phase = p_phase
	if p_type == "mag_iron":
		blocker_type = "mag_iron"
		weight_label = "12kg"
		smash_momentum = IRON_SMASH_MOMENTUM
		speed_loss_ratio = IRON_SPEED_LOSS
	else:
		blocker_type = "soft_balloon"
		weight_label = "2kg"
		smash_momentum = SOFT_SMASH_MOMENTUM
		speed_loss_ratio = SOFT_SPEED_LOSS
	set_meta("weight_label", weight_label)


func _ready() -> void:
	configure_type(blocker_type, initial_phase)
	_origin_pos = position

	_sensor = Area3D.new()
	var s_col := CollisionShape3D.new()

	if blocker_type == "mag_iron":
		var cube_inst := MeshInstance3D.new()
		var cube_mesh := BoxMesh.new()
		cube_mesh.size = Vector3(1.25, 1.25, 1.25)
		cube_mesh.material = MaterialLibrary.make_cast_iron_material()
		RenderHelper.attach_mesh(cube_inst, cube_mesh)
		add_child(cube_inst)

		if DisplayServer.get_name() != "headless":
			var mag_ring := MeshInstance3D.new()
			var mag_torus := TorusMesh.new()
			mag_torus.inner_radius = 0.55
			mag_torus.outer_radius = 0.78
			mag_torus.rings = 24
			mag_torus.ring_segments = 12
			mag_torus.material = MaterialLibrary.make_frosted_acrylic_material(Color(0.14, 0.92, 1.0, 0.85))
			RenderHelper.attach_mesh(mag_ring, mag_torus)
			mag_ring.position = Vector3(0.0, -0.78, 0.0)
			add_child(mag_ring)

		MaterialLibrary.attach_weight_labels(self, "12kg", Vector3(1.25, 1.25, 1.25), Color(0.96, 0.97, 1.0))

		var b_shape := BoxShape3D.new()
		b_shape.size = Vector3(1.50, 1.50, 1.50)
		s_col.shape = b_shape
	else:
		var balloon_inst := MeshInstance3D.new()
		var balloon_mesh := SphereMesh.new()
		balloon_mesh.radius = 0.72
		balloon_mesh.height = 1.44
		balloon_mesh.material = MaterialLibrary.make_silicone_soft_material(Color(1.0, 0.52, 0.34))
		RenderHelper.attach_mesh(balloon_inst, balloon_mesh)
		add_child(balloon_inst)

		if DisplayServer.get_name() != "headless":
			var knot_inst := MeshInstance3D.new()
			var knot_cyl := CylinderMesh.new()
			knot_cyl.top_radius = 0.08
			knot_cyl.bottom_radius = 0.14
			knot_cyl.height = 0.16
			knot_cyl.material = MaterialLibrary.make_silicone_soft_material(Color(0.92, 0.42, 0.26))
			RenderHelper.attach_mesh(knot_inst, knot_cyl)
			knot_inst.position = Vector3(0.0, -0.76, 0.0)
			add_child(knot_inst)

		MaterialLibrary.attach_weight_labels(self, "2kg", Vector3(1.45, 1.45, 1.45), Color(0.99, 0.97, 0.92))

		var s_shape := SphereShape3D.new()
		s_shape.radius = 0.98
		s_col.shape = s_shape

	_sensor.add_child(s_col)
	_sensor.body_entered.connect(_on_body_entered)
	add_child(_sensor)


func _physics_process(delta: float) -> void:
	_hit_cooldown = maxf(0.0, _hit_cooldown - delta)
	if is_smashed:
		global_position += _fly_vel * delta
		rotate_x(7.5 * delta)
		rotate_z(5.5 * delta)
		_ttl -= delta
		if _ttl <= 0.0:
			queue_free()
		return

	_elapsed += delta
	var phase := _elapsed + initial_phase
	var sway_x := sin(phase * 1.8) * 0.45
	var bob_y := sin(phase * 2.7) * 0.28
	position = Vector3(_origin_pos.x + sway_x, _origin_pos.y + bob_y, _origin_pos.z)


func _on_body_entered(body: Node) -> void:
	if body is PlayerBall3D:
		interact_with_ball(body as PlayerBall3D)


func interact_with_ball(ball: PlayerBall3D) -> void:
	if is_smashed or ball == null or ball.is_respawning:
		return
	var origin := global_position if is_inside_tree() else position
	var ball_pos := ball.global_position if ball.is_inside_tree() else ball.position

	if ball.get_current_momentum() >= smash_momentum:
		_smash(Vector3(ball.linear_velocity.x * 0.3, 9.0, -20.0))
		ball.notify_smash_target(origin, speed_loss_ratio, 0)
		return

	if _hit_cooldown > 0.0:
		return

	if blocker_type == "mag_iron":
		_hit_cooldown = 0.28
		ball.linear_velocity.z *= 0.30
		ball.linear_velocity.y = minf(ball.linear_velocity.y, -2.5)
		ball.notify_wall_or_bumper_bounce(Vector3.BACK, origin, 0.0)
	else:
		_hit_cooldown = 0.24
		ball.linear_velocity.z = maxf(ball.linear_velocity.z * 0.4, 3.5)
		var lat_sign := 1.0 if (ball_pos.x - origin.x) >= 0.0 else -1.0
		ball.linear_velocity.x = lat_sign * 5.5
		ball.linear_velocity.y = maxf(ball.linear_velocity.y, 2.5)
		ball.notify_wall_or_bumper_bounce(Vector3.BACK, origin, 0.0)


func apply_shockwave(
	origin: Vector3,
	radius: float,
	force: float,
	chain_depth: int,
	ball: PlayerBall3D
) -> void:
	if is_smashed:
		return
	var req_force := 10.0 if blocker_type == "mag_iron" else 6.0
	var self_pos := global_position if is_inside_tree() else position
	if self_pos.distance_to(origin) <= radius and force >= req_force:
		var dir := (self_pos - origin).normalized()
		if dir.length_squared() < 0.01:
			dir = Vector3(0.0, 1.0, -1.0).normalized()
		_smash(dir * 16.0 + Vector3(0.0, 8.0, -6.0))
		if ball != null:
			ball.notify_smash_target(self_pos, 0.0, chain_depth)


func _smash(vel: Vector3) -> void:
	is_smashed = true
	_fly_vel = vel
	_ttl = 0.75
	if _sensor != null:
		_sensor.set_deferred("monitoring", false)
