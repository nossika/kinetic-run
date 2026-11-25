class_name SlimeZone
extends Area3D

var zone_size: Vector2 = Vector2(4.0, 6.0)


func _ready() -> void:
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(zone_size.x, 0.45, zone_size.y)
	col.shape = shape
	add_child(col)

	var mesh_inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(zone_size.x, 0.08, zone_size.y)
	mesh.material = MaterialLibrary.make_jelly_outer_material(Color(0.35, 0.88, 0.28))
	RenderHelper.attach_mesh(mesh_inst, mesh)
	add_child(mesh_inst)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if body is PlayerBall3D:
		on_ball_entered(body as PlayerBall3D)


func _on_body_exited(body: Node) -> void:
	if body is PlayerBall3D:
		on_ball_exited(body as PlayerBall3D)


func on_ball_entered(ball: PlayerBall3D) -> void:
	if ball != null:
		ball.set_in_slime_zone(true)


func on_ball_exited(ball: PlayerBall3D) -> void:
	if ball != null:
		ball.set_in_slime_zone(false)
