class_name ExplosiveBarrel
extends RigidBody3D

signal barrel_exploded(origin: Vector3, radius: float, force: float, chain_depth: int)

const BLAST_RADIUS: float = 6.5
const BLAST_FORCE: float = 30.0
const BALL_BLAST_IMPULSE_PER_KG: float = 16.0
const RB_IMPACT_SPEED_THRESHOLD: float = 2.8

var weight_label: String = "1.5kg"
var is_detonated: bool = false
var _sensor: Area3D = null


func _init() -> void:
	mass = 1.5
	set_meta("weight_label", weight_label)


func _ready() -> void:
	mass = 1.5
	physics_material_override = MaterialLibrary.high_friction_physics(0.90, 0.08)
	gravity_scale = 1.0
	linear_damp = 1.6
	angular_damp = 2.4
	contact_monitor = true
	max_contacts_reported = 4

	var body_col := CollisionShape3D.new()
	var body_cyl := CylinderShape3D.new()
	body_cyl.radius = 0.52
	body_cyl.height = 1.25
	body_col.shape = body_cyl
	add_child(body_col)

	var mesh_inst := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.52
	cyl.bottom_radius = 0.52
	cyl.height = 1.25
	cyl.material = MaterialLibrary.make_retro_barrel_material()
	RenderHelper.attach_mesh(mesh_inst, cyl)
	add_child(mesh_inst)

	if DisplayServer.get_name() != "headless":
		var rim_mat := MaterialLibrary.make_cast_iron_material(Color(0.36, 0.38, 0.43))
		var rim_mesh := CylinderMesh.new()
		rim_mesh.top_radius = 0.545
		rim_mesh.bottom_radius = 0.545
		rim_mesh.height = 0.07
		rim_mesh.material = rim_mat
		for sy in [-1.0, 1.0]:
			var rim_inst := MeshInstance3D.new()
			RenderHelper.attach_mesh(rim_inst, rim_mesh)
			rim_inst.position = Vector3(0.0, sy * 0.59, 0.0)
			add_child(rim_inst)

	MaterialLibrary.attach_weight_labels(self, "1.5kg", Vector3(1.06, 1.25, 1.06), Color(0.98, 0.96, 0.90))

	_sensor = Area3D.new()
	_sensor.collision_mask = 3
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.78
	shape.height = 1.4
	col.shape = shape
	_sensor.add_child(col)
	_sensor.body_entered.connect(_on_sensor_body_entered)
	add_child(_sensor)


func _on_sensor_body_entered(body: Node) -> void:
	if is_detonated or body == null or body == self:
		return
	if body is PlayerBall3D:
		var empty_list: Array[Node3D] = []
		detonate(body as PlayerBall3D, empty_list, 0)
	elif body is RigidBody3D:
		var rb := body as RigidBody3D
		if rb.linear_velocity.length() > RB_IMPACT_SPEED_THRESHOLD:
			var empty_list: Array[Node3D] = []
			detonate(null, empty_list, 0)


func detonate(ball: PlayerBall3D, nearby_entities: Array[Node3D], chain_depth: int = 0) -> void:
	if is_detonated:
		return
	is_detonated = true
	visible = false
	collision_layer = 0
	collision_mask = 0
	if _sensor != null:
		_sensor.set_deferred("monitoring", false)

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
