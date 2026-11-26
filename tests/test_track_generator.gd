extends TestBase


func run() -> void:
	await _test_track_length_scaling_and_seamless_alignment()
	await _test_chunk_variety_and_funnel_level_gate()
	await _test_sloped_track_root_and_coordinate_transforms()
	await _test_wave_hills_side_launch_ramp_and_vertical_entities()
	await _test_deterministic_multi_level_seed_layout()
	await _test_rigidbody_clearance_and_chunk_z_bounds()


func _test_track_length_scaling_and_seamless_alignment() -> void:
	var gen_script: GDScript = load("res://src/track/track_generator_3d.gd")
	var run_script: GDScript = load("res://src/core/run_state.gd")
	assert_true(gen_script != null, "TrackGenerator3D script must exist")
	if gen_script == null or run_script == null:
		return

	var root := Node3D.new()
	scene_tree.root.add_child(root)
	var gen = gen_script.new()
	root.add_child(gen)

	var prev_len := 0.0
	for lvl in [1, 3, 6, 10]:
		var info: Dictionary = gen.generate_track(lvl, 1000 + lvl)
		var total_len := float(info["total_length"])
		var target_len := float(run_script.target_length_for_level(lvl))
		assert_true(
			total_len >= target_len,
			"Level %d generated length (%0.1f) meets target (%0.1f)" % [lvl, total_len, target_len]
		)
		assert_gt(total_len, prev_len, "Generated length strictly grows across tested levels")
		prev_len = total_len

		var chunks: Array = info["chunks"]
		assert_gt(float(chunks.size()), 3.0, "Track contains multiple modular chunks")
		for i in range(chunks.size() - 1):
			assert_approx(
				float(chunks[i].exit_z),
				float(chunks[i + 1].entry_z),
				0.001,
				"Chunk %d exit_z seamlessly matches Chunk %d entry_z" % [i, i + 1]
			)

		var entities: Array = info["entities"]
		assert_gt(float(entities.size()), 4.0, "Generated track spawns obstacles, monsters, and boosters")

	for s in range(1, 25):
		var info_l1: Dictionary = gen.generate_track(1, s * 7919 + 11)
		var info_l2: Dictionary = gen.generate_track(2, s * 7919 + 22)
		assert_lt(
			float(info_l2["finish_z"]),
			float(info_l1["finish_z"]) - 40.0,
			"Seed %d Level 2 finish_z extends >40m beyond Level 1 finish_z" % s
		)

	root.queue_free()
	await scene_tree.process_frame


func _test_chunk_variety_and_funnel_level_gate() -> void:
	var gen_script: GDScript = load("res://src/track/track_generator_3d.gd")
	if gen_script == null:
		return

	var root := Node3D.new()
	scene_tree.root.add_child(root)
	var gen = gen_script.new()
	root.add_child(gen)

	# Level 1 must include WaveHills in the chunk pool while gating FunnelGauntlet until Level 3+
	var seen_lvl1_types: Dictionary = {}
	for s in range(1, 18):
		var info_early: Dictionary = gen.generate_track(1, s * 77)
		for ch in info_early["chunks"]:
			seen_lvl1_types[ch.chunk_type] = true
			assert_true(ch.chunk_type != "FunnelGauntlet", "FunnelGauntlet is gated until Level 3+")
	assert_true(seen_lvl1_types.has("WaveHills"), "Chunk type 'WaveHills' spawns starting from Level 1")

	# Across seeded Level 5 tracks, all 7 chunk types appear
	var seen_types: Dictionary = {}
	for s in range(1, 18):
		var info_mid: Dictionary = gen.generate_track(5, s * 131)
		for ch in info_mid["chunks"]:
			seen_types[ch.chunk_type] = true

	for expected_type in [
		"StraightWide",
		"NarrowBridge",
		"SplitPath",
		"RampGap",
		"PinballAlley",
		"WaveHills",
		"FunnelGauntlet"
	]:
		assert_true(seen_types.has(expected_type), "Chunk type '%s' spawns by Level 5" % expected_type)

	root.queue_free()
	await scene_tree.process_frame


func _test_sloped_track_root_and_coordinate_transforms() -> void:
	var gen_script: GDScript = load("res://src/track/track_generator_3d.gd")
	var ball_script: GDScript = load("res://src/gameplay/player_ball_3d.gd")
	var bus_script: GDScript = load("res://src/core/physics_synergy_bus.gd")
	if gen_script == null or ball_script == null or bus_script == null:
		return

	var root := Node3D.new()
	scene_tree.root.add_child(root)

	var ball = ball_script.new()
	ball.name = "PlayerBall3D"
	root.add_child(ball)
	ball.setup(bus_script.new())

	var gen = gen_script.new()
	gen.name = "TrackGenerator3D"

	# Verify out-of-tree coordinate transforms before adding to scene tree
	gen.generate_track(1, 4242)
	assert_true("TRACK_SLOPE_PITCH_DEG" in gen, "TrackGenerator3D defines TRACK_SLOPE_PITCH_DEG")
	if "TRACK_SLOPE_PITCH_DEG" in gen:
		assert_approx(float(gen.TRACK_SLOPE_PITCH_DEG), -11.0, 0.001, "TRACK_SLOPE_PITCH_DEG is -11.0")

	assert_true(gen.has_method("get_track_root"), "TrackGenerator3D exposes get_track_root()")
	assert_true(gen.has_method("track_local_to_world"), "TrackGenerator3D exposes track_local_to_world()")
	assert_true(gen.has_method("world_to_track_local"), "TrackGenerator3D exposes world_to_track_local()")
	assert_true(gen.has_signal("bonus_ring_collected"), "TrackGenerator3D defines signal bonus_ring_collected")

	if gen.has_method("get_track_root") and gen.has_method("track_local_to_world") and gen.has_method("world_to_track_local"):
		var out_world: Vector3 = gen.track_local_to_world(Vector3(0.0, 0.0, -100.0))
		assert_lt(out_world.y, -18.0, "Out-of-tree track_local_to_world(0, 0, -100).y < -18.0 on -11° slope")
		var out_roundtrip: Vector3 = gen.world_to_track_local(out_world)
		assert_approx(out_roundtrip.distance_to(Vector3(0.0, 0.0, -100.0)), 0.0, 0.001, "Out-of-tree world_to_track_local round-trips cleanly")

	# Add to tree and regenerate to verify in-tree transforms and automatic sibling PlayerBall3D track_reference wiring
	root.add_child(gen)
	gen.generate_track(1, 4242)

	if gen.has_method("get_track_root") and gen.has_method("track_local_to_world") and gen.has_method("world_to_track_local"):
		var track_root: Node3D = gen.get_track_root()
		assert_true(track_root != null, "get_track_root() returns GeneratedTrack Node3D")
		if track_root != null:
			assert_approx(track_root.rotation_degrees.x, -11.0, 0.001, "GeneratedTrack rotation_degrees.x is -11.0")
			assert_true(ball.track_reference == track_root, "generate_track wires sibling PlayerBall3D.track_reference to new _track_root")

		var world_pt: Vector3 = gen.track_local_to_world(Vector3(0.0, 0.0, -100.0))
		assert_lt(world_pt.y, -18.0, "In-tree track_local_to_world(0, 0, -100).y < -18.0 (~-19.08m)")
		var local_pt: Vector3 = gen.world_to_track_local(world_pt)
		assert_approx(local_pt.distance_to(Vector3(0.0, 0.0, -100.0)), 0.0, 0.001, "In-tree world_to_track_local round-trips cleanly")

		# Regenerating a second level updates sibling ball's track_reference to the newly created _track_root
		gen.generate_track(2, 5353)
		assert_true(ball.track_reference == gen.get_track_root(), "Regenerating track refreshes sibling PlayerBall3D.track_reference")

		# Null _track_root fallback uses global_transform when generator is inside tree under an offset parent
		var offset_holder := Node3D.new()
		offset_holder.position = Vector3(5.0, 3.0, -4.0)
		root.add_child(offset_holder)
		var gen_offset = gen_script.new()
		offset_holder.add_child(gen_offset)
		var null_root_world: Vector3 = gen_offset.track_local_to_world(Vector3.ZERO)
		assert_approx(
			null_root_world.distance_to(Vector3(5.0, 3.0, -4.0)),
			0.0,
			0.001,
			"In-tree null _track_root fallback uses global_transform origin"
		)
		var null_root_local: Vector3 = gen_offset.world_to_track_local(null_root_world)
		assert_approx(
			null_root_local.distance_to(Vector3.ZERO),
			0.0,
			0.001,
			"In-tree null _track_root world_to_track_local round-trips via global_transform"
		)

	root.queue_free()
	await scene_tree.process_frame


func _test_wave_hills_side_launch_ramp_and_vertical_entities() -> void:
	var gen_script: GDScript = load("res://src/track/track_generator_3d.gd")
	var chunk_script: GDScript = load("res://src/track/track_chunk_base.gd")
	var ball_script: GDScript = load("res://src/gameplay/player_ball_3d.gd")
	var bus_script: GDScript = load("res://src/core/physics_synergy_bus.gd")
	if gen_script == null or chunk_script == null or ball_script == null or bus_script == null:
		return

	var root := Node3D.new()
	scene_tree.root.add_child(root)

	# 1. Direct WaveHills & add_side_launch_ramp inspection on TrackChunkBase
	var wave_chunk = chunk_script.new()
	root.add_child(wave_chunk)
	wave_chunk.build_chunk("WaveHills", -10.0)
	assert_approx(wave_chunk.length, 30.0, 0.01, "WaveHills chunk length is 30.0m")
	assert_approx(wave_chunk.exit_z, -40.0, 0.01, "WaveHills exit_z advances by -30.0m")

	var peak_slab_y := -99.0
	for child in wave_chunk.get_children():
		if child is StaticBody3D and not child.is_in_group("track_rail"):
			peak_slab_y = maxf(peak_slab_y, (child as StaticBody3D).position.y)
	var crest_top_y: float = peak_slab_y + float(chunk_script.FLOOR_THICKNESS) * 0.5
	assert_approx(crest_top_y, 1.45, 0.05, "WaveHills crest top surface reaches +1.45m (±0.05m) local Y")

	assert_true(wave_chunk.has_method("add_side_launch_ramp"), "TrackChunkBase exposes add_side_launch_ramp()")
	if wave_chunk.has_method("add_side_launch_ramp"):
		var ramp = wave_chunk.add_side_launch_ramp(Vector3(3.2, 0.0, -14.0), 2.4)
		assert_true(ramp is StaticBody3D, "add_side_launch_ramp returns StaticBody3D")
		if ramp is StaticBody3D:
			assert_approx(ramp.rotation_degrees.x, 16.0, 0.05, "Side launch ramp pitches upward at +16.0°")
			assert_eq(bool(ramp.get_meta("is_anchored_fixed", false)), true, "Side launch ramp carries anchored flange base meta")

	# 2. Generated tracks include SpringPad, AerialBonusRing, AerialBlocker, and mixed crate tiers on Level 2+
	var gen = gen_script.new()
	root.add_child(gen)
	var ball = ball_script.new()
	root.add_child(ball)
	ball.setup(bus_script.new())

	var bonus_signal_state := {"count": 0, "seconds": 0.0}
	if gen.has_signal("bonus_ring_collected"):
		gen.bonus_ring_collected.connect(
			func(sec: float) -> void:
				bonus_signal_state["count"] = int(bonus_signal_state["count"]) + 1
				bonus_signal_state["seconds"] = sec
		)

	var found_spring := false
	var found_ring := false
	var found_blocker := false
	var found_balloon_blocker := false
	var found_iron_blocker := false
	var found_light_crate := false
	var found_medium_crate := false
	var found_wooden_pin := false
	var found_slime := false
	var found_barrel := false
	var found_brute := false
	var all_medium_crates_angled := true
	var min_medium_crate_yaw := 999.0
	var narrow_bridge_medium_crates := 0
	var narrow_bridge_light_or_pin := 0
	var pin_chunks_seen: Dictionary = {}
	var sample_ring: AerialBonusRing = null

	for s in range(1, 16):
		var lvl := 2 if s <= 5 else 3
		var info: Dictionary = gen.generate_track(lvl, 9000 + s * 37)
		var chunks: Array = info["chunks"]
		for ent in info["entities"]:
			var node_ent := ent as Node3D
			var owner_chunk_type := ""
			for ch in chunks:
				if node_ent.position.z <= ch.entry_z and node_ent.position.z >= ch.exit_z:
					owner_chunk_type = String(ch.chunk_type)
					break

			if ent is SpringPad:
				found_spring = true
			elif ent is AerialBonusRing:
				found_ring = true
				if sample_ring == null:
					sample_ring = ent as AerialBonusRing
			elif ent is AerialBlocker:
				found_blocker = true
				assert_true(ent is RigidBody3D, "AerialBlocker is a native RigidBody3D")
				var ab := ent as AerialBlocker
				if ab.blocker_type == "mag_iron" and ab.weight_label == "12kg":
					found_iron_blocker = true
				elif ab.blocker_type == "soft_balloon" and ab.weight_label == "250g":
					found_balloon_blocker = true
			elif ent is CrateObstacle:
				var c := ent as CrateObstacle
				if c.weight_tier == "medium":
					found_medium_crate = true
					assert_eq(c.weight_label, "2kg", "Medium crate weight_label is 2kg")
					var abs_yaw := absf(c.rotation_degrees.y)
					min_medium_crate_yaw = minf(min_medium_crate_yaw, abs_yaw)
					if abs_yaw < 15.0:
						all_medium_crates_angled = false
					if owner_chunk_type == "NarrowBridge":
						narrow_bridge_medium_crates += 1
				else:
					found_light_crate = true
					assert_eq(c.weight_label, "500g", "Light crate weight_label is 500g")
					if owner_chunk_type == "NarrowBridge":
						narrow_bridge_light_or_pin += 1
			elif ent is WoodenPin:
				found_wooden_pin = true
				var wp := ent as WoodenPin
				assert_eq(wp.weight_label, "800g", "WoodenPin weight_label is 800g")
				if owner_chunk_type != "":
					pin_chunks_seen[owner_chunk_type] = true
				if owner_chunk_type == "NarrowBridge":
					narrow_bridge_light_or_pin += 1
			elif ent is BouncerSlime:
				found_slime = true
				assert_true(ent is RigidBody3D, "BouncerSlime is a native RigidBody3D")
				assert_eq((ent as BouncerSlime).weight_label, "3kg", "BouncerSlime weight_label is 3kg")
			elif ent is ExplosiveBarrel:
				found_barrel = true
				assert_true(ent is RigidBody3D, "ExplosiveBarrel is a native RigidBody3D")
				assert_eq((ent as ExplosiveBarrel).weight_label, "1.5kg", "ExplosiveBarrel weight_label is 1.5kg")
			elif ent is ShieldBrute:
				found_brute = true
				assert_true(ent is RigidBody3D, "ShieldBrute is a native RigidBody3D")
				assert_eq((ent as ShieldBrute).weight_label, "20kg", "ShieldBrute weight_label is 20kg")

	assert_true(found_spring, "Generated tracks spawn SpringPad entities")
	assert_true(found_ring, "Generated tracks spawn AerialBonusRing entities")
	assert_true(found_blocker, "Generated tracks spawn AerialBlocker entities")
	assert_true(found_balloon_blocker, "Generated tracks spawn 250g soft_balloon AerialBlockers")
	assert_true(found_iron_blocker, "Generated Level 3+ tracks spawn 12kg mag_iron AerialBlockers")
	assert_true(found_light_crate, "Generated tracks spawn 500g light crates")
	assert_true(found_medium_crate, "Generated Level 2+ tracks deterministically mix 2kg medium crates")
	assert_true(
		all_medium_crates_angled and min_medium_crate_yaw >= 15.0,
		"Every 2kg medium crate spawns with angled yaw abs(rotation_degrees.y) >= 15.0 (min=%0.2f°)" % min_medium_crate_yaw
	)
	assert_true(found_wooden_pin, "Generated tracks spawn 800g WoodenPin entities")
	assert_true(found_slime, "Generated tracks spawn 3kg BouncerSlime RigidBody3D entities")
	assert_true(found_barrel, "Generated tracks spawn 1.5kg ExplosiveBarrel RigidBody3D entities")
	assert_true(found_brute, "Generated tracks spawn 20kg ShieldBrute RigidBody3D entities")
	assert_eq(narrow_bridge_medium_crates, 0, "NarrowBridge chunks contain zero 2kg medium crates")
	assert_gt(float(narrow_bridge_light_or_pin), 0.0, "NarrowBridge Level 2+ chunks spawn lightweight 500g crates or 800g WoodenPins")
	for expected_pin_chunk in ["StraightWide", "WaveHills", "SplitPath", "FunnelGauntlet"]:
		assert_true(
			pin_chunks_seen.has(expected_pin_chunk),
			"WoodenPin formations spawn in '%s' chunks" % expected_pin_chunk
		)

	# Verify bonus_ring_collected signal forwarding on TrackGenerator3D
	if sample_ring != null and is_instance_valid(sample_ring) and gen.has_signal("bonus_ring_collected"):
		sample_ring.interact_with_ball(ball)
		assert_eq(int(bonus_signal_state["count"]), 1, "Collecting AerialBonusRing emits TrackGenerator3D.bonus_ring_collected")
		assert_approx(float(bonus_signal_state["seconds"]), 0.8, 0.001, "bonus_ring_collected forwards +0.8s")

	root.queue_free()
	await scene_tree.process_frame


func _capture_track_signature(info: Dictionary) -> Dictionary:
	var chunk_types: Array[String] = []
	for ch in info["chunks"]:
		chunk_types.append(String(ch.chunk_type))

	var ent_records: Array[String] = []
	for ent in info["entities"]:
		var node_ent := ent as Node3D
		var scr: Script = node_ent.get_script()
		var scr_path: String = scr.resource_path if scr != null else node_ent.get_class()
		var p: Vector3 = node_ent.position
		var rot_y: float = node_ent.rotation_degrees.y
		var extra: String = str(node_ent.get_meta("weight_label", ""))
		if node_ent is AerialBlocker:
			extra += "|phase=%0.4f" % (node_ent as AerialBlocker).initial_phase
		ent_records.append("%s@(%0.3f,%0.3f,%0.3f)rotY=%0.3f[%s]" % [scr_path, p.x, p.y, p.z, rot_y, extra])

	return {
		"chunk_types": chunk_types,
		"entity_count": ent_records.size(),
		"entity_records": ent_records,
	}


func _test_deterministic_multi_level_seed_layout() -> void:
	var gen_script: GDScript = load("res://src/track/track_generator_3d.gd")
	var run_script: GDScript = load("res://src/core/run_state.gd")
	if gen_script == null or run_script == null:
		return

	var root := Node3D.new()
	scene_tree.root.add_child(root)
	var gen_a = gen_script.new()
	var gen_b = gen_script.new()
	root.add_child(gen_a)
	root.add_child(gen_b)

	var seed_main := 20261125
	var seed_other := 99887766

	for lvl in [1, 2, 3]:
		var track_seed_1: int = run_script.derive_track_seed(seed_main, lvl)
		var track_seed_2: int = run_script.derive_track_seed(seed_main, lvl)
		assert_eq(track_seed_1, track_seed_2, "RunState.derive_track_seed is deterministic for Level %d" % lvl)

		var sig_a := _capture_track_signature(gen_a.generate_track(lvl, track_seed_1))
		var sig_b := _capture_track_signature(gen_b.generate_track(lvl, track_seed_2))

		assert_eq(sig_a["chunk_types"], sig_b["chunk_types"], "Same seed Level %d produces identical chunk type array" % lvl)
		assert_eq(sig_a["entity_count"], sig_b["entity_count"], "Same seed Level %d produces identical entity count" % lvl)
		assert_eq(sig_a["entity_records"], sig_b["entity_records"], "Same seed Level %d produces identical entity classes, tiers, rotations, phases, and local positions" % lvl)

		var diff_seed: int = run_script.derive_track_seed(seed_other, lvl)
		var sig_diff: Dictionary = _capture_track_signature(gen_b.generate_track(lvl, diff_seed))
		var differs: bool = (sig_a["chunk_types"] != sig_diff["chunk_types"]) or (sig_a["entity_records"] != sig_diff["entity_records"])
		assert_true(differs, "Different seed on Level %d produces a different track layout" % lvl)

	root.queue_free()
	await scene_tree.process_frame


func _test_rigidbody_clearance_and_chunk_z_bounds() -> void:
	var gen_script: GDScript = load("res://src/track/track_generator_3d.gd")
	if gen_script == null:
		return

	var root := Node3D.new()
	scene_tree.root.add_child(root)
	var gen = gen_script.new()
	root.add_child(gen)

	assert_true("MIN_PIN_CLEARANCE_XZ" in gen, "TrackGenerator3D defines MIN_PIN_CLEARANCE_XZ")
	if "MIN_PIN_CLEARANCE_XZ" in gen:
		assert_approx(float(gen.MIN_PIN_CLEARANCE_XZ), 0.92, 0.001, "MIN_PIN_CLEARANCE_XZ is 0.92m")

	# Direct unit verification of 3D layered + pin-aware clearance helper
	gen.generate_track(1, 1111)
	gen.active_entities.clear()
	var aerial_rb := TrackEntityFactory.create_aerial_blocker(Vector3(0.0, 2.65, -20.0), "soft_balloon", 0.0)
	gen._spawn_entity(aerial_rb)
	assert_true(
		gen._is_rigidbody_pos_clear(Vector3(0.0, 0.50, -20.0), false),
		"AerialBlocker at Y=2.65m does not displace ground obstacle at Y=0.50m (different vertical layer)"
	)
	var pin_a := TrackEntityFactory.create_wooden_pin(Vector3(-0.52, 0.79, -20.0))
	gen._spawn_entity(pin_a)
	assert_true(
		gen._is_rigidbody_pos_clear(Vector3(0.52, 0.79, -20.0), true),
		"Two co-planar WoodenPins 1.04m apart satisfy MIN_PIN_CLEARANCE_XZ (0.92m)"
	)
	assert_false(
		gen._is_rigidbody_pos_clear(Vector3(0.20, 0.79, -20.0), true),
		"Two co-planar WoodenPins 0.72m apart violate MIN_PIN_CLEARANCE_XZ (0.92m)"
	)
	assert_false(
		gen._is_rigidbody_pos_clear(Vector3(0.52, 0.50, -20.0), false),
		"Non-pin ground RigidBody3D 1.04m from a WoodenPin violates MIN_RB_CLEARANCE_XZ (1.90m)"
	)

	var min_non_pin_rb_dist := 999.0
	var min_pin_pair_dist := 999.0
	var pin_pair_count := 0
	var out_of_bounds_count := 0

	for lvl in [1, 3, 5, 9]:
		for s in range(1, 7):
			var info: Dictionary = gen.generate_track(lvl, lvl * 10007 + s * 313)
			var fin_z := float(info["finish_z"])
			var start_apron_z := -float(gen.START_APRON_LEN)
			var rbs: Array[Node3D] = []

			var ent_idx := 0
			for ent in info["entities"]:
				var node_ent := ent as Node3D
				# Entity 0 is the start-apron BoostPad at z = -7.5; all chunk entities must stay inside chunk Z bounds
				if ent_idx == 0:
					if node_ent.position.z > 4.0 or node_ent.position.z < fin_z:
						out_of_bounds_count += 1
				else:
					if node_ent.position.z > start_apron_z - 1.4 or node_ent.position.z < fin_z + 1.4:
						out_of_bounds_count += 1
				if node_ent is RigidBody3D:
					rbs.append(node_ent)
				ent_idx += 1

			for i in range(rbs.size()):
				var pi := Vector2(rbs[i].position.x, rbs[i].position.z)
				for j in range(i + 1, rbs.size()):
					if absf(rbs[i].position.y - rbs[j].position.y) >= 1.50:
						continue
					var pj := Vector2(rbs[j].position.x, rbs[j].position.z)
					var d := pi.distance_to(pj)
					if rbs[i] is WoodenPin and rbs[j] is WoodenPin:
						min_pin_pair_dist = minf(min_pin_pair_dist, d)
						if d < 1.85:
							pin_pair_count += 1
					else:
						min_non_pin_rb_dist = minf(min_non_pin_rb_dist, d)

	assert_eq(out_of_bounds_count, 0, "All chunk entities spawn strictly within [finish_z + 1.4, -START_APRON_LEN - 1.4]")
	assert_gt(float(pin_pair_count), 0.0, "Generated tracks contain tight WoodenPin bowling clusters (< 1.85m pin-to-pin spacing)")
	assert_true(
		min_pin_pair_dist >= 0.90,
		"Every co-planar WoodenPin pair maintains >= 0.90m XZ clearance (min=%0.3fm)" % min_pin_pair_dist
	)
	assert_true(
		min_non_pin_rb_dist >= 1.85,
		"Every co-planar non-pin RigidBody3D pair maintains >= 1.85m XZ clearance (min=%0.3fm)" % min_non_pin_rb_dist
	)

	root.queue_free()
	await scene_tree.process_frame
