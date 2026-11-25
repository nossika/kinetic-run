class_name PinballBumper
extends StaticBody3D

const BUMPER_IMPULSE_PER_KG: float = 14.0

var is_anchored_fixed: bool = true
var _cooldown: float = 0.0
var _ring_pulse: float = 0.0
var _cushion_ring: MeshInstance3D = null


func _init() -> void:
	set_meta("is_anchored_fixed", true)


func _ready() -> void:
	var col := CollisionShape3D.new()
	var cyl_shape := CylinderShape3D.new()
	cyl_shape.radius = 0.72
	cyl_shape.height = 1.3
	col.shape = cyl_shape
	add_child(col)

	MaterialLibrary.attach_anchored_flange_base(self, -0.65, 0.82, 0.82, true)

	var post_inst := MeshInstance3D.new()
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.44
	post_mesh.bottom_radius = 0.50
	post_mesh.height = 1.24
	var post_mat := MaterialLibrary.make_cast_iron_material(Color(0.55, 0.58, 0.65))
	post_mat.metallic = 0.84
	post_mat.roughness = 0.24
	post_mesh.material = post_mat
	RenderHelper.attach_mesh(post_inst, post_mesh)
	add_child(post_inst)

	_cushion_ring = MeshInstance3D.new()
	_cushion_ring.name = "SiliconeBounceRing"
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.42
	ring_mesh.outer_radius = 0.80
	ring_mesh.rings = 24
	ring_mesh.ring_segments = 16
	ring_mesh.material = MaterialLibrary.make_silicone_soft_material(Color(1.0, 0.38, 0.62))
	RenderHelper.attach_mesh(_cushion_ring, ring_mesh)
	_cushion_ring.position = Vector3(0.0, 0.08, 0.0)
	add_child(_cushion_ring)

	var sensor := Area3D.new()
	var s_col := CollisionShape3D.new()
	var s_cyl := CylinderShape3D.new()
	s_cyl.radius = 0.95
	s_cyl.height = 1.4
	s_col.shape = s_cyl
	sensor.add_child(s_col)
	sensor.body_entered.connect(_on_sensor_body_entered)
	add_child(sensor)


func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	_ring_pulse = maxf(0.0, _ring_pulse - delta * 6.0)
	if _cushion_ring != null:
		var expand := sin(_ring_pulse * PI) * 0.18
		_cushion_ring.scale = Vector3(1.0 + expand, 1.0 - expand * 0.4, 1.0 + expand)


func _on_sensor_body_entered(body: Node) -> void:
	if body is PlayerBall3D and _cooldown <= 0.0:
		_cooldown = 0.18
		interact_with_ball(body as PlayerBall3D)


func interact_with_ball(ball: PlayerBall3D) -> void:
	if ball == null or ball.is_respawning:
		return
	_ring_pulse = 1.0
	var diff := ball.global_position - global_position
	diff.y = 0.0
	var normal := diff.normalized() if diff.length_squared() > 0.001 else Vector3.RIGHT
	ball.linear_velocity.x = normal.x * maxf(8.5, absf(ball.linear_velocity.x))
	ball.notify_wall_or_bumper_bounce(normal, global_position, BUMPER_IMPULSE_PER_KG * ball.mass)
