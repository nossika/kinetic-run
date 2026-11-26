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
	var pebble := ClayMeshBuilder.make_pebble_pad(Vector2(2.3, 3.5), 0.10, 24)
	var pad_mat := MaterialLibrary.make_silicone_soft_material(Color(0.18, 0.80, 0.46))
	ClayMeshBuilder.assign_mesh(pad_mesh, pebble, pad_mat)
	add_child(pad_mesh)

	if DisplayServer.get_name() != "headless":
		var chev_mat := MaterialLibrary.make_silicone_soft_material(Color(0.99, 0.98, 0.92), false)
		chev_mat.emission_enabled = true
		chev_mat.emission = Color(0.76, 0.98, 0.88)
		chev_mat.emission_energy_multiplier = 0.35

		var arm_cap := CapsuleMesh.new()
		arm_cap.radius = 0.055
		arm_cap.height = 0.74
		arm_cap.radial_segments = 12
		arm_cap.material = chev_mat

		for z_off in [0.92, 0.0, -0.92]:
			var left_arm := MeshInstance3D.new()
			RenderHelper.attach_mesh(left_arm, arm_cap)
			left_arm.position = Vector3(-0.28, 0.062, z_off)
			left_arm.rotation_degrees = Vector3(90.0, -56.0, 0.0)
			add_child(left_arm)

			var right_arm := MeshInstance3D.new()
			RenderHelper.attach_mesh(right_arm, arm_cap)
			right_arm.position = Vector3(0.28, 0.062, z_off)
			right_arm.rotation_degrees = Vector3(90.0, 56.0, 0.0)
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
