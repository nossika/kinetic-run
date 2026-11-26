class_name TrackGenerator3D
extends Node3D

signal finish_crossed
signal barrel_detonated(origin: Vector3, radius: float, force: float, chain_depth: int)
signal bonus_ring_collected(seconds: float)

const TRACK_SLOPE_PITCH_DEG: float = -11.0
const START_APRON_LEN: float = 10.0
const FINISH_RUNWAY_LEN: float = 10.0
const MIN_RB_CLEARANCE_XZ: float = 1.90
const MIN_PIN_CLEARANCE_XZ: float = 0.92
const MIN_RB_LAYER_DIFF_Y: float = 1.50
const CHUNK_Z_MARGIN: float = 1.45

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
	var base_xform := global_transform if is_inside_tree() else transform
	var fallback_xform := base_xform * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(TRACK_SLOPE_PITCH_DEG)), Vector3.ZERO)
	return fallback_xform * local_pos


func world_to_track_local(world_pos: Vector3) -> Vector3:
	if _track_root != null and is_instance_valid(_track_root):
		if _track_root.is_inside_tree():
			return _track_root.to_local(world_pos)
		return (transform * _track_root.transform).affine_inverse() * world_pos
	var base_xform := global_transform if is_inside_tree() else transform
	var fallback_xform := base_xform * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(TRACK_SLOPE_PITCH_DEG)), Vector3.ZERO)
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
		Vector3(TrackChunkBase.STANDARD_WIDTH, 0.6, 14.0),
		Color(1.0, 0.98, 0.95)
	)
	var rail_col := Color(0.58, 0.84, 0.75)
	start_chunk._add_guard_rail(Vector3(-6.45, 0.52, -3.0), Vector3(0.46, 1.04, 14.0), rail_col)
	start_chunk._add_guard_rail(Vector3(6.45, 0.52, -3.0), Vector3(0.46, 1.04, 14.0), rail_col)
	start_chunk._add_guard_rail(Vector3(0.0, 0.52, 3.8), Vector3(12.9, 1.04, 0.52), rail_col)
	_spawn_entity(TrackEntityFactory.create_boost_pad(Vector3(0.0, 0.06, -7.5)))


func _build_finish_archway(z_pos: float) -> void:
	var finish_node := TrackChunkBase.new()
	_track_root.add_child(finish_node)
	finish_node._add_floor_slab(
		Vector3(0.0, -0.3, z_pos - FINISH_RUNWAY_LEN * 0.5),
		Vector3(15.0, 0.6, FINISH_RUNWAY_LEN),
		Color(0.96, 1.0, 0.95)
	)

	var pillar_mat := MaterialLibrary.make_silicone_soft_material(Color(0.98, 0.95, 0.88))
	var bar_mat := MaterialLibrary.make_silicone_soft_material(Color(0.54, 0.86, 0.72))
	var pillar_mesh := ClayMeshBuilder.make_chamfered_cylinder(0.36, 0.42, 7.4, 0.12, 22)

	for side_x in [-6.75, 6.75]:
		var pillar_root := Node3D.new()
		pillar_root.position = Vector3(side_x, 0.0, z_pos)
		_track_root.add_child(pillar_root)
		MaterialLibrary.attach_anchored_flange_base(pillar_root, 0.0, 0.56, 0.56, false)

		var pillar := MeshInstance3D.new()
		ClayMeshBuilder.assign_mesh(pillar, pillar_mesh, pillar_mat)
		pillar.position = Vector3(0.0, 3.7, 0.0)
		pillar_root.add_child(pillar)

	var crossbar := MeshInstance3D.new()
	var cm := ClayMeshBuilder.make_rounded_box(Vector3(14.6, 0.86, 0.86), 0.30, 3)
	ClayMeshBuilder.assign_mesh(crossbar, cm, bar_mat)
	crossbar.position = Vector3(0.0, 7.4, z_pos)
	_track_root.add_child(crossbar)

	var goal_area := Area3D.new()
	goal_area.position = Vector3(0.0, 7.5, z_pos)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(28.0, 22.0, 3.5)
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


func _spawn_tiered_crate(x: float, z: float, level: int, rng: RandomNumberGenerator, chunk: TrackChunkBase) -> void:
	var tier := _roll_crate_tier(level, rng)
	var cy := 0.50
	var yaw_deg := 0.0
	if tier == "medium":
		cy = 0.62
		yaw_deg = (1.0 if rng.randf() < 0.5 else -1.0) * rng.randf_range(18.0, 40.0)
	else:
		cy = 0.50
		yaw_deg = rng.randf_range(-24.0, 24.0)
	_spawn_chunk_entity(TrackEntityFactory.create_crate(Vector3(x, cy, z), tier, yaw_deg), chunk)


func _spawn_pin_cluster(center_x: float, center_z: float, count: int, chunk: TrackChunkBase) -> void:
	var offsets: Array[Vector2] = []
	if count <= 1:
		offsets = [Vector2.ZERO]
	elif count == 2:
		offsets = [Vector2(-0.52, 0.0), Vector2(0.52, 0.0)]
	else:
		offsets = [Vector2(0.0, 0.45), Vector2(-0.54, -0.48), Vector2(0.54, -0.48)]
	for off in offsets:
		_spawn_chunk_entity(
			TrackEntityFactory.create_wooden_pin(Vector3(center_x + off.x, 0.79, center_z + off.y)),
			chunk
		)


func _roll_blocker_type(level: int, rng: RandomNumberGenerator) -> String:
	return "mag_iron" if (level >= 3 and rng.randf() < 0.45) else "soft_balloon"


func _spawn_chunk_entity(ent: Node3D, chunk: TrackChunkBase) -> void:
	var z_min := chunk.exit_z + CHUNK_Z_MARGIN
	var z_max := chunk.entry_z - CHUNK_Z_MARGIN
	ent.position.z = clampf(ent.position.z, z_min, z_max)

	if ent is RigidBody3D:
		ent.position = _resolve_rigidbody_clearance(ent.position, z_min, z_max, ent is WoodenPin)

	_spawn_entity(ent)


func _resolve_rigidbody_clearance(desired: Vector3, z_min: float, z_max: float, is_pin: bool = false) -> Vector3:
	var candidate := Vector3(desired.x, desired.y, clampf(desired.z, z_min, z_max))
	if _is_rigidbody_pos_clear(candidate, is_pin):
		return candidate

	# Deterministic spiral search within safe lane/chunk bounds if any candidate ever approaches another RigidBody3D
	var is_high_air := desired.y >= 4.2
	var min_x := -4.8
	var max_x := 4.8
	var eff_z_min := z_min
	var eff_z_max := z_max
	var x_offsets: Array[float] = [0.0, -1.2, 1.2, -2.4, 2.4, -3.6, 3.6]
	var z_offsets: Array[float] = [0.0, -1.95, 1.95, -3.9, 3.9]
	if is_high_air:
		min_x = desired.x - 1.1
		max_x = desired.x + 1.1
		eff_z_min = maxf(z_min, desired.z - 2.0)
		eff_z_max = minf(z_max, desired.z + 2.0)
		if eff_z_min > eff_z_max:
			eff_z_min = candidate.z
			eff_z_max = candidate.z
		x_offsets = [0.0, -0.55, 0.55, -1.05, 1.05]
		z_offsets = [0.0, -1.5, 1.5, -2.8, 2.8]
	for dz in z_offsets:
		var test_z := clampf(candidate.z + dz, eff_z_min, eff_z_max)
		for dx in x_offsets:
			var test_x := clampf(candidate.x + dx, min_x, max_x)
			var probe := Vector3(test_x, candidate.y, test_z)
			if _is_rigidbody_pos_clear(probe, is_pin):
				return probe
	return candidate


func _is_rigidbody_pos_clear(pos: Vector3, is_pin: bool = false) -> bool:
	var p2 := Vector2(pos.x, pos.z)
	for other in active_entities:
		if other is RigidBody3D and is_instance_valid(other):
			if absf(pos.y - other.position.y) >= MIN_RB_LAYER_DIFF_Y:
				continue
			var req_clearance := MIN_PIN_CLEARANCE_XZ if (is_pin and other is WoodenPin) else MIN_RB_CLEARANCE_XZ
			var o2 := Vector2(other.position.x, other.position.z)
			if p2.distance_to(o2) < req_clearance:
				return false
	return true


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
			_spawn_chunk_entity(TrackEntityFactory.create_boost_pad(Vector3(rng.randf_range(-2.75, 2.75), 0.06, z0 - 6.2)), chunk)
			var side_sign := -1.0 if rng.randf() < 0.5 else 1.0
			var crate_count := 2 + density_extra

			if is_first_chunk:
				# Optional side SpringPad arc on opening chunk while keeping center lane welcoming
				var spring_x := side_sign * 3.85
				_spawn_chunk_entity(TrackEntityFactory.create_spring_pad(Vector3(spring_x, 0.0, z0 - 10.5)), chunk)
				_spawn_chunk_entity(TrackEntityFactory.create_aerial_bonus_ring(Vector3(spring_x, 2.7, z0 - 16.5)), chunk)
				_spawn_chunk_entity(
					TrackEntityFactory.create_aerial_blocker(
						Vector3(spring_x - side_sign * 1.0, 2.6, z0 - 19.5),
						"soft_balloon",
						rng.randf_range(0.0, TAU)
					),
					chunk
				)
				_spawn_pin_cluster(-side_sign * 2.95, z0 - 8.2, 3, chunk)
				var z_step := minf(2.7, 12.0 / float(maxi(1, crate_count - 1)))
				for i in range(crate_count):
					var lane_sign := -1.0 if (i % 2 == 0) else 1.0
					var cx := lane_sign * rng.randf_range(1.2, 2.55)
					var cz := z0 - 12.0 - float(i) * z_step
					_spawn_tiered_crate(cx, cz, level, rng, chunk)
			else:
				# Side launch ramp (+16° frosted cyan acrylic) leaping past ground 20kg ShieldBrute!
				var ramp_x := side_sign * 4.0
				chunk.add_side_launch_ramp(Vector3(ramp_x, 0.0, -10.5), 3.0)
				_spawn_chunk_entity(TrackEntityFactory.create_aerial_bonus_ring(Vector3(ramp_x, 2.5, z0 - 16.8)), chunk)
				if level >= 2:
					_spawn_chunk_entity(
						TrackEntityFactory.create_aerial_blocker(
							Vector3(ramp_x - side_sign * 0.95, 2.6, z0 - 19.8),
							_roll_blocker_type(level, rng),
							rng.randf_range(0.0, TAU)
						),
						chunk
					)
				_spawn_pin_cluster(-side_sign * 2.05, z0 - 5.2, 3, chunk)
				_spawn_chunk_entity(TrackEntityFactory.create_shield_brute(Vector3(-side_sign * 1.45, 0.73, z0 - 15.6)), chunk)

				if rng.randf() < 0.55:
					var opp_x := -side_sign * 3.75
					_spawn_chunk_entity(TrackEntityFactory.create_spring_pad(Vector3(opp_x, 0.0, z0 - 9.5)), chunk)
					_spawn_chunk_entity(TrackEntityFactory.create_aerial_bonus_ring(Vector3(opp_x, 2.75, z0 - 15.5)), chunk)
					_spawn_chunk_entity(
						TrackEntityFactory.create_aerial_blocker(
							Vector3(opp_x + side_sign * 0.88, 2.65, z0 - 18.2),
							_roll_blocker_type(level, rng),
							rng.randf_range(0.0, TAU)
						),
						chunk
					)

				if rng.randf() < 0.55:
					_spawn_chunk_entity(TrackEntityFactory.create_explosive_barrel(Vector3(-side_sign * 3.65, 0.65, z0 - 20.4)), chunk)

				var crate_slots: Array[Vector2] = [
					Vector2(-side_sign * 1.15 * 1.25, -11.4),
					Vector2(side_sign * 0.95 * 1.25, -14.2),
					Vector2(side_sign * 1.35 * 1.25, -18.0),
					Vector2(-side_sign * 0.65 * 1.25, -20.6),
					Vector2(side_sign * 2.25 * 1.25, -22.2),
					Vector2(-side_sign * 1.35 * 1.25, -24.2),
				]
				for i in range(mini(crate_count, crate_slots.size())):
					var slot := crate_slots[i]
					var cx := slot.x + rng.randf_range(-0.18, 0.18)
					var cz := z0 + slot.y
					_spawn_tiered_crate(cx, cz, level, rng, chunk)

				if rng.randf() < 0.65:
					_spawn_chunk_entity(TrackEntityFactory.create_bouncer_slime(Vector3(0.0, 0.65, z0 - 23.2), 3.5), chunk)

		"WaveHills":
			var ring_x_1 := rng.randf_range(-2.75, 2.75)
			var offset_dir_1 := 1.68 if rng.randf() < 0.5 else -1.68
			_spawn_chunk_entity(TrackEntityFactory.create_aerial_bonus_ring(Vector3(ring_x_1, 2.75, z0 - 9.6)), chunk)
			_spawn_chunk_entity(
				TrackEntityFactory.create_aerial_blocker(
					Vector3(clampf(ring_x_1 + offset_dir_1, -4.0, 4.0), 2.65, z0 - 11.6),
					_roll_blocker_type(level, rng),
					rng.randf_range(0.0, TAU)
				),
				chunk
			)

			# Central trough targets (crates + explosive barrel) rewarded by landing shockwaves
			_spawn_tiered_crate(-2.75, z0 - 15.0, level, rng, chunk)
			_spawn_tiered_crate(2.75, z0 - 15.0, level, rng, chunk)
			if rng.randf() < 0.75:
				_spawn_chunk_entity(TrackEntityFactory.create_explosive_barrel(Vector3(0.0, 0.65, z0 - 15.0)), chunk)

			var ring_x_2 := rng.randf_range(-2.75, 2.75)
			_spawn_chunk_entity(TrackEntityFactory.create_aerial_bonus_ring(Vector3(ring_x_2, 2.85, z0 - 23.0)), chunk)
			_spawn_chunk_entity(
				TrackEntityFactory.create_aerial_blocker(
					Vector3(clampf(-ring_x_2 * 0.7, -4.0, 4.0), 2.65, z0 - 25.2),
					_roll_blocker_type(level, rng),
					rng.randf_range(0.0, TAU)
				),
				chunk
			)
			# Flat exit apron [-27 .. -30] bowling cluster rewarded after Wave Hill 2 crest
			_spawn_pin_cluster(rng.randf_range(-1.75, 1.75), z0 - 28.02, 3 if level >= 2 else 2, chunk)

		"NarrowBridge":
			_spawn_chunk_entity(TrackEntityFactory.create_boost_pad(Vector3(0.0, 0.06, z0 - 7.5)), chunk)
			_spawn_chunk_entity(TrackEntityFactory.create_boost_pad(Vector3(0.0, 0.06, z0 - 16.5)), chunk)
			if level >= 2:
				var nb_x := rng.randf_range(-1.05, 1.05)
				if rng.randf() < 0.55:
					_spawn_chunk_entity(TrackEntityFactory.create_wooden_pin(Vector3(nb_x, 0.79, z0 - 12.0)), chunk)
				else:
					var light_yaw := rng.randf_range(-24.0, 24.0)
					_spawn_chunk_entity(
						TrackEntityFactory.create_crate(Vector3(nb_x, 0.50, z0 - 12.0), "light", light_yaw),
						chunk
					)

		"SplitPath":
			# Left lane (-3.85): High risk, pin gate + barrel + monsters + double BoostPads!
			_spawn_chunk_entity(TrackEntityFactory.create_boost_pad(Vector3(-3.85, 0.06, z0 - 6.5)), chunk)
			_spawn_pin_cluster(-3.85, z0 - 9.2, 2, chunk)
			_spawn_chunk_entity(TrackEntityFactory.create_explosive_barrel(Vector3(-3.85, 0.65, z0 - 12.8)), chunk)
			_spawn_tiered_crate(-2.70, z0 - 15.6, level, rng, chunk)
			_spawn_tiered_crate(-5.00, z0 - 16.6, level, rng, chunk)
			if level >= 2:
				_spawn_chunk_entity(TrackEntityFactory.create_shield_brute(Vector3(-3.85, 0.73, z0 - 21.0)), chunk)
			_spawn_chunk_entity(TrackEntityFactory.create_boost_pad(Vector3(-3.85, 0.06, z0 - 26.5)), chunk)

			# Right lane (+3.85): SpringPad vault over SlimeZone with aerial bonus ring, blocker & landing pins
			_spawn_chunk_entity(TrackEntityFactory.create_spring_pad(Vector3(3.85, 0.0, z0 - 9.0)), chunk)
			_spawn_chunk_entity(TrackEntityFactory.create_slime_zone(Vector3(3.85, 0.05, z0 - 17.5), Vector2(4.5, 10.0)), chunk)
			_spawn_chunk_entity(TrackEntityFactory.create_aerial_bonus_ring(Vector3(3.85, 2.75, z0 - 15.5)), chunk)
			_spawn_chunk_entity(
				TrackEntityFactory.create_aerial_blocker(
					Vector3(2.95, 2.65, z0 - 18.5),
					_roll_blocker_type(level, rng),
					rng.randf_range(0.0, TAU)
				),
				chunk
			)
			_spawn_pin_cluster(3.85, z0 - 26.2, 3, chunk)

		"RampGap":
			# BoostPad right before the ramp + AerialBonusRing & offset AerialBlocker over chasm!
			_spawn_chunk_entity(TrackEntityFactory.create_boost_pad(Vector3(0.0, 0.06, z0 - 5.2)), chunk)
			_spawn_chunk_entity(TrackEntityFactory.create_aerial_bonus_ring(Vector3(0.0, 2.8, z0 - 16.5)), chunk)
			var chasm_blocker_x := 1.05 if rng.randf() < 0.5 else -1.05
			_spawn_chunk_entity(
				TrackEntityFactory.create_aerial_blocker(
					Vector3(chasm_blocker_x, 2.75, z0 - 18.4),
					_roll_blocker_type(level, rng),
					rng.randf_range(0.0, TAU)
				),
				chunk
			)
			# Crates & monsters on landing deck so landing shockwave (Quake Refractor) blasts them all!
			_spawn_tiered_crate(-1.75, z0 - 22.5, level, rng, chunk)
			_spawn_tiered_crate(1.75, z0 - 22.5, level, rng, chunk)
			_spawn_chunk_entity(TrackEntityFactory.create_bouncer_slime(Vector3(0.0, 0.65, z0 - 25.0), 3.5), chunk)

		"PinballAlley":
			_spawn_chunk_entity(TrackEntityFactory.create_pinball_bumper(Vector3(-2.75, 0.65, z0 - 7.0)), chunk)
			_spawn_chunk_entity(TrackEntityFactory.create_pinball_bumper(Vector3(2.75, 0.65, z0 - 13.0)), chunk)
			_spawn_chunk_entity(TrackEntityFactory.create_pinball_bumper(Vector3(0.0, 0.65, z0 - 19.0)), chunk)
			_spawn_chunk_entity(TrackEntityFactory.create_bouncer_slime(Vector3(0.0, 0.65, z0 - 10.0), 3.75), chunk)
			_spawn_tiered_crate(rng.randf_range(-4.0, 4.0), z0 - 16.0, level, rng, chunk)
			if level >= 3:
				_spawn_chunk_entity(TrackEntityFactory.create_explosive_barrel(Vector3(rng.randf_range(-3.1, 3.1), 0.65, z0 - 22.5)), chunk)

		"FunnelGauntlet":
			_spawn_chunk_entity(TrackEntityFactory.create_spring_pad(Vector3(0.0, 0.0, z0 - 5.2)), chunk)
			_spawn_chunk_entity(TrackEntityFactory.create_boost_pad(Vector3(-3.0, 0.06, z0 - 5.2)), chunk)
			_spawn_chunk_entity(TrackEntityFactory.create_boost_pad(Vector3(3.0, 0.06, z0 - 5.2)), chunk)
			_spawn_pin_cluster(0.0, z0 - 9.0, 3, chunk)
			_spawn_chunk_entity(TrackEntityFactory.create_aerial_bonus_ring(Vector3(0.0, 2.8, z0 - 11.8)), chunk)
			_spawn_chunk_entity(
				TrackEntityFactory.create_aerial_blocker(
					Vector3(rng.randf_range(-1.35, 1.35), 2.75, z0 - 14.6),
					_roll_blocker_type(level, rng),
					rng.randf_range(0.0, TAU)
				),
				chunk
			)
			_spawn_chunk_entity(TrackEntityFactory.create_explosive_barrel(Vector3(0.0, 0.65, z0 - 12.8)), chunk)
			_spawn_chunk_entity(TrackEntityFactory.create_shield_brute(Vector3(-2.30, 0.73, z0 - 15.6)), chunk)
			_spawn_chunk_entity(TrackEntityFactory.create_shield_brute(Vector3(2.30, 0.73, z0 - 15.6)), chunk)
			var funnel_crates := 3 + density_extra
			var funnel_z_step := minf(2.1, 9.9 / float(maxi(1, funnel_crates - 1)))
			for i in range(funnel_crates):
				var lane_sign := -1.0 if (i % 2 == 0) else 1.0
				var cx := lane_sign * rng.randf_range(1.45, 3.15)
				var cz := z0 - 18.2 - float(i) * funnel_z_step
				_spawn_tiered_crate(cx, cz, level, rng, chunk)
			_spawn_chunk_entity(TrackEntityFactory.create_bouncer_slime(Vector3(0.0, 0.65, z0 - 27.2), 3.75), chunk)

	var high_air_info := _populate_high_air_layer(chunk, level, rng, is_first_chunk)
	_populate_chunk_wind_zones(
		chunk,
		level,
		rng,
		is_first_chunk,
		bool(high_air_info.get("has_approach_updraft", false)),
		bool(high_air_info.get("has_sky_platform", false))
	)


func _populate_high_air_layer(
	chunk: TrackChunkBase,
	level: int,
	rng: RandomNumberGenerator,
	is_first_chunk: bool
) -> Dictionary:
	if is_first_chunk or chunk.chunk_type == "NarrowBridge":
		return {"has_approach_updraft": false, "has_sky_platform": false}

	var sky_prob := clampf(0.34 + 0.04 * float(level - 1), 0.34, 0.48)
	if rng.randf() >= sky_prob:
		return {"has_approach_updraft": false, "has_sky_platform": false}

	var z0 := chunk.entry_z

	if chunk.chunk_type == "WaveHills" or chunk.chunk_type == "RampGap":
		var sky_x := rng.randf_range(-2.4, 2.4)
		var sky_y := rng.randf_range(4.8, 5.7)
		if rng.randf() < 0.55:
			chunk.add_sky_platform(Vector3(sky_x, sky_y, -18.5), Vector3(3.8, 0.34, 10.0), true)
			var top_y := sky_y + 0.17
			_spawn_chunk_entity(
				TrackEntityFactory.create_aerial_bonus_ring(Vector3(sky_x, sky_y + 1.25, z0 - 15.6), false),
				chunk
			)
			if rng.randf() < 0.55:
				_spawn_chunk_entity(
					TrackEntityFactory.create_wooden_pin(Vector3(sky_x - 0.52, top_y + 0.79, z0 - 21.0)),
					chunk
				)
				_spawn_chunk_entity(
					TrackEntityFactory.create_wooden_pin(Vector3(sky_x + 0.52, top_y + 0.79, z0 - 21.0)),
					chunk
				)
			else:
				var sky_yaw := rng.randf_range(-20.0, 20.0)
				_spawn_chunk_entity(
					TrackEntityFactory.create_crate(Vector3(sky_x, top_y + 0.50, z0 - 21.0), "light", sky_yaw),
					chunk
				)
			return {"has_approach_updraft": false, "has_sky_platform": true}
		else:
			var blocker_off_x := 1.15 if rng.randf() < 0.5 else -1.15
			_spawn_chunk_entity(
				TrackEntityFactory.create_aerial_bonus_ring(Vector3(sky_x, sky_y + 0.4, z0 - 16.5), false),
				chunk
			)
			_spawn_chunk_entity(
				TrackEntityFactory.create_aerial_blocker(
					Vector3(clampf(sky_x + blocker_off_x, -3.8, 3.8), sky_y + 0.2, z0 - 19.6),
					_roll_blocker_type(level, rng),
					rng.randf_range(0.0, TAU)
				),
				chunk
			)
			return {"has_approach_updraft": false, "has_sky_platform": false}

	# StraightWide, SplitPath, PinballAlley, FunnelGauntlet
	var sky_x := 0.0
	if chunk.chunk_type == "SplitPath":
		sky_x = -3.85 if rng.randf() < 0.5 else 3.85
	else:
		var lane_choices: Array[float] = [-3.6, 0.0, 3.6]
		sky_x = lane_choices[rng.randi_range(0, 2)]

	var sky_y := rng.randf_range(4.6, 5.3)
	chunk.add_sky_platform(Vector3(sky_x, sky_y, -16.2), Vector3(3.8, 0.34, 11.2), rng.randf() < 0.65)
	var top_y := sky_y + 0.17
	_spawn_chunk_entity(
		TrackEntityFactory.create_aerial_bonus_ring(Vector3(sky_x, top_y + 1.20, z0 - 13.0), false),
		chunk
	)

	if rng.randf() < 0.55:
		_spawn_chunk_entity(
			TrackEntityFactory.create_wooden_pin(Vector3(sky_x - 0.52, top_y + 0.79, z0 - 19.2)),
			chunk
		)
		_spawn_chunk_entity(
			TrackEntityFactory.create_wooden_pin(Vector3(sky_x + 0.52, top_y + 0.79, z0 - 19.2)),
			chunk
		)
	else:
		var sky_yaw := rng.randf_range(-20.0, 20.0)
		_spawn_chunk_entity(
			TrackEntityFactory.create_crate(Vector3(sky_x, top_y + 0.50, z0 - 19.2), "light", sky_yaw),
			chunk
		)

	if rng.randf() < 0.55:
		_spawn_chunk_entity(
			TrackEntityFactory.create_wind_zone(
				Vector3(sky_x, 2.35, z0 - 6.8),
				Vector3(4.2, 4.7, 8.2),
				"updraft",
				45.0
			),
			chunk
		)
		return {"has_approach_updraft": true, "has_sky_platform": true}

	return {"has_approach_updraft": false, "has_sky_platform": true}


func _populate_chunk_wind_zones(
	chunk: TrackChunkBase,
	level: int,
	rng: RandomNumberGenerator,
	is_first_chunk: bool,
	has_approach_updraft: bool,
	has_sky_platform: bool = false
) -> void:
	if is_first_chunk or has_approach_updraft:
		return

	var wind_prob := clampf(0.50 + 0.04 * float(level - 1), 0.50, 0.68)
	if rng.randf() >= wind_prob:
		return

	var z0 := chunk.entry_z

	if has_sky_platform or rng.randf() < 0.58:
		var wz_y := 1.85
		var wz_z := z0 - chunk.length * rng.randf_range(0.42, 0.68)
		match chunk.chunk_type:
			"NarrowBridge":
				var nb_presets: Array[String] = ["cross_left", "cross_right", "tailwind"]
				var nb_preset := nb_presets[rng.randi_range(0, 2)]
				var nb_force := 26.0 if nb_preset == "tailwind" else 21.0
				_spawn_chunk_entity(
					TrackEntityFactory.create_wind_zone(
						Vector3(0.0, wz_y, wz_z),
						Vector3(6.5, 3.6, 10.0),
						nb_preset,
						nb_force
					),
					chunk
				)
			"SplitPath":
				var sp_x := -3.85 if rng.randf() < 0.5 else 3.85
				var sp_presets: Array[String] = ["tailwind", "headwind", "updraft"]
				var sp_preset := sp_presets[rng.randi_range(0, 2)]
				var sp_force := 30.0
				if sp_preset == "headwind":
					sp_force = 21.0
				elif sp_preset == "updraft":
					sp_force = 44.0
				_spawn_chunk_entity(
					TrackEntityFactory.create_wind_zone(
						Vector3(sp_x, wz_y, wz_z),
						Vector3(5.2, 3.6, 11.5),
						sp_preset,
						sp_force
					),
					chunk
				)
			_:
				var wide_presets: Array[String] = ["cross_left", "cross_right", "tailwind", "updraft", "headwind"]
				var w_preset := wide_presets[rng.randi_range(0, 4)]
				var w_force := 44.0 if w_preset == "updraft" else rng.randf_range(23.0, 31.0)
				if w_preset == "headwind":
					var hw_x := -3.1 if rng.randf() < 0.5 else 3.1
					_spawn_chunk_entity(
						TrackEntityFactory.create_wind_zone(
							Vector3(hw_x, wz_y, wz_z),
							Vector3(5.6, 3.6, 10.5),
							w_preset,
							w_force
						),
						chunk
					)
				elif w_preset == "updraft":
					var up_x := rng.randf_range(-2.6, 2.6)
					_spawn_chunk_entity(
						TrackEntityFactory.create_wind_zone(
							Vector3(up_x, 2.15, wz_z),
							Vector3(6.0, 4.2, 10.5),
							w_preset,
							w_force
						),
						chunk
					)
				else:
					_spawn_chunk_entity(
						TrackEntityFactory.create_wind_zone(
							Vector3(0.0, wz_y, wz_z),
							Vector3(10.5, 3.6, 11.0),
							w_preset,
							w_force
						),
						chunk
					)
	else:
		var air_y := rng.randf_range(3.8, 5.4)
		var air_z := z0 - chunk.length * 0.55
		var air_presets: Array[String] = [
			"cross_left",
			"cross_right",
			"tailwind",
			"high_downdraft_left",
			"high_downdraft_right",
		]
		var air_preset := air_presets[rng.randi_range(0, 4)]
		var air_force := rng.randf_range(22.0, 29.0)
		_spawn_chunk_entity(
			TrackEntityFactory.create_wind_zone(
				Vector3(0.0, air_y, air_z),
				Vector3(10.5, 3.4, 11.5),
				air_preset,
				air_force
			),
			chunk
		)
