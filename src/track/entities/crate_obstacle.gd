class_name CrateObstacle
extends RigidBody3D

const SMASH_MOMENTUM: float = 14.0
const SPEED_LOSS_RATIO: float = 0.08

var is_smashed: bool = false
var _debris_ttl: float = 0.0
var _sensor: Area3D = null


func _ready() -> void:
	mass = 1.2
	gravity_scale = 0.18
	linear_damp = 4.5
	angular_damp = 3.0
	contact_monitor = true
	max_contacts_reported = 4

	var col := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(1.1, 1.1, 1.1)
	col.shape = box_shape
	add_child(col)

	var mesh_inst := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(1.1, 1.1, 1.1)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.88, 0.58, 0.20)
	mat.roughness = 0.65
	box_mesh.material = mat
	RenderHelper.attach_mesh(mesh_inst, box_mesh)
	add_child(mesh_inst)

	_sensor = Area3D.new()
	var s_col := CollisionShape3D.new()
	var s_box := BoxShape3D.new()
	s_box.size = Vector3(1.35, 1.35, 1.35)
	s_col.shape = s_box
	_sensor.add_child(s_col)
	_sensor.body_entered.connect(_on_sensor_body_entered)
	add_child(_sensor)


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
	if ball.get_current_momentum() >= SMASH_MOMENTUM:
		_shatter(Vector3(ball.linear_velocity.x * 0.4, 8.5, -18.0))
		ball.notify_smash_target(global_position, SPEED_LOSS_RATIO, 0)


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
	collision_layer = 0
	collision_mask = 0
	gravity_scale = 1.0
	linear_damp = 0.1
	linear_velocity = launch_vel
	angular_velocity = Vector3(9.0, 6.0, 11.0)
