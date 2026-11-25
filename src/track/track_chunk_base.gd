class_name TrackChunkBase
extends Node3D

const STANDARD_WIDTH: float = 10.0
const FLOOR_THICKNESS: float = 0.6

var chunk_type: String = "StraightWide"
var length: float = 26.0
var entry_z: float = 0.0
var exit_z: float = -26.0


func build_chunk(p_type: String, p_entry_z: float) -> void:
	chunk_type = p_type
	entry_z = p_entry_z
	position = Vector3(0.0, 0.0, entry_z)

	match chunk_type:
		"StraightWide":
			length = 26.0
			_build_straight_wide()
		"NarrowBridge":
			length = 24.0
			_build_narrow_bridge()
		"SplitPath":
			length = 32.0
			_build_split_path()
		"RampGap":
			length = 28.0
			_build_ramp_gap()
		"PinballAlley":
			length = 26.0
			_build_pinball_alley()
		"FunnelGauntlet":
			length = 30.0
			_build_funnel_gauntlet()
		_:
			length = 26.0
			_build_straight_wide()

	exit_z = entry_z - length


func _add_floor_slab(local_pos: Vector3, size: Vector3, color: Color, rot_deg: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = local_pos
	body.rotation_degrees = rot_deg
	var phys_mat := PhysicsMaterial.new()
	phys_mat.friction = 0.35
	phys_mat.bounce = 0.15
	body.physics_material_override = phys_mat

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)

	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.55
	mat.metallic = 0.25
	box.material = mat
	RenderHelper.attach_mesh(mesh_inst, box)
	body.add_child(mesh_inst)

	add_child(body)
	return body


func _add_guard_rail(local_pos: Vector3, size: Vector3, color: Color, yaw_deg: float = 0.0) -> StaticBody3D:
	var rail := StaticBody3D.new()
	rail.add_to_group("track_rail")
	rail.position = local_pos
	rail.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	var phys_mat := PhysicsMaterial.new()
	phys_mat.friction = 0.08
	phys_mat.bounce = 0.55
	rail.physics_material_override = phys_mat

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	rail.add_child(col)

	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color * 0.75
	mat.emission_energy_multiplier = 1.1
	box.material = mat
	RenderHelper.attach_mesh(mesh_inst, box)
	rail.add_child(mesh_inst)

	add_child(rail)
	return rail


func _add_speed_stripes(z_len: float, half_w: float) -> void:
	var stripe_mat := StandardMaterial3D.new()
	stripe_mat.albedo_color = Color(0.22, 0.32, 0.50)
	var count := int(z_len / 6.0)
	for i in range(count):
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(half_w * 1.6, 0.02, 0.35)
		bm.material = stripe_mat
		RenderHelper.attach_mesh(m, bm)
		m.position = Vector3(0.0, 0.01, -float(i) * 6.0 - 3.0)
		add_child(m)


func _build_straight_wide() -> void:
	_add_floor_slab(
		Vector3(0.0, -FLOOR_THICKNESS * 0.5, -length * 0.5),
		Vector3(STANDARD_WIDTH, FLOOR_THICKNESS, length),
		Color(0.11, 0.15, 0.23)
	)
	_add_speed_stripes(length, 4.2)
	var rail_col := Color(0.18, 0.68, 0.98)
	_add_guard_rail(Vector3(-5.2, 0.55, -length * 0.5), Vector3(0.4, 1.1, length), rail_col)
	_add_guard_rail(Vector3(5.2, 0.55, -length * 0.5), Vector3(0.4, 1.1, length), rail_col)


func _build_narrow_bridge() -> void:
	# Entry & exit transition aprons + 4.2m narrow unrailed bridge
	_add_floor_slab(
		Vector3(0.0, -FLOOR_THICKNESS * 0.5, -2.0),
		Vector3(8.0, FLOOR_THICKNESS, 4.0),
		Color(0.14, 0.16, 0.25)
	)
	_add_floor_slab(
		Vector3(0.0, -FLOOR_THICKNESS * 0.5, -12.0),
		Vector3(4.2, FLOOR_THICKNESS, 16.0),
		Color(0.20, 0.16, 0.28)
	)
	_add_floor_slab(
		Vector3(0.0, -FLOOR_THICKNESS * 0.5, -22.0),
		Vector3(8.0, FLOOR_THICKNESS, 4.0),
		Color(0.14, 0.16, 0.25)
	)
	# Visual hazard edge trim (non-blocking height)
	var trim_mat := StandardMaterial3D.new()
	trim_mat.albedo_color = Color(1.0, 0.55, 0.12)
	trim_mat.emission_enabled = true
	trim_mat.emission = Color(1.0, 0.42, 0.08)
	for side in [-2.05, 2.05]:
		var trim := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.12, 0.06, 16.0)
		bm.material = trim_mat
		RenderHelper.attach_mesh(trim, bm)
		trim.position = Vector3(side, 0.03, -12.0)
		add_child(trim)


func _build_split_path() -> void:
	_add_floor_slab(
		Vector3(0.0, -FLOOR_THICKNESS * 0.5, -length * 0.5),
		Vector3(STANDARD_WIDTH + 1.2, FLOOR_THICKNESS, length),
		Color(0.10, 0.14, 0.22)
	)
	var rail_col := Color(0.25, 0.80, 0.95)
	_add_guard_rail(Vector3(-5.8, 0.55, -length * 0.5), Vector3(0.4, 1.1, length), rail_col)
	_add_guard_rail(Vector3(5.8, 0.55, -length * 0.5), Vector3(0.4, 1.1, length), rail_col)
	# Central divider island separating risk/reward left lane and safer right lane
	_add_guard_rail(Vector3(0.0, 0.65, -length * 0.5), Vector3(1.4, 1.3, 20.0), Color(0.95, 0.42, 0.25))


func _build_ramp_gap() -> void:
	# Entry deck [0 .. -8]
	_add_floor_slab(
		Vector3(0.0, -FLOOR_THICKNESS * 0.5, -4.0),
		Vector3(STANDARD_WIDTH, FLOOR_THICKNESS, 8.0),
		Color(0.12, 0.16, 0.24)
	)
	# Central 18-deg launch ramp [-8 .. -14], flush at Z=-8 (y=0) rising to y=+1.85m at Z=-14
	_add_floor_slab(
		Vector3(0.0, 0.65, -11.0),
		Vector3(5.2, 0.45, 6.4),
		Color(0.18, 0.45, 0.82),
		Vector3(18.0, 0.0, 0.0)
	)
	# Auxiliary side bridges spanning [-8 .. -20] so low-speed balls can bypass chasm
	_add_floor_slab(
		Vector3(-4.1, -FLOOR_THICKNESS * 0.5, -14.0),
		Vector3(1.8, FLOOR_THICKNESS, 12.0),
		Color(0.16, 0.20, 0.30)
	)
	_add_floor_slab(
		Vector3(4.1, -FLOOR_THICKNESS * 0.5, -14.0),
		Vector3(1.8, FLOOR_THICKNESS, 12.0),
		Color(0.16, 0.20, 0.30)
	)
	# Landing deck [-20 .. -28]
	_add_floor_slab(
		Vector3(0.0, -FLOOR_THICKNESS * 0.5, -24.0),
		Vector3(STANDARD_WIDTH, FLOOR_THICKNESS, 8.0),
		Color(0.12, 0.16, 0.24)
	)
	var rail_col := Color(0.28, 0.72, 1.0)
	_add_guard_rail(Vector3(-5.2, 0.55, -length * 0.5), Vector3(0.4, 1.1, length), rail_col)
	_add_guard_rail(Vector3(5.2, 0.55, -length * 0.5), Vector3(0.4, 1.1, length), rail_col)


func _build_pinball_alley() -> void:
	_add_floor_slab(
		Vector3(0.0, -FLOOR_THICKNESS * 0.5, -length * 0.5),
		Vector3(STANDARD_WIDTH, FLOOR_THICKNESS, length),
		Color(0.15, 0.11, 0.24)
	)
	_add_speed_stripes(length, 4.0)
	var rail_col := Color(0.95, 0.25, 0.80)
	_add_guard_rail(Vector3(-5.2, 0.65, -length * 0.5), Vector3(0.45, 1.3, length), rail_col)
	_add_guard_rail(Vector3(5.2, 0.65, -length * 0.5), Vector3(0.45, 1.3, length), rail_col)


func _build_funnel_gauntlet() -> void:
	_add_floor_slab(
		Vector3(0.0, -FLOOR_THICKNESS * 0.5, -length * 0.5),
		Vector3(STANDARD_WIDTH, FLOOR_THICKNESS, length),
		Color(0.18, 0.12, 0.16)
	)
	var rail_col := Color(1.0, 0.32, 0.22)
	_add_guard_rail(Vector3(-5.2, 0.65, -length * 0.5), Vector3(0.45, 1.3, length), rail_col)
	_add_guard_rail(Vector3(5.2, 0.65, -length * 0.5), Vector3(0.45, 1.3, length), rail_col)
	# Angled inner funnel bumpers narrowing middle corridor
	_add_guard_rail(Vector3(-3.8, 0.55, -10.0), Vector3(0.4, 1.1, 9.0), rail_col, -10.0)
	_add_guard_rail(Vector3(3.8, 0.55, -10.0), Vector3(0.4, 1.1, 9.0), rail_col, 10.0)
