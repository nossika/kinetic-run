class_name ExplosiveBarrel
extends RigidBody3D

signal barrel_exploded(origin: Vector3, radius: float, force: float, chain_depth: int)

const ABYSS_LOCAL_Y: float = -28.0
const MAX_SHOCKWAVE_SPEED: float = 32.0
const BLAST_RADIUS: float = 6.5
const BLAST_FORCE: float = 30.0
const BALL_BLAST_IMPULSE_PER_KG: float = 16.0
const RB_IMPACT_SPEED_THRESHOLD: float = 2.6

var weight_label: String = "1.5kg"
var is_detonated: bool = false
var is_dislodged: bool = false
var _barrel_mesh_inst: MeshInstance3D = null
var _saved_linear_velocity: Vector3 = Vector3.ZERO
var _queued_shockwave_dv: float = 0.0


func _init() -> void:
	mass = 1.5
	physics_material_override = MaterialLibrary.high_friction_physics(0.72, 0.28)
	contact_monitor = true
	max_contacts_reported = 6
	set_meta("weight_label", weight_label)


func _ready() -> void:
	mass = 0.45 if is_detonated else 1.5
	physics_material_override = MaterialLibrary.high_friction_physics(0.72, 0.28)
	gravity_scale = 1.0
	can_sleep = false
	linear_damp = 0.14 if is_detonated else 1.6
	angular_damp = 0.24 if is_detonated else 2.4
	contact_monitor = true
	max_contacts_reported = 6

	var body_col := CollisionShape3D.new()
	var body_cyl := CylinderShape3D.new()
	body_cyl.radius = 0.52
	body_cyl.height = 1.25
	body_col.shape = body_cyl
	add_child(body_col)

	_barrel_mesh_inst = MeshInstance3D.new()
	_barrel_mesh_inst.name = "BarrelMesh"
	var cyl := ClayMeshBuilder.make_chamfered_cylinder(0.52, 0.52, 1.25, 0.11, 24)
	var b_mat := (
		MaterialLibrary.make_charred_husk_material()
		if is_detonated
		else MaterialLibrary.make_retro_barrel_material()
	)
	ClayMeshBuilder.assign_mesh(_barrel_mesh_inst, cyl, b_mat)
	add_child(_barrel_mesh_inst)

	if DisplayServer.get_name() != "headless":
		var rim_mat := MaterialLibrary.make_silicone_soft_material(Color(0.96, 0.88, 0.74))
		var rim_torus := TorusMesh.new()
		rim_torus.inner_radius = 0.47
		rim_torus.outer_radius = 0.555
		rim_torus.rings = 24
		rim_torus.ring_segments = 12
		rim_torus.material = rim_mat
		for sy in [-1.0, 1.0]:
			var rim_inst := MeshInstance3D.new()
			RenderHelper.attach_mesh(rim_inst, rim_torus)
			rim_inst.position = Vector3(0.0, sy * 0.52, 0.0)
			add_child(rim_inst)

	MaterialLibrary.attach_weight_labels(self, weight_label, Vector3(1.06, 1.25, 1.06), Color(0.50, 0.30, 0.22))
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _physics_process(_delta: float) -> void:
	_queued_shockwave_dv = 0.0
	if not is_detonated and contact_monitor:
		for b in get_colliding_bodies():
			on_body_contact(b)
			if is_detonated:
				break
	_saved_linear_velocity = linear_velocity
	if get_parent() is Node3D and position.y < ABYSS_LOCAL_Y:
		queue_free()


func _on_body_entered(body: Node) -> void:
	on_body_contact(body)


func _on_sensor_body_entered(body: Node) -> void:
	on_body_contact(body)


func on_ball_contact(ball: PlayerBall3D) -> void:
	if is_detonated or ball == null or ball.is_respawning:
		return
	var empty_list: Array[Node3D] = []
	detonate(ball, empty_list, 0)


func on_body_contact(body: Node) -> void:
	if is_detonated or body == null or body == self:
		return
	if body is PlayerBall3D:
		on_ball_contact(body as PlayerBall3D)
	elif body is RigidBody3D:
		var rb := body as RigidBody3D
		var dv_self := linear_velocity - _saved_linear_velocity
		var rb_pre_est := rb.linear_velocity + dv_self * (mass / maxf(0.05, rb.mass))
		var rel_post := (rb.linear_velocity - linear_velocity).length()
		var rel_pre := (rb_pre_est - _saved_linear_velocity).length()
		if maxf(rel_post, rel_pre) > RB_IMPACT_SPEED_THRESHOLD:
			var empty_list: Array[Node3D] = []
			detonate(null, empty_list, 0)


func detonate(ball: PlayerBall3D, nearby_entities: Array[Node3D], chain_depth: int = 0) -> void:
	if is_detonated:
		return
	is_detonated = true
	is_dislodged = true
	visible = true
	collision_layer = 1
	collision_mask = 1
	sleeping = false
	mass = 0.45
	weight_label = "EMPTY"
	linear_damp = 0.14
	angular_damp = 0.24

	var husk_mat := MaterialLibrary.make_charred_husk_material()
	if _barrel_mesh_inst != null:
		_barrel_mesh_inst.material_override = husk_mat
		if _barrel_mesh_inst.mesh is PrimitiveMesh:
			(_barrel_mesh_inst.mesh as PrimitiveMesh).material = husk_mat
	MaterialLibrary.attach_weight_labels(self, "EMPTY", Vector3(1.06, 1.25, 1.06), Color(0.90, 0.86, 0.80))

	var origin := global_position if is_inside_tree() else position
	var b := global_transform.basis.orthonormalized() if is_inside_tree() else transform.basis.orthonormalized()
	var up_dir := b.y.normalized() if b.y.length_squared() > 0.0001 else Vector3.UP
	var fwd_dir := (-b.z).normalized() if b.z.length_squared() > 0.0001 else Vector3.FORWARD
	var right_dir := b.x.normalized() if b.x.length_squared() > 0.0001 else Vector3.RIGHT
	var inward_sign := -signf(position.x) if absf(position.x) > 0.8 else 1.0
	linear_velocity = up_dir * 7.2 + fwd_dir * 6.0 + right_dir * (inward_sign * 1.4)
	angular_velocity = right_dir * 8.5 + b.z.normalized() * (inward_sign * 5.0)
	_saved_linear_velocity = linear_velocity

	if ball != null and not ball.is_respawning:
		var ball_pos := ball.global_position if ball.is_inside_tree() else ball.position
		var dist := ball_pos.distance_to(origin)
		if dist <= BLAST_RADIUS:
			var falloff := clampf(1.0 - (dist / (BLAST_RADIUS * 1.25)), 0.35, 1.0)
			# Forward-biased Tailwind explosion boost
			ball.notify_external_boost(BALL_BLAST_IMPULSE_PER_KG * ball.mass * falloff, origin)

	if chain_depth < PhysicsSynergyBus.MAX_CHAIN_DEPTH:
		for ent in nearby_entities:
			if ent == null or ent == self or not is_instance_valid(ent):
				continue
			if ent.has_method("apply_shockwave"):
				ent.apply_shockwave(origin, BLAST_RADIUS, BLAST_FORCE, chain_depth + 1, ball)

	barrel_exploded.emit(origin, BLAST_RADIUS, BLAST_FORCE, chain_depth + 1)


func apply_shockwave(
	origin: Vector3,
	radius: float,
	force: float,
	chain_depth: int,
	ball: PlayerBall3D
) -> void:
	var self_pos := global_position if is_inside_tree() else position
	var dist := self_pos.distance_to(origin)
	if not is_detonated:
		if chain_depth < PhysicsSynergyBus.MAX_CHAIN_DEPTH and dist <= radius and force >= 8.0:
			var empty_list: Array[Node3D] = []
			detonate(ball, empty_list, chain_depth)
		return

	if dist <= 0.25 or dist > radius or force < 4.0:
		return
	var falloff := clampf(1.0 - (dist / (radius * 1.15)), 0.25, 1.0)
	var radial := self_pos - origin
	radial.y = 0.0
	var dir := radial.normalized() if radial.length_squared() > 0.001 else Vector3(0.25, 0.0, -1.0).normalized()
	var up_dir := global_transform.basis.y.normalized() if is_inside_tree() else Vector3.UP
	var impulse_vec := (dir + up_dir * 0.42).normalized() * (force * 0.85 * falloff)
	var budget_dv := maxf(0.0, MAX_SHOCKWAVE_SPEED - linear_velocity.length() - _queued_shockwave_dv)
	var clamped_vec := impulse_vec.limit_length(budget_dv * mass)
	if clamped_vec.length_squared() > 0.0001:
		apply_impulse(clamped_vec, up_dir * 0.16)
		_queued_shockwave_dv += clamped_vec.length() / maxf(0.05, mass)
	if linear_velocity.length() > MAX_SHOCKWAVE_SPEED:
		linear_velocity = linear_velocity.normalized() * MAX_SHOCKWAVE_SPEED
