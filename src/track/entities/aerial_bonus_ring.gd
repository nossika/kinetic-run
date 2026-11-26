class_name AerialBonusRing
extends Area3D

signal ring_collected(bonus_seconds: float)

const BONUS_SECONDS: float = 0.8
const RING_BOOST_PER_KG: float = 15.0

var is_collected: bool = false
var with_ground_stem: bool = true
var _visual_root: Node3D = null


func _ready() -> void:
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.35
	col.shape = sphere
	add_child(col)

	_visual_root = Node3D.new()
	_visual_root.name = "VisualRoot"
	add_child(_visual_root)

	if DisplayServer.get_name() != "headless":
		var outer_ring := MeshInstance3D.new()
		var outer_torus := TorusMesh.new()
		outer_torus.inner_radius = 0.90
		outer_torus.outer_radius = 1.18
		outer_torus.rings = 32
		outer_torus.ring_segments = 16
		outer_torus.material = MaterialLibrary.make_silicone_soft_material(Color(0.98, 0.68, 0.14))
		RenderHelper.attach_mesh(outer_ring, outer_torus)
		outer_ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		_visual_root.add_child(outer_ring)

		var inner_ring := MeshInstance3D.new()
		var inner_torus := TorusMesh.new()
		inner_torus.inner_radius = 0.81
		inner_torus.outer_radius = 0.91
		inner_torus.rings = 32
		inner_torus.ring_segments = 14
		inner_torus.material = MaterialLibrary.make_frosted_acrylic_material(Color(0.52, 0.90, 0.76, 0.88))
		RenderHelper.attach_mesh(inner_ring, inner_torus)
		inner_ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		_visual_root.add_child(inner_ring)

		if with_ground_stem:
			var stem_inst := MeshInstance3D.new()
			var stem_cap := CapsuleMesh.new()
			stem_cap.radius = 0.075
			stem_cap.height = 1.85
			stem_cap.radial_segments = 14
			stem_cap.material = MaterialLibrary.make_beechwood_material(Color(0.96, 0.88, 0.76))
			RenderHelper.attach_mesh(stem_inst, stem_cap)
			stem_inst.position = Vector3(0.0, -2.0, 0.0)
			_visual_root.add_child(stem_inst)

	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body is PlayerBall3D:
		interact_with_ball(body as PlayerBall3D)


func interact_with_ball(ball: PlayerBall3D) -> void:
	if is_collected or ball == null or ball.is_respawning:
		return
	is_collected = true
	visible = false
	var origin := global_position if is_inside_tree() else position
	ball.notify_external_boost(RING_BOOST_PER_KG * ball.mass, origin)
	ring_collected.emit(BONUS_SECONDS)
	queue_free()
