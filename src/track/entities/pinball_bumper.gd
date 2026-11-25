class_name PinballBumper
extends StaticBody3D

const BUMPER_IMPULSE_PER_KG: float = 14.0
var _cooldown: float = 0.0


func _ready() -> void:
	var col := CollisionShape3D.new()
	var cyl_shape := CylinderShape3D.new()
	cyl_shape.radius = 0.72
	cyl_shape.height = 1.3
	col.shape = cyl_shape
	add_child(col)

	var mesh_inst := MeshInstance3D.new()
	var cyl_mesh := CylinderMesh.new()
	cyl_mesh.top_radius = 0.78
	cyl_mesh.bottom_radius = 0.65
	cyl_mesh.height = 1.3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.22, 0.78)
	mat.emission_enabled = true
	mat.emission = Color(0.95, 0.15, 0.72)
	mat.emission_energy_multiplier = 1.6
	cyl_mesh.material = mat
	RenderHelper.attach_mesh(mesh_inst, cyl_mesh)
	add_child(mesh_inst)

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


func _on_sensor_body_entered(body: Node) -> void:
	if body is PlayerBall3D and _cooldown <= 0.0:
		_cooldown = 0.18
		interact_with_ball(body as PlayerBall3D)


func interact_with_ball(ball: PlayerBall3D) -> void:
	if ball == null or ball.is_respawning:
		return
	var diff := ball.global_position - global_position
	diff.y = 0.0
	var normal := diff.normalized() if diff.length_squared() > 0.001 else Vector3.RIGHT
	ball.linear_velocity.x = normal.x * maxf(8.5, absf(ball.linear_velocity.x))
	ball.notify_wall_or_bumper_bounce(normal, global_position, BUMPER_IMPULSE_PER_KG * ball.mass)
