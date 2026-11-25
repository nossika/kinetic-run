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
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.92, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.05, 0.85, 1.0)
	mat.emission_energy_multiplier = 1.9
	bm.material = mat
	RenderHelper.attach_mesh(pad_mesh, bm)
	add_child(pad_mesh)

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
