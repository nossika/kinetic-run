class_name BoostPad
extends Area3D

const BOOST_IMPULSE_PER_KG: float = 18.0
var _cooldown: float = 0.0


func _ready() -> void:
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.4, 0.6, 3.6)
	col.shape = shape
	add_child(col)

	var pad_mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.3, 0.10, 3.5)
	bm.material = MaterialLibrary.make_frosted_acrylic_material(Color(0.12, 0.88, 0.98))
	RenderHelper.attach_mesh(pad_mesh, bm)
	add_child(pad_mesh)

	if DisplayServer.get_name() != "headless":
		var chev_mat := StandardMaterial3D.new()
		chev_mat.albedo_color = Color(0.80, 1.0, 0.98)
		chev_mat.emission_enabled = true
		chev_mat.emission = Color(0.24, 0.96, 0.92)
		chev_mat.emission_energy_multiplier = 0.95

		var arm_mesh := BoxMesh.new()
		arm_mesh.size = Vector3(0.76, 0.035, 0.17)
		arm_mesh.material = chev_mat

		for z_off in [0.95, 0.0, -0.95]:
			var left_arm := MeshInstance3D.new()
			RenderHelper.attach_mesh(left_arm, arm_mesh)
			left_arm.position = Vector3(-0.32, 0.068, z_off)
			left_arm.rotation_degrees = Vector3(0.0, 32.0, 0.0)
			add_child(left_arm)

			var right_arm := MeshInstance3D.new()
			RenderHelper.attach_mesh(right_arm, arm_mesh)
			right_arm.position = Vector3(0.32, 0.068, z_off)
			right_arm.rotation_degrees = Vector3(0.0, -32.0, 0.0)
			add_child(right_arm)

	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)


func _on_body_entered(body: Node) -> void:
	if body is PlayerBall3D and _cooldown <= 0.0:
		_cooldown = 0.25
		interact_with_ball(body as PlayerBall3D)


func interact_with_ball(ball: PlayerBall3D) -> void:
	if ball == null or ball.is_respawning:
		return
	ball.notify_external_boost(BOOST_IMPULSE_PER_KG * ball.mass, global_position)
