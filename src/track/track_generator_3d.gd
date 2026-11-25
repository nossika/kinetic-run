class_name TrackGenerator3D
extends Node3D

signal finish_crossed
signal barrel_detonated(origin: Vector3, radius: float, force: float, chain_depth: int)
signal bonus_ring_collected(seconds: float)

const TRACK_SLOPE_PITCH_DEG: float = -11.0
const START_APRON_LEN: float = 10.0
const FINISH_RUNWAY_LEN: float = 10.0

var active_chunks: Array[TrackChunkBase] = []
var active_entities: Array[Node3D] = []
var finish_z: float = -130.0
var total_length: float = 130.0

var _track_root: Node3D = null


func get_track_root() -> Node3D:
	return _track_root


func track_local_to_world(local_pos: Vector3) -> Vector3:
	if _track_root != null and is_instance_valid(_track_root):
		if _track_root.is_inside_tree():
			return _track_root.to_global(local_pos)
		return (transform * _track_root.transform) * local_pos
	var fallback_xform := transform * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(TRACK_SLOPE_PITCH_DEG)), Vector3.ZERO)
	return fallback_xform * local_pos


func world_to_track_local(world_pos: Vector3) -> Vector3:
	if _track_root != null and is_instance_valid(_track_root):
		if _track_root.is_inside_tree():
			return _track_root.to_local(world_pos)
		return (transform * _track_root.transform).affine_inverse() * world_pos
	var fallback_xform := transform * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(TRACK_SLOPE_PITCH_DEG)), Vector3.ZERO)
	return fallback_xform.affine_inverse() * world_pos


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
	_track_root.rotation_degrees = Vector3(TRACK_SLOPE_PITCH_DEG, 0.0, 0.0)
	add_child(_track_root)

	if get_parent() != null:
		var sibling_ball := get_parent().get_node_or_null("PlayerBall3D")
		if sibling_ball != null and "track_reference" in sibling_ball:
			sibling_ball.track_reference = _track_root

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	var target_len := RunState.target_length_for_level(level)
	var min_build_len := target_len + (12.0 if level >= 2 else 0.0)

	# 1. Build starting safe platform [Z = +4 .. -START_APRON_LEN]
	_build_start_platform()
	var cursor_z := -START_APRON_LEN

	# 2. Concatenate modular chunks until cursor_z reaches -min_build_len
	var chunk_pool: Array[String] = [
		"StraightWide",
		"WaveHills",
		"NarrowBridge",
		"SplitPath",
		"RampGap",
		"PinballAlley",
	]
	if level >= 3:
		chunk_pool.append("FunnelGauntlet")
	var compact_pool: Array[String] = ["StraightWide", "NarrowBridge", "PinballAlley"]

	var chunk_index := 0
	var last_type := ""
	while absf(cursor_z) < min_build_len:
		var chosen_type := "StraightWide"
		if chunk_index == 0:
			chosen_type = "StraightWide"
		else:
			var remaining := min_build_len - absf(cursor_z)
			var active_pool := compact_pool if remaining <= 14.0 else chunk_pool
			for _attempt in range(5):
				var candidate := active_pool[rng.randi_range(0, active_pool.size() - 1)]
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
		Color(1.0, 0.98, 0.95)
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
		Color(0.94, 1.0, 0.94)
	)

	var arch_mat := MaterialLibrary.make_frosted_acrylic_material(Color(0.24, 0.96, 0.60, 0.86))

	for side_x in [-5.4, 5.4]:
		var pillar_root := Node3D.new()
		pillar_root.position = Vector3(side_x, 0.0, z_pos)
		_track_root.add_child(pillar_root)
		MaterialLibrary.attach_anchored_flange_base(pillar_root, 0.0, 0.58, 0.58, false)

		var pillar := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.65, 6.5, 0.65)
		pm.material = arch_mat
		RenderHelper.attach_mesh(pillar, pm)
		pillar.position = Vector3(0.0, 3.25, 0.0)
		pillar_root.add_child(pillar)

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
	elif ent is AerialBonusRing:
		(ent as AerialBonusRing).ring_collected.connect(_on_bonus_ring_collected)


func _on_barrel_exploded(origin: Vector3, radius: float, force: float, chain_depth: int) -> void:
	barrel_detonated.emit(origin, radius, force, chain_depth)


func _on_bonus_ring_collected(seconds: float) -> void:
	bonus_ring_collected.emit(seconds)


func _roll_crate_tier(level: int, rng: RandomNumberGenerator) -> String:
	return "medium" if (level >= 2 and rng.randf() < 0.40) else "light"


func _roll_blocker_type(level: int, rng: RandomNumberGenerator) -> String:
	return "mag_iron" if (level >= 3 and rng.randf() < 0.45) else "soft_balloon"


func _populate_chunk_entities(
	chunk: TrackChunkBase,
	level: int,
	rng: RandomNumberGenerator,
	is_first_chunk: bool
) -> void:
	var z0 := chunk.entry_z
	@warning_ignore("integer_division")
	var density_extra := mini(4, (level - 1) / 2)

	match chunk.chunk_type:
		"StraightWide":
			_spawn_entity(TrackEntityFactory.create_boost_pad(Vector3(rng.randf_range(-2.2, 2.2), 0.06, z0 - 6.5)))
			var side_sign := -1.0 if rng.randf() < 0.5 else 1.0
			var crate_count := 2 + density_extra

			if is_first_chunk:
				# Optional side SpringPad arc on opening chunk while keeping center lane welcoming
				var spring_x := side_sign * 3.1
				_spawn_entity(TrackEntityFactory.create_spring_pad(Vector3(spring_x, 0.0, z0 - 10.5)))
				_spawn_entity(TrackEntityFactory.create_aerial_bonus_ring(Vector3(spring_x, 2.7, z0 - 16.5)))
				_spawn_entity(
					TrackEntityFactory.create_aerial_blocker(
						Vector3(spring_x - side_sign * 0.8, 2.6, z0 - 19.5),
						"soft_balloon",
						rng.randf_range(0.0, TAU)
					)
				)
				for i in range(crate_count):
					var cx := rng.randf_range(-1.9, 1.9)
					var cz := z0 - 12.5 - float(i) * 2.8
					_spawn_entity(TrackEntityFactory.create_crate(Vector3(cx, 0.64, cz), _roll_crate_tier(level, rng)))
			else:
				# Side launch ramp (+16° frosted cyan acrylic) leaping past ground 20kg ShieldBrute!
				var ramp_x := side_sign * 3.2
				chunk.add_side_launch_ramp(Vector3(ramp_x, 0.0, -10.5), 2.4)
				_spawn_entity(TrackEntityFactory.create_aerial_bonus_ring(Vector3(ramp_x, 2.5, z0 - 16.8)))
				if level >= 2:
					_spawn_entity(
						TrackEntityFactory.create_aerial_blocker(
							Vector3(ramp_x - side_sign * 0.75, 2.6, z0 - 19.8),
							_roll_blocker_type(level, rng),
							rng.randf_range(0.0, TAU)
						)
					)
				_spawn_entity(TrackEntityFactory.create_shield_brute(Vector3(-side_sign * 1.1, 0.73, z0 - 15.8)))

				if rng.randf() < 0.55:
					var opp_x := -side_sign * 3.0
					_spawn_entity(TrackEntityFactory.create_spring_pad(Vector3(opp_x, 0.0, z0 - 9.5)))
					_spawn_entity(TrackEntityFactory.create_aerial_bonus_ring(Vector3(opp_x, 2.75, z0 - 15.5)))
					_spawn_entity(
						TrackEntityFactory.create_aerial_blocker(
							Vector3(opp_x + side_sign * 0.7, 2.65, z0 - 18.2),
							_roll_blocker_type(level, rng),
							rng.randf_range(0.0, TAU)
						)
					)

				for i in range(crate_count):
					var lane_min := -1.8 if side_sign > 0.0 else -0.4
					var lane_max := 0.4 if side_sign > 0.0 else 1.8
					var cx := rng.randf_range(lane_min, lane_max)
					var cz := z0 - 11.8 - float(i) * 2.9
					if absf(cz - (z0 - 15.8)) < 1.7:
						cz -= 1.8
					_spawn_entity(TrackEntityFactory.create_crate(Vector3(cx, 0.64, cz), _roll_crate_tier(level, rng)))

				if rng.randf() < 0.65:
					_spawn_entity(TrackEntityFactory.create_bouncer_slime(Vector3(0.0, 0.65, z0 - 23.0), 2.8))
				if rng.randf() < 0.55:
					_spawn_entity(TrackEntityFactory.create_explosive_barrel(Vector3(-side_sign * 2.6, 0.65, z0 - 19.6)))

		"WaveHills":
			var ring_x_1 := rng.randf_range(-2.2, 2.2)
			var offset_dir_1 := 1.35 if rng.randf() < 0.5 else -1.35
			_spawn_entity(TrackEntityFactory.create_aerial_bonus_ring(Vector3(ring_x_1, 2.75, z0 - 9.6)))
			_spawn_entity(
				TrackEntityFactory.create_aerial_blocker(
					Vector3(clampf(ring_x_1 + offset_dir_1, -3.2, 3.2), 2.65, z0 - 11.6),
					_roll_blocker_type(level, rng),
					rng.randf_range(0.0, TAU)
				)
			)

			# Central trough targets (crates + explosive barrel) rewarded by landing shockwaves
			_spawn_entity(TrackEntityFactory.create_crate(Vector3(-2.2, 0.64, z0 - 15.0), _roll_crate_tier(level, rng)))
			_spawn_entity(TrackEntityFactory.create_crate(Vector3(2.2, 0.64, z0 - 15.0), _roll_crate_tier(level, rng)))
			if rng.randf() < 0.75:
				_spawn_entity(TrackEntityFactory.create_explosive_barrel(Vector3(0.0, 0.65, z0 - 15.0)))

			var ring_x_2 := rng.randf_range(-2.2, 2.2)
			_spawn_entity(TrackEntityFactory.create_aerial_bonus_ring(Vector3(ring_x_2, 2.85, z0 - 23.0)))
			_spawn_entity(
				TrackEntityFactory.create_aerial_blocker(
					Vector3(clampf(-ring_x_2 * 0.7, -3.0, 3.0), 2.65, z0 - 25.2),
					_roll_blocker_type(level, rng),
					rng.randf_range(0.0, TAU)
				)
			)

		"NarrowBridge":
			_spawn_entity(TrackEntityFactory.create_boost_pad(Vector3(0.0, 0.06, z0 - 7.5)))
			_spawn_entity(TrackEntityFactory.create_boost_pad(Vector3(0.0, 0.06, z0 - 16.5)))
			if level >= 2:
				_spawn_entity(
					TrackEntityFactory.create_crate(
						Vector3(rng.randf_range(-0.9, 0.9), 0.64, z0 - 12.0),
						_roll_crate_tier(level, rng)
					)
				)

		"SplitPath":
			# Left lane (-3.1): High risk, monsters + barrel + double BoostPads!
			_spawn_entity(TrackEntityFactory.create_boost_pad(Vector3(-3.1, 0.06, z0 - 6.5)))
			_spawn_entity(TrackEntityFactory.create_explosive_barrel(Vector3(-3.1, 0.65, z0 - 13.0)))
			_spawn_entity(TrackEntityFactory.create_crate(Vector3(-2.2, 0.64, z0 - 16.0), _roll_crate_tier(level, rng)))
			_spawn_entity(TrackEntityFactory.create_crate(Vector3(-4.0, 0.64, z0 - 16.0), _roll_crate_tier(level, rng)))
			if level >= 2:
				_spawn_entity(TrackEntityFactory.create_shield_brute(Vector3(-3.1, 0.73, z0 - 21.0)))
			_spawn_entity(TrackEntityFactory.create_boost_pad(Vector3(-3.1, 0.06, z0 - 26.5)))

			# Right lane (+3.1): SpringPad vault over SlimeZone with aerial bonus ring & blocker
			_spawn_entity(TrackEntityFactory.create_spring_pad(Vector3(3.1, 0.0, z0 - 9.0)))
			_spawn_entity(TrackEntityFactory.create_slime_zone(Vector3(3.1, 0.05, z0 - 17.5), Vector2(3.6, 10.0)))
			_spawn_entity(TrackEntityFactory.create_aerial_bonus_ring(Vector3(3.1, 2.75, z0 - 15.5)))
			_spawn_entity(
				TrackEntityFactory.create_aerial_blocker(
					Vector3(2.35, 2.65, z0 - 18.5),
					_roll_blocker_type(level, rng),
					rng.randf_range(0.0, TAU)
				)
			)

		"RampGap":
			# BoostPad right before the ramp + AerialBonusRing & offset AerialBlocker over chasm!
			_spawn_entity(TrackEntityFactory.create_boost_pad(Vector3(0.0, 0.06, z0 - 5.2)))
			_spawn_entity(TrackEntityFactory.create_aerial_bonus_ring(Vector3(0.0, 2.8, z0 - 16.5)))
			var chasm_blocker_x := 0.85 if rng.randf() < 0.5 else -0.85
			_spawn_entity(
				TrackEntityFactory.create_aerial_blocker(
					Vector3(chasm_blocker_x, 2.75, z0 - 18.4),
					_roll_blocker_type(level, rng),
					rng.randf_range(0.0, TAU)
				)
			)
			# Crates & monsters on landing deck so landing shockwave (Quake Refractor) blasts them all!
			_spawn_entity(TrackEntityFactory.create_crate(Vector3(-1.4, 0.64, z0 - 22.5), _roll_crate_tier(level, rng)))
			_spawn_entity(TrackEntityFactory.create_crate(Vector3(1.4, 0.64, z0 - 22.5), _roll_crate_tier(level, rng)))
			_spawn_entity(TrackEntityFactory.create_bouncer_slime(Vector3(0.0, 0.65, z0 - 25.0), 2.8))

		"PinballAlley":
			_spawn_entity(TrackEntityFactory.create_pinball_bumper(Vector3(-2.2, 0.65, z0 - 7.0)))
			_spawn_entity(TrackEntityFactory.create_pinball_bumper(Vector3(2.2, 0.65, z0 - 13.0)))
			_spawn_entity(TrackEntityFactory.create_pinball_bumper(Vector3(0.0, 0.65, z0 - 19.0)))
			_spawn_entity(TrackEntityFactory.create_bouncer_slime(Vector3(0.0, 0.65, z0 - 10.0), 3.0))
			_spawn_entity(
				TrackEntityFactory.create_crate(
					Vector3(rng.randf_range(-3.2, 3.2), 0.64, z0 - 16.0),
					_roll_crate_tier(level, rng)
				)
			)
			if level >= 3:
				_spawn_entity(TrackEntityFactory.create_explosive_barrel(Vector3(rng.randf_range(-2.5, 2.5), 0.65, z0 - 22.5)))

		"FunnelGauntlet":
			_spawn_entity(TrackEntityFactory.create_spring_pad(Vector3(0.0, 0.0, z0 - 5.2)))
			_spawn_entity(TrackEntityFactory.create_boost_pad(Vector3(-2.4, 0.06, z0 - 5.2)))
			_spawn_entity(TrackEntityFactory.create_boost_pad(Vector3(2.4, 0.06, z0 - 5.2)))
			_spawn_entity(TrackEntityFactory.create_aerial_bonus_ring(Vector3(0.0, 2.8, z0 - 11.8)))
			_spawn_entity(
				TrackEntityFactory.create_aerial_blocker(
					Vector3(rng.randf_range(-1.1, 1.1), 2.75, z0 - 14.6),
					_roll_blocker_type(level, rng),
					rng.randf_range(0.0, TAU)
				)
			)
			_spawn_entity(TrackEntityFactory.create_explosive_barrel(Vector3(0.0, 0.65, z0 - 13.0)))
			_spawn_entity(TrackEntityFactory.create_shield_brute(Vector3(-1.8, 0.73, z0 - 15.8)))
			_spawn_entity(TrackEntityFactory.create_shield_brute(Vector3(1.8, 0.73, z0 - 15.8)))
			for i in range(3 + density_extra):
				_spawn_entity(
					TrackEntityFactory.create_crate(
						Vector3(rng.randf_range(-2.8, 2.8), 0.64, z0 - 19.0 - float(i) * 2.0),
						_roll_crate_tier(level, rng)
					)
				)
			_spawn_entity(TrackEntityFactory.create_bouncer_slime(Vector3(0.0, 0.65, z0 - 27.0), 3.0))
