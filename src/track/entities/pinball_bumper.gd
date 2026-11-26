class_name PinballBumper
extends StaticBody3D

const BUMPER_IMPULSE_PER_KG: float = 14.0
const BUMPER_COOLDOWN: float = 0.16
const MIN_RADIAL_KICK_SPEED: float = 8.5

var is_anchored_fixed: bool = true
var _cooldown: float = 0.0
var _ring_pulse: float = 0.0
var _cushion_ring: MeshInstance3D = null


func _init() -> void:
	set_meta("is_anchored_fixed", true)
	add_to_group("pinball_bumper")
	physics_material_override = MaterialLibrary.high_friction_physics(0.05, 0.95)


func _ready() -> void:
	add_to_group("pinball_bumper")
	physics_material_override = MaterialLibrary.high_friction_physics(0.05, 0.95)

	var col := CollisionShape3D.new()
	var cyl_shape := CylinderShape3D.new()
	cyl_shape.radius = 0.72
	cyl_shape.height = 1.3
	col.shape = cyl_shape
	add_child(col)

	MaterialLibrary.attach_anchored_flange_base(self, -0.65, 0.76, 0.76, false)

	var post_inst := MeshInstance3D.new()
	var post_mesh := ClayMeshBuilder.make_chamfered_cylinder(0.46, 0.50, 1.20, 0.16, 24)
	var post_mat := MaterialLibrary.make_silicone_soft_material(Color(0.98, 0.94, 0.87))
	ClayMeshBuilder.assign_mesh(post_inst, post_mesh, post_mat)
	add_child(post_inst)

	_cushion_ring = MeshInstance3D.new()
	_cushion_ring.name = "SiliconeBounceRing"
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.42
	ring_mesh.outer_radius = 0.80
	ring_mesh.rings = 28
	ring_mesh.ring_segments = 16
	ring_mesh.material = MaterialLibrary.make_silicone_soft_material(Color(0.95, 0.54, 0.58))
	RenderHelper.attach_mesh(_cushion_ring, ring_mesh)
	_cushion_ring.position = Vector3(0.0, 0.10, 0.0)
	add_child(_cushion_ring)
	call_deferred("_bind_ball_contact_fallback")


func _bind_ball_contact_fallback() -> void:
	if not is_inside_tree():
		return
	var p := get_parent()
	while p != null:
		for ch in p.get_children():
			if ch is PlayerBall3D:
				var ball := ch as PlayerBall3D
				var cb := Callable(self, "_on_ball_body_entered").bind(ball)
				if not ball.body_entered.is_connected(cb):
					ball.body_entered.connect(cb)
				return
		if p.get_parent() == get_tree().root:
			break
		p = p.get_parent()


func _on_ball_body_entered(collided_body: Node, ball: PlayerBall3D) -> void:
	if collided_body != self or ball == null or ball.is_respawning or ball.has_method("notify_obstacle_impact"):
		return
	interact_with_ball(ball)


func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	_ring_pulse = maxf(0.0, _ring_pulse - delta * 6.0)
	if _cushion_ring != null:
		var expand := sin(_ring_pulse * PI) * 0.18
		_cushion_ring.scale = Vector3(1.0 + expand, 1.0 - expand * 0.4, 1.0 + expand)


func trigger_bumper_bounce(ball: PlayerBall3D, contact_normal: Vector3) -> void:
	if ball == null or ball.is_respawning or _cooldown > 0.0:
		return
	_cooldown = BUMPER_COOLDOWN
	_ring_pulse = 1.0
	var self_pos := global_position if is_inside_tree() else position
	var ball_pos := ball.global_position if ball.is_inside_tree() else ball.position
	var horiz_n := Vector3(contact_normal.x, 0.0, contact_normal.z)
	if horiz_n.length_squared() < 0.0001:
		var diff := ball_pos - self_pos
		diff.y = 0.0
		horiz_n = diff.normalized() if diff.length_squared() > 0.0001 else Vector3.RIGHT
	else:
		horiz_n = horiz_n.normalized()
	var radial_diff := Vector3(ball_pos.x - self_pos.x, 0.0, ball_pos.z - self_pos.z)
	if radial_diff.length_squared() > 0.001 and horiz_n.dot(radial_diff) < 0.0:
		horiz_n = -horiz_n

	var v_rad := ball.linear_velocity.dot(horiz_n)
	if v_rad < MIN_RADIAL_KICK_SPEED:
		ball.linear_velocity += horiz_n * (MIN_RADIAL_KICK_SPEED - v_rad)
	ball.notify_wall_or_bumper_bounce(horiz_n, self_pos, BUMPER_IMPULSE_PER_KG * ball.mass)


func interact_with_ball(ball: PlayerBall3D) -> void:
	if ball == null:
		return
	var self_pos := global_position if is_inside_tree() else position
	var ball_pos := ball.global_position if ball.is_inside_tree() else ball.position
	var diff := ball_pos - self_pos
	diff.y = 0.0
	var normal := diff.normalized() if diff.length_squared() > 0.0001 else Vector3.RIGHT
	trigger_bumper_bounce(ball, normal)
