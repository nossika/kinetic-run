class_name CrateObstacle
extends RigidBody3D

const SMASH_MOMENTUM: float = 10.0
const MEDIUM_SMASH_MOMENTUM: float = 18.0

var weight_tier: String = "light"
var weight_label: String = "500g"
var smash_momentum: float = 10.0
var speed_loss_ratio: float = 0.05
var is_smashed: bool = false

var _debris_ttl: float = 0.0
var _sensor: Area3D = null


func _init() -> void:
	configure_tier("light")


func configure_tier(tier: String) -> void:
	if tier == "medium":
		weight_tier = "medium"
		mass = 2.5
		smash_momentum = MEDIUM_SMASH_MOMENTUM
		speed_loss_ratio = 0.09
		weight_label = "2.5kg"
	else:
		weight_tier = "light"
		mass = 0.5
		smash_momentum = SMASH_MOMENTUM
		speed_loss_ratio = 0.05
		weight_label = "500g"
	set_meta("weight_label", weight_label)


func _ready() -> void:
	configure_tier(weight_tier)

	physics_material_override = MaterialLibrary.high_friction_physics(0.90, 0.10)
	gravity_scale = 1.0
	linear_damp = 1.5
	angular_damp = 2.2
	contact_monitor = true
	max_contacts_reported = 4

	var is_heavy := (weight_tier == "medium")
	var box_size := Vector3(1.22, 1.22, 1.22) if is_heavy else Vector3(0.96, 0.96, 0.96)

	var col := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = box_size
	col.shape = box_shape
	add_child(col)

	var mesh_inst := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = box_size
	box_mesh.material = MaterialLibrary.make_wood_crate_material(is_heavy)
	RenderHelper.attach_mesh(mesh_inst, box_mesh)
	add_child(mesh_inst)

	if is_heavy:
		_build_heavy_trim_bands(box_size)

	var label_color := Color(0.99, 0.92, 0.68) if is_heavy else Color(0.24, 0.14, 0.06)
	MaterialLibrary.attach_weight_labels(self, weight_label, box_size, label_color)

	_sensor = Area3D.new()
	var s_col := CollisionShape3D.new()
	var s_box := BoxShape3D.new()
	s_box.size = box_size + Vector3(0.26, 0.26, 0.26)
	s_col.shape = s_box
	_sensor.add_child(s_col)
	_sensor.body_entered.connect(_on_sensor_body_entered)
	add_child(_sensor)


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


func _process(delta: float) -> void:
	if is_smashed:
		_debris_ttl -= delta
		if _debris_ttl <= 0.0:
			queue_free()


func _on_sensor_body_entered(body: Node) -> void:
	if body is PlayerBall3D:
		interact_with_ball(body as PlayerBall3D)


func interact_with_ball(ball: PlayerBall3D) -> void:
	if is_smashed or ball == null or ball.is_respawning:
		return
	if ball.get_current_momentum() >= smash_momentum:
		_shatter(Vector3(ball.linear_velocity.x * 0.4, 8.5, -18.0))
		ball.notify_smash_target(global_position, speed_loss_ratio, 0)


func apply_shockwave(
	origin: Vector3,
	radius: float,
	force: float,
	chain_depth: int,
	ball: PlayerBall3D
) -> void:
	if is_smashed:
		return
	var dist := global_position.distance_to(origin)
	if dist <= radius and force >= 6.0:
		var dir := (global_position - origin).normalized()
		if dir.length_squared() < 0.01:
			dir = Vector3(0.0, 1.0, -1.0).normalized()
		_shatter(dir * 16.0 + Vector3(0.0, 7.0, 0.0))
		if ball != null:
			ball.notify_smash_target(global_position, 0.0, chain_depth)


func _shatter(launch_vel: Vector3) -> void:
	is_smashed = true
	_debris_ttl = 0.75
	collision_layer = 2
	collision_mask = 0
	if _sensor != null:
		_sensor.set_deferred("monitoring", false)
	gravity_scale = 1.0
	linear_damp = 0.1
	linear_velocity = launch_vel
	angular_velocity = Vector3(9.0, 6.0, 11.0)
