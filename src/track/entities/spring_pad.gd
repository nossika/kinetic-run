class_name SpringPad
extends Area3D

const UPWARD_LAUNCH_SPEED: float = 11.5
const FORWARD_BOOST_PER_KG: float = 6.5

var is_anchored_fixed: bool = true
var _cooldown: float = 0.0
var _spring_anim: float = 0.0
var _coil_root: Node3D = null
var _top_pad: Node3D = null


func _init() -> void:
	set_meta("is_anchored_fixed", true)


func _ready() -> void:
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.3, 0.85, 2.5)
	col.shape = box
	col.position = Vector3(0.0, 0.35, 0.0)
	add_child(col)

	MaterialLibrary.attach_anchored_flange_base(self, 0.0, 1.15, 1.25, false)

	_coil_root = Node3D.new()
	_coil_root.name = "HelicalCoils"
	_coil_root.position = Vector3(0.0, 0.06, 0.0)
	add_child(_coil_root)

	_top_pad = Node3D.new()
	_top_pad.name = "SiliconeTopPad"
	_top_pad.position = Vector3(0.0, 0.30, 0.0)
	add_child(_top_pad)

	if DisplayServer.get_name() != "headless":
		var coil_mat := MaterialLibrary.make_cast_iron_material(Color(0.24, 0.26, 0.30))
		var coil_torus := TorusMesh.new()
		coil_torus.inner_radius = 0.56
		coil_torus.outer_radius = 0.70
		coil_torus.rings = 20
		coil_torus.ring_segments = 12
		coil_torus.material = coil_mat

		for i in range(3):
			var ring_inst := MeshInstance3D.new()
			RenderHelper.attach_mesh(ring_inst, coil_torus)
			ring_inst.position = Vector3(0.0, 0.04 + float(i) * 0.085, 0.0)
			ring_inst.rotation_degrees = Vector3(0.0, float(i) * 45.0, 4.0)
			_coil_root.add_child(ring_inst)

		var pad_inst := MeshInstance3D.new()
		var pad_box := BoxMesh.new()
		pad_box.size = Vector3(2.05, 0.12, 2.20)
		pad_box.material = MaterialLibrary.make_silicone_soft_material(Color(1.0, 0.84, 0.16))
		RenderHelper.attach_mesh(pad_inst, pad_box)
		_top_pad.add_child(pad_inst)

	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	_spring_anim = maxf(0.0, _spring_anim - delta * 4.5)

	var lift := sin(_spring_anim * PI) * 0.32
	if _top_pad != null:
		_top_pad.position.y = 0.30 + lift
	if _coil_root != null:
		_coil_root.scale.y = 1.0 + lift * 2.2


func _on_body_entered(body: Node) -> void:
	if body is PlayerBall3D and _cooldown <= 0.0:
		_cooldown = 0.28
		interact_with_ball(body as PlayerBall3D)


func interact_with_ball(ball: PlayerBall3D) -> void:
	if ball == null or ball.is_respawning:
		return
	_spring_anim = 1.0
	var up_dir := (global_transform.basis.y if is_inside_tree() else transform.basis.y).normalized()
	var cur_up := ball.linear_velocity.dot(up_dir)
	if cur_up < UPWARD_LAUNCH_SPEED:
		ball.linear_velocity += up_dir * (UPWARD_LAUNCH_SPEED - cur_up)
	var origin := global_position if is_inside_tree() else position
	ball.notify_external_boost(FORWARD_BOOST_PER_KG * ball.mass, origin)
