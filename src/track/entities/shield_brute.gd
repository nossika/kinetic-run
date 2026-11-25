class_name ShieldBrute
extends Node3D

const SMASH_MOMENTUM: float = 42.0
const SPEED_LOSS_RATIO: float = 0.15

var is_smashed: bool = false
var _fly_vel: Vector3 = Vector3.ZERO
var _ttl: float = 0.0
var _hit_cooldown: float = 0.0


func _ready() -> void:
	var body_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.5, 1.45, 1.1)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.82, 0.18, 0.24)
	mat.metallic = 0.65
	mat.roughness = 0.32
	mat.emission_enabled = true
	mat.emission = Color(0.45, 0.06, 0.10)
	mat.emission_energy_multiplier = 0.5
	box.material = mat
	RenderHelper.attach_mesh(body_mesh, box)
	add_child(body_mesh)

	var area := Area3D.new()
	var col := CollisionShape3D.new()
	var b_shape := BoxShape3D.new()
	b_shape.size = Vector3(1.65, 1.55, 1.25)
	col.shape = b_shape
	area.add_child(col)
	area.body_entered.connect(_on_body_entered)
	add_child(area)


func _physics_process(delta: float) -> void:
	_hit_cooldown = maxf(0.0, _hit_cooldown - delta)
	if is_smashed:
		global_position += _fly_vel * delta
		rotate_z(8.0 * delta)
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
		_smash(Vector3(0.0, 10.0, -22.0))
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
		_smash(dir * 16.0 + Vector3(0.0, 9.0, -8.0))
		if ball != null:
			ball.notify_smash_target(global_position, 0.0, chain_depth)


func _smash(vel: Vector3) -> void:
	is_smashed = true
	_fly_vel = vel
	_ttl = 0.75
