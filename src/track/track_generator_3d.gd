class_name TrackGenerator3D
extends Node3D

signal finish_crossed
signal barrel_detonated(origin: Vector3, radius: float, force: float, chain_depth: int)

const START_APRON_LEN: float = 10.0
const FINISH_RUNWAY_LEN: float = 10.0

var active_chunks: Array[TrackChunkBase] = []
var active_entities: Array[Node3D] = []
var finish_z: float = -130.0
var total_length: float = 130.0

var _track_root: Node3D = null


func clear_track() -> void:
	active_chunks.clear()
	active_entities.clear()
	if _track_root != null and is_instance_valid(_track_root):
		remove_child(_track_root)
		_track_root.free()
	_track_root = null


func generate_track(level: int, seed_val: int) -> Dictionary:
	clear_track()
	_track_root = Node3D.new()
	_track_root.name = "GeneratedTrack"
	add_child(_track_root)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	var target_len := RunState.target_length_for_level(level)

	# 1. Build starting safe platform [Z = +4 .. -START_APRON_LEN]
	_build_start_platform()
	var cursor_z := -START_APRON_LEN

	# 2. Concatenate modular chunks until cursor_z reaches -target_len
	var chunk_pool: Array[String] = [
		"StraightWide",
		"NarrowBridge",
		"SplitPath",
		"RampGap",
		"PinballAlley",
	]
	if level >= 3:
		chunk_pool.append("FunnelGauntlet")

	var chunk_index := 0
	var last_type := ""
	while absf(cursor_z) < target_len:
		var chosen_type := "StraightWide"
		if chunk_index == 0:
			chosen_type = "StraightWide"
		else:
			for _attempt in range(5):
				var candidate := chunk_pool[rng.randi_range(0, chunk_pool.size() - 1)]
				if candidate != last_type:
					chosen_type = candidate
					break
		last_type = chosen_type

		var chunk := TrackChunkBase.new()
		_track_root.add_child(chunk)
		chunk.build_chunk(chosen_type, cursor_z)
		active_chunks.append(chunk)

		_populate_chunk_entities(chunk, level, rng, chunk_index == 0)
		cursor_z = chunk.exit_z
		chunk_index += 1

	finish_z = cursor_z
	total_length = absf(finish_z)

	# 3. Build Finish Archway & post-finish catch runway
	_build_finish_archway(finish_z)

	return {
		"total_length": total_length,
		"finish_z": finish_z,
		"chunks": active_chunks,
		"entities": active_entities,
	}


func _build_start_platform() -> void:
	var start_chunk := TrackChunkBase.new()
	_track_root.add_child(start_chunk)
	start_chunk._add_floor_slab(
		Vector3(0.0, -0.3, -3.0),
		Vector3(10.0, 0.6, 14.0),
		Color(0.12, 0.18, 0.28)
	)
	var rail_col := Color(0.20, 0.85, 1.0)
	start_chunk._add_guard_rail(Vector3(-5.2, 0.55, -3.0), Vector3(0.4, 1.1, 14.0), rail_col)
	start_chunk._add_guard_rail(Vector3(5.2, 0.55, -3.0), Vector3(0.4, 1.1, 14.0), rail_col)
	start_chunk._add_guard_rail(Vector3(0.0, 0.55, 3.8), Vector3(10.4, 1.1, 0.5), rail_col)
	# Give player an immediate welcoming BoostPad right near the start!
	_spawn_entity(TrackEntityFactory.create_boost_pad(Vector3(0.0, 0.06, -7.5)))


func _build_finish_archway(z_pos: float) -> void:
	var finish_node := TrackChunkBase.new()
	_track_root.add_child(finish_node)
	finish_node._add_floor_slab(
		Vector3(0.0, -0.3, z_pos - FINISH_RUNWAY_LEN * 0.5),
		Vector3(12.0, 0.6, FINISH_RUNWAY_LEN),
		Color(0.15, 0.32, 0.22)
	)

	var arch_mat := StandardMaterial3D.new()
	arch_mat.albedo_color = Color(0.25, 1.0, 0.58)
	arch_mat.emission_enabled = true
	arch_mat.emission = Color(0.18, 0.95, 0.50)
	arch_mat.emission_energy_multiplier = 2.2

	for side_x in [-5.4, 5.4]:
		var pillar := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.65, 6.5, 0.65)
		pm.material = arch_mat
		RenderHelper.attach_mesh(pillar, pm)
		pillar.position = Vector3(side_x, 3.25, z_pos)
		_track_root.add_child(pillar)

	var crossbar := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(11.5, 0.75, 0.75)
	cm.material = arch_mat
	RenderHelper.attach_mesh(crossbar, cm)
	crossbar.position = Vector3(0.0, 6.4, z_pos)
	_track_root.add_child(crossbar)

	var goal_area := Area3D.new()
	goal_area.position = Vector3(0.0, 5.0, z_pos)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(22.0, 16.0, 3.0)
	col.shape = box
	goal_area.add_child(col)
	goal_area.body_entered.connect(_on_goal_body_entered)
	_track_root.add_child(goal_area)


func _on_goal_body_entered(body: Node) -> void:
	if body is PlayerBall3D:
		finish_crossed.emit()


func _spawn_entity(ent: Node3D) -> void:
	_track_root.add_child(ent)
	active_entities.append(ent)
	if ent is ExplosiveBarrel:
		(ent as ExplosiveBarrel).barrel_exploded.connect(_on_barrel_exploded)


func _on_barrel_exploded(origin: Vector3, radius: float, force: float, chain_depth: int) -> void:
	barrel_detonated.emit(origin, radius, force, chain_depth)


func _populate_chunk_entities(
	chunk: TrackChunkBase,
	level: int,
	rng: RandomNumberGenerator,
	is_first_chunk: bool
) -> void:
	var z0 := chunk.entry_z
	var density_extra := mini(4, (level - 1) / 2)

	match chunk.chunk_type:
		"StraightWide":
			_spawn_entity(TrackEntityFactory.create_boost_pad(Vector3(rng.randf_range(-2.6, 2.6), 0.06, z0 - 8.0)))
			var crate_count := 2 + density_extra
			for i in range(crate_count):
				var cx := rng.randf_range(-3.8, 3.8)
				var cz := z0 - 12.0 - float(i) * 2.8
				_spawn_entity(TrackEntityFactory.create_crate(Vector3(cx, 0.6, cz)))
			if not is_first_chunk and rng.randf() < 0.75:
				_spawn_entity(TrackEntityFactory.create_bouncer_slime(Vector3(0.0, 0.65, z0 - 20.0), 3.2))
			if rng.randf() < 0.60:
				_spawn_entity(TrackEntityFactory.create_explosive_barrel(Vector3(rng.randf_range(-2.2, 2.2), 0.65, z0 - 16.5)))

		"NarrowBridge":
			_spawn_entity(TrackEntityFactory.create_boost_pad(Vector3(0.0, 0.06, z0 - 7.5)))
			_spawn_entity(TrackEntityFactory.create_boost_pad(Vector3(0.0, 0.06, z0 - 16.5)))
			if level >= 2:
				_spawn_entity(TrackEntityFactory.create_crate(Vector3(rng.randf_range(-0.9, 0.9), 0.6, z0 - 12.0)))

		"SplitPath":
			# Left lane (-3.1): High risk, monsters + barrel + double BoostPads!
			_spawn_entity(TrackEntityFactory.create_boost_pad(Vector3(-3.1, 0.06, z0 - 7.0)))
			_spawn_entity(TrackEntityFactory.create_explosive_barrel(Vector3(-3.1, 0.65, z0 - 14.0)))
			_spawn_entity(TrackEntityFactory.create_crate(Vector3(-2.4, 0.6, z0 - 15.5)))
			_spawn_entity(TrackEntityFactory.create_crate(Vector3(-3.8, 0.6, z0 - 15.5)))
			if level >= 2:
				_spawn_entity(TrackEntityFactory.create_shield_brute(Vector3(-3.1, 0.75, z0 - 21.0)))
			_spawn_entity(TrackEntityFactory.create_boost_pad(Vector3(-3.1, 0.06, z0 - 26.5)))

			# Right lane (+3.1): Safer from monsters, but SlimeZone slows non-maglev builds
			_spawn_entity(TrackEntityFactory.create_slime_zone(Vector3(3.1, 0.05, z0 - 16.0), Vector2(3.6, 11.0)))

		"RampGap":
			# BoostPad right before the ramp to reward lining up the center jump!
			_spawn_entity(TrackEntityFactory.create_boost_pad(Vector3(0.0, 0.06, z0 - 5.2)))
			# Crates & monsters on landing deck so landing shockwave (Quake Refractor) blasts them all!
			_spawn_entity(TrackEntityFactory.create_crate(Vector3(-1.4, 0.6, z0 - 22.5)))
			_spawn_entity(TrackEntityFactory.create_crate(Vector3(1.4, 0.6, z0 - 22.5)))
			_spawn_entity(TrackEntityFactory.create_bouncer_slime(Vector3(0.0, 0.65, z0 - 25.0), 2.8))

		"PinballAlley":
			_spawn_entity(TrackEntityFactory.create_pinball_bumper(Vector3(-2.2, 0.65, z0 - 7.0)))
			_spawn_entity(TrackEntityFactory.create_pinball_bumper(Vector3(2.2, 0.65, z0 - 13.0)))
			_spawn_entity(TrackEntityFactory.create_pinball_bumper(Vector3(0.0, 0.65, z0 - 19.0)))
			_spawn_entity(TrackEntityFactory.create_bouncer_slime(Vector3(0.0, 0.65, z0 - 10.0), 3.0))
			if level >= 3:
				_spawn_entity(TrackEntityFactory.create_explosive_barrel(Vector3(rng.randf_range(-2.5, 2.5), 0.65, z0 - 22.5)))

		"FunnelGauntlet":
			_spawn_entity(TrackEntityFactory.create_boost_pad(Vector3(0.0, 0.06, z0 - 5.0)))
			_spawn_entity(TrackEntityFactory.create_explosive_barrel(Vector3(0.0, 0.65, z0 - 13.5)))
			_spawn_entity(TrackEntityFactory.create_shield_brute(Vector3(-1.6, 0.75, z0 - 15.5)))
			_spawn_entity(TrackEntityFactory.create_shield_brute(Vector3(1.6, 0.75, z0 - 15.5)))
			for i in range(3 + density_extra):
				_spawn_entity(
					TrackEntityFactory.create_crate(
						Vector3(rng.randf_range(-2.8, 2.8), 0.6, z0 - 19.0 - float(i) * 2.0)
					)
				)
			_spawn_entity(TrackEntityFactory.create_bouncer_slime(Vector3(0.0, 0.65, z0 - 26.0), 3.2))
