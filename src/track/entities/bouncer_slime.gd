class_name BouncerSlime
extends Node3D

const SMASH_MOMENTUM: float = 22.0
const SPEED_LOSS_RATIO: float = 0.10

var patrol_half_width: float = 2.8
var patrol_speed: float = 2.6
var is_smashed: bool = false

var _origin_x: float = 0.0
var _dir: float = 1.0
var _fly_vel: Vector3 = Vector3.ZERO
var _ttl: float = 0.0
var _hit_cooldown: float = 0.0


func _ready() -> void:
	_origin_x = position.x

	var visual := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.72
	sphere.height = 1.15
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.95, 0.48)
	mat.roughness = 0.25
	mat.emission_enabled = true
	mat.emission = Color(0.10, 0.55, 0.22)
	mat.emission_energy_multiplier = 0.6
	sphere.material = mat
	RenderHelper.attach_mesh(visual, sphere)
	add_child(visual)

	var area := Area3D.new()
	var col := CollisionShape3D.new()
	var s_shape := SphereShape3D.new()
	s_shape.radius = 0.85
	col.shape = s_shape
	area.add_child(col)
	area.body_entered.connect(_on_body_entered)
	add_child(area)


func _physics_process(delta: float) -> void:
	_hit_cooldown = maxf(0.0, _hit_cooldown - delta)
	if is_smashed:
		global_position += _fly_vel * delta
		rotate_x(9.0 * delta)
		_ttl -= delta
		if _ttl <= 0.0:
			queue_free()
		return

	if patrol_half_width > 0.1:
		position.x += _dir * patrol_speed * delta
		if position.x > _origin_x + patrol_half_width:
			position.x = _origin_x + patrol_half_width
			_dir = -1.0
		elif position.x < _origin_x - patrol_half_width:
			position.x = _origin_x - patrol_half_width
			_dir = 1.0


func _on_body_entered(body: Node) -> void:
	if body is PlayerBall3D:
		interact_with_ball(body as PlayerBall3D)


func interact_with_ball(ball: PlayerBall3D) -> void:
	if is_smashed or ball == null or ball.is_respawning:
		return
	if ball.get_current_momentum() >= SMASH_MOMENTUM:
		_smash(Vector3(ball.linear_velocity.x * 0.3, 9.5, -20.0))
		ball.notify_smash_target(global_position, SPEED_LOSS_RATIO, 0)
	elif _hit_cooldown <= 0.0:
		_hit_cooldown = 0.22
		ball.linear_velocity.z = maxf(ball.linear_velocity.z, 0.0) + 8.0
		ball.linear_velocity.x += signf(ball.global_position.x - global_position.x + 0.05) * 4.0
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
	if global_position.distance_to(origin) <= radius and force >= 8.0:
		var dir := (global_position - origin).normalized()
		_smash(dir * 18.0 + Vector3(0.0, 8.0, -6.0))
		if ball != null:
			ball.notify_smash_target(global_position, 0.0, chain_depth)


func _smash(vel: Vector3) -> void:
	is_smashed = true
	_fly_vel = vel
	_ttl = 0.7
