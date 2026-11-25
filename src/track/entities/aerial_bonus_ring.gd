class_name AerialBonusRing
extends Area3D

signal ring_collected(bonus_seconds: float)

const BONUS_SECONDS: float = 0.8
const RING_BOOST_PER_KG: float = 15.0

var is_collected: bool = false
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
		outer_torus.inner_radius = 0.92
		outer_torus.outer_radius = 1.16
		outer_torus.rings = 28
		outer_torus.ring_segments = 14
		outer_torus.material = MaterialLibrary.make_frosted_acrylic_material(Color(0.18, 0.94, 1.0, 0.82))
		RenderHelper.attach_mesh(outer_ring, outer_torus)
		outer_ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		_visual_root.add_child(outer_ring)

		var inner_ring := MeshInstance3D.new()
		var inner_torus := TorusMesh.new()
		inner_torus.inner_radius = 0.83
		inner_torus.outer_radius = 0.92
		inner_torus.rings = 28
		inner_torus.ring_segments = 12
		inner_torus.material = MaterialLibrary.make_frosted_acrylic_material(Color(1.0, 0.82, 0.24, 0.88))
		RenderHelper.attach_mesh(inner_ring, inner_torus)
		inner_ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		_visual_root.add_child(inner_ring)

		var stem_inst := MeshInstance3D.new()
		var stem_cyl := CylinderMesh.new()
		stem_cyl.top_radius = 0.055
		stem_cyl.bottom_radius = 0.075
		stem_cyl.height = 1.8
		var brass_mat := StandardMaterial3D.new()
		brass_mat.albedo_color = Color(0.85, 0.68, 0.28)
		brass_mat.metallic = 0.78
		brass_mat.roughness = 0.28
		stem_cyl.material = brass_mat
		RenderHelper.attach_mesh(stem_inst, stem_cyl)
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
