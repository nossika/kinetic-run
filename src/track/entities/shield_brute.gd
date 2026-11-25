class_name ShieldBrute
extends RigidBody3D

const SMASH_MOMENTUM: float = 42.0
const SPEED_LOSS_RATIO: float = 0.15

var smash_momentum: float = SMASH_MOMENTUM
var weight_label: String = "20kg"
var is_smashed: bool = false

var _ttl: float = 0.0
var _hit_cooldown: float = 0.0
var _sensor: Area3D = null


func _init() -> void:
	mass = 20.0
	set_meta("weight_label", weight_label)


func _ready() -> void:
	mass = 20.0
	physics_material_override = MaterialLibrary.high_friction_physics(0.94, 0.06)
	gravity_scale = 1.0
	linear_damp = 2.0
	angular_damp = 3.0
	contact_monitor = true
	max_contacts_reported = 4

	var col := CollisionShape3D.new()
	var cyl_shape := CylinderShape3D.new()
	cyl_shape.radius = 0.72
	cyl_shape.height = 1.40
	col.shape = cyl_shape
	add_child(col)

	_build_weight_visuals()
	MaterialLibrary.attach_weight_labels(self, "20kg", Vector3(1.45, 1.45, 1.45), Color(0.96, 0.97, 1.0))

	_sensor = Area3D.new()
	var s_col := CollisionShape3D.new()
	var b_shape := BoxShape3D.new()
	b_shape.size = Vector3(1.70, 1.60, 1.65)
	s_col.shape = b_shape
	_sensor.add_child(s_col)
	_sensor.body_entered.connect(_on_body_entered)
	add_child(_sensor)


func _build_weight_visuals() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var iron_mat := MaterialLibrary.make_cast_iron_material()

	var base_inst := MeshInstance3D.new()
	var base_cyl := CylinderMesh.new()
	base_cyl.top_radius = 0.68
	base_cyl.bottom_radius = 0.75
	base_cyl.height = 0.74
	base_cyl.radial_segments = 8
	base_cyl.material = iron_mat
	RenderHelper.attach_mesh(base_inst, base_cyl)
	base_inst.position = Vector3(0.0, -0.33, 0.0)
	base_inst.rotation_degrees = Vector3(0.0, 22.5, 0.0)
	add_child(base_inst)

	var shoulder_inst := MeshInstance3D.new()
	var shoulder_cyl := CylinderMesh.new()
	shoulder_cyl.top_radius = 0.50
	shoulder_cyl.bottom_radius = 0.62
	shoulder_cyl.height = 0.34
	shoulder_cyl.radial_segments = 8
	shoulder_cyl.material = iron_mat
	RenderHelper.attach_mesh(shoulder_inst, shoulder_cyl)
	shoulder_inst.position = Vector3(0.0, 0.21, 0.0)
	shoulder_inst.rotation_degrees = Vector3(0.0, 22.5, 0.0)
	add_child(shoulder_inst)

	var neck_inst := MeshInstance3D.new()
	var neck_cyl := CylinderMesh.new()
	neck_cyl.top_radius = 0.24
	neck_cyl.bottom_radius = 0.30
	neck_cyl.height = 0.12
	neck_cyl.radial_segments = 12
	neck_cyl.material = iron_mat
	RenderHelper.attach_mesh(neck_inst, neck_cyl)
	neck_inst.position = Vector3(0.0, 0.43, 0.0)
	add_child(neck_inst)

	var grip_inst := MeshInstance3D.new()
	var grip_torus := TorusMesh.new()
	grip_torus.inner_radius = 0.12
	grip_torus.outer_radius = 0.22
	grip_torus.rings = 20
	grip_torus.ring_segments = 12
	var grip_mat := MaterialLibrary.make_cast_iron_material(Color(0.42, 0.45, 0.52))
	grip_mat.metallic = 0.86
	grip_mat.roughness = 0.24
	grip_torus.material = grip_mat
	RenderHelper.attach_mesh(grip_inst, grip_torus)
	grip_inst.position = Vector3(0.0, 0.50, 0.0)
	grip_inst.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	add_child(grip_inst)


func _physics_process(delta: float) -> void:
	_hit_cooldown = maxf(0.0, _hit_cooldown - delta)
	if is_smashed:
		_ttl -= delta
		if _ttl <= 0.0:
			queue_free()


func _on_body_entered(body: Node) -> void:
	if body is PlayerBall3D:
		interact_with_ball(body as PlayerBall3D)


func interact_with_ball(ball: PlayerBall3D) -> void:
	if is_smashed or ball == null or ball.is_respawning:
		return
	if ball.get_current_momentum() >= SMASH_MOMENTUM:
		_smash(Vector3(ball.linear_velocity.x * 0.25, 10.0, -22.0))
		ball.notify_smash_target(global_position, SPEED_LOSS_RATIO, 0)
	elif _hit_cooldown <= 0.0:
		_hit_cooldown = 0.28
		ball.linear_velocity *= 0.35
		ball.global_position.z += 0.35
		ball.notify_wall_or_bumper_bounce(Vector3.BACK, global_position, 0.0)


func apply_shockwave(
	origin: Vector3,
	radius: float,
	force: float,
	chain_depth: int,
	ball: PlayerBall3D
) -> void:
	if is_smashed:
		return
	if global_position.distance_to(origin) <= radius and force >= 10.0:
		var dir := (global_position - origin).normalized()
		if dir.length_squared() < 0.01:
			dir = Vector3(0.0, 1.0, -1.0).normalized()
		_smash(dir * 16.0 + Vector3(0.0, 9.0, -8.0))
		if ball != null:
			ball.notify_smash_target(global_position, 0.0, chain_depth)


func _smash(vel: Vector3) -> void:
	is_smashed = true
	_ttl = 0.75
	collision_layer = 2
	collision_mask = 0
	if _sensor != null:
		_sensor.set_deferred("monitoring", false)
	gravity_scale = 1.0
	linear_damp = 0.1
	linear_velocity = vel
	angular_velocity = Vector3(6.0, 5.0, 8.0)
