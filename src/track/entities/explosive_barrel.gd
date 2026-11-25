class_name ExplosiveBarrel
extends Node3D

signal barrel_exploded(origin: Vector3, radius: float, force: float, chain_depth: int)

const BLAST_RADIUS: float = 6.5
const BLAST_FORCE: float = 30.0
const BALL_BLAST_IMPULSE_PER_KG: float = 16.0

var is_detonated: bool = false


func _ready() -> void:
	var mesh_inst := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.52
	cyl.bottom_radius = 0.52
	cyl.height = 1.25
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.36, 0.08)
	mat.emission_enabled = true
	mat.emission = Color(0.95, 0.25, 0.04)
	mat.emission_energy_multiplier = 1.2
	cyl.material = mat
	RenderHelper.attach_mesh(mesh_inst, cyl)
	add_child(mesh_inst)

	var sensor := Area3D.new()
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.78
	shape.height = 1.4
	col.shape = shape
	sensor.add_child(col)
	sensor.body_entered.connect(_on_sensor_body_entered)
	add_child(sensor)


func _on_sensor_body_entered(body: Node) -> void:
	if is_detonated:
		return
	if body is PlayerBall3D:
		var empty_list: Array[Node3D] = []
		detonate(body as PlayerBall3D, empty_list, 0)


func detonate(ball: PlayerBall3D, nearby_entities: Array[Node3D], chain_depth: int = 0) -> void:
	if is_detonated:
		return
	is_detonated = true
	visible = false

	var origin := global_position

	if ball != null and not ball.is_respawning:
		var dist := ball.global_position.distance_to(origin)
		if dist <= BLAST_RADIUS:
			var falloff := clampf(1.0 - (dist / (BLAST_RADIUS * 1.25)), 0.35, 1.0)
			# Forward-biased Tailwind explosion boost (backward component attenuated 70%)
			ball.notify_external_boost(BALL_BLAST_IMPULSE_PER_KG * ball.mass * falloff, origin)

	if chain_depth < PhysicsSynergyBus.MAX_CHAIN_DEPTH:
		for ent in nearby_entities:
			if ent == null or ent == self or not is_instance_valid(ent):
				continue
			if ent.has_method("apply_shockwave"):
				ent.apply_shockwave(origin, BLAST_RADIUS, BLAST_FORCE, chain_depth + 1, ball)

	barrel_exploded.emit(origin, BLAST_RADIUS, BLAST_FORCE, chain_depth + 1)
	queue_free()


func apply_shockwave(
	origin: Vector3,
	radius: float,
	force: float,
	chain_depth: int,
	ball: PlayerBall3D
) -> void:
	if is_detonated or chain_depth >= PhysicsSynergyBus.MAX_CHAIN_DEPTH:
		return
	if global_position.distance_to(origin) <= radius and force >= 8.0:
		var empty_list: Array[Node3D] = []
		detonate(ball, empty_list, chain_depth)
