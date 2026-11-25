class_name BouncerSlime
extends Node3D

const SMASH_MOMENTUM: float = 22.0
const SPEED_LOSS_RATIO: float = 0.10

var smash_momentum: float = SMASH_MOMENTUM
var weight_label: String = "3kg"
var patrol_half_width: float = 2.8
var patrol_speed: float = 2.6
var is_smashed: bool = false

var _origin_x: float = 0.0
var _dir: float = 1.0
var _fly_vel: Vector3 = Vector3.ZERO
var _ttl: float = 0.0
var _hit_cooldown: float = 0.0
var _anim_time: float = 0.0
var _bounce_squash: float = 0.0
var _visual_root: Node3D = null
var _sensor: Area3D = null


func _init() -> void:
	set_meta("weight_label", weight_label)


func _ready() -> void:
	_origin_x = position.x

	_visual_root = Node3D.new()
	_visual_root.name = "VisualRoot"
	add_child(_visual_root)

	var outer_inst := MeshInstance3D.new()
	outer_inst.name = "OuterJelly"
	var outer_sphere := SphereMesh.new()
	outer_sphere.radius = 0.64
	outer_sphere.height = 1.12
	outer_sphere.material = MaterialLibrary.make_jelly_outer_material(Color(0.28, 0.95, 0.52))
	RenderHelper.attach_mesh(outer_inst, outer_sphere)
	_visual_root.add_child(outer_inst)

	var core_inst := MeshInstance3D.new()
	core_inst.name = "InnerCore"
	var core_sphere := SphereMesh.new()
	core_sphere.radius = 0.38
	core_sphere.height = 0.68
	core_sphere.material = MaterialLibrary.make_jelly_core_material(Color(0.45, 1.0, 0.62))
	RenderHelper.attach_mesh(core_inst, core_sphere)
	_visual_root.add_child(core_inst)

	MaterialLibrary.attach_weight_labels(self, "3kg", Vector3(1.3, 1.15, 1.3), Color(0.95, 1.0, 0.92))

	_sensor = Area3D.new()
	var col := CollisionShape3D.new()
	var s_shape := SphereShape3D.new()
	s_shape.radius = 0.85
	col.shape = s_shape
	_sensor.add_child(col)
	_sensor.body_entered.connect(_on_body_entered)
	add_child(_sensor)


func _physics_process(delta: float) -> void:
	_hit_cooldown = maxf(0.0, _hit_cooldown - delta)
	_anim_time += delta
	_bounce_squash = maxf(0.0, _bounce_squash - delta * 4.5)

	if is_smashed:
		global_position += _fly_vel * delta
		rotate_x(9.0 * delta)
		_ttl -= delta
		if _ttl <= 0.0:
			queue_free()
		return

	if _visual_root != null:
		var breathe := sin(_anim_time * 5.2) * 0.06
		var pulse := sin(_bounce_squash * PI * 3.0) * _bounce_squash * 0.34
		var sy := clampf(1.0 + breathe - pulse, 0.62, 1.35)
		var sxz := 1.0 / sqrt(sy)
		_visual_root.scale = Vector3(sxz, sy, sxz)

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
	var self_pos := global_position if is_inside_tree() else position
	if ball.get_current_momentum() >= SMASH_MOMENTUM:
		_smash(Vector3(ball.linear_velocity.x * 0.3, 9.5, -20.0))
		ball.notify_smash_target(self_pos, SPEED_LOSS_RATIO, 0)
	elif _hit_cooldown <= 0.0:
		_hit_cooldown = 0.22
		_bounce_squash = 1.0
		var b := global_transform.basis.orthonormalized() if is_inside_tree() else transform.basis.orthonormalized()
		var right_dir := b.x.normalized() if b.x.length_squared() > 0.0001 else Vector3.RIGHT
		var up_dir := b.y.normalized() if b.y.length_squared() > 0.0001 else Vector3.UP
		var uphill_dir := b.z.normalized() if b.z.length_squared() > 0.0001 else Vector3.BACK

		var ball_pos := ball.global_position if ball.is_inside_tree() else ball.position
		var v_lat := ball.linear_velocity.dot(right_dir)
		var v_up := maxf(ball.linear_velocity.dot(up_dir), 0.0)
		var v_uphill := maxf(ball.linear_velocity.dot(uphill_dir), 0.0)
		var lat_push := signf((ball_pos - self_pos).dot(right_dir) + 0.05) * 4.0

		ball.linear_velocity = (
			right_dir * (v_lat + lat_push)
			+ up_dir * (v_up + 1.5)
			+ uphill_dir * (v_uphill + 8.0)
		)
		ball.notify_wall_or_bumper_bounce(uphill_dir, self_pos, 0.0)


func apply_shockwave(
	origin: Vector3,
	radius: float,
	force: float,
	chain_depth: int,
	ball: PlayerBall3D
) -> void:
	if is_smashed:
		return
	var self_pos := global_position if is_inside_tree() else position
	if self_pos.distance_to(origin) <= radius and force >= 8.0:
		var dir := (self_pos - origin).normalized()
		if dir.length_squared() < 0.01:
			dir = Vector3(0.0, 1.0, -1.0).normalized()
		_smash(dir * 18.0 + Vector3(0.0, 8.0, -6.0))
		if ball != null:
			ball.notify_smash_target(self_pos, 0.0, chain_depth)


func _smash(vel: Vector3) -> void:
	is_smashed = true
	if _sensor != null:
		_sensor.set_deferred("monitoring", false)
	_fly_vel = vel
	_ttl = 0.7
