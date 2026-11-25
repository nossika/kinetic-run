extends TestBase


func run() -> void:
	await _test_track_length_scaling_and_seamless_alignment()
	await _test_chunk_variety_and_funnel_level_gate()
	await _test_sloped_track_root_and_coordinate_transforms()
	await _test_wave_hills_side_launch_ramp_and_vertical_entities()
	await _test_deterministic_multi_level_seed_layout()


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
	assert_gt(peak_slab_y, 1.0, "WaveHills builds elevated beechwood hill crests above y=+1.0m")

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
	var found_light_crate := false
	var found_medium_crate := false
	var sample_ring: AerialBonusRing = null

	for s in range(1, 10):
		var info: Dictionary = gen.generate_track(2, 9000 + s * 37)
		for ent in info["entities"]:
			if ent is SpringPad:
				found_spring = true
			elif ent is AerialBonusRing:
				found_ring = true
				if sample_ring == null:
					sample_ring = ent as AerialBonusRing
			elif ent is AerialBlocker:
				found_blocker = true
			elif ent is CrateObstacle:
				var c := ent as CrateObstacle
				if c.weight_tier == "medium":
					found_medium_crate = true
				else:
					found_light_crate = true

	assert_true(found_spring, "Generated tracks spawn SpringPad entities")
	assert_true(found_ring, "Generated tracks spawn AerialBonusRing entities")
	assert_true(found_blocker, "Generated tracks spawn AerialBlocker entities")
	assert_true(found_light_crate, "Generated tracks spawn 500g light crates")
	assert_true(found_medium_crate, "Generated Level 2+ tracks deterministically mix 2.5kg medium crates")

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
		var extra: String = str(node_ent.get_meta("weight_label", ""))
		if node_ent is AerialBlocker:
			extra += "|phase=%0.4f" % (node_ent as AerialBlocker).initial_phase
		ent_records.append("%s@(%0.3f,%0.3f,%0.3f)[%s]" % [scr_path, p.x, p.y, p.z, extra])

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

	for lvl in [1, 2]:
		var track_seed_1: int = run_script.derive_track_seed(seed_main, lvl)
		var track_seed_2: int = run_script.derive_track_seed(seed_main, lvl)
		assert_eq(track_seed_1, track_seed_2, "RunState.derive_track_seed is deterministic for Level %d" % lvl)

		var sig_a := _capture_track_signature(gen_a.generate_track(lvl, track_seed_1))
		var sig_b := _capture_track_signature(gen_b.generate_track(lvl, track_seed_2))

		assert_eq(sig_a["chunk_types"], sig_b["chunk_types"], "Same seed Level %d produces identical chunk type array" % lvl)
		assert_eq(sig_a["entity_count"], sig_b["entity_count"], "Same seed Level %d produces identical entity count" % lvl)
		assert_eq(sig_a["entity_records"], sig_b["entity_records"], "Same seed Level %d produces identical entity classes, tiers, phases, and local positions" % lvl)

		var diff_seed: int = run_script.derive_track_seed(seed_other, lvl)
		var sig_diff: Dictionary = _capture_track_signature(gen_b.generate_track(lvl, diff_seed))
		var differs: bool = (sig_a["chunk_types"] != sig_diff["chunk_types"]) or (sig_a["entity_records"] != sig_diff["entity_records"])
		assert_true(differs, "Different seed on Level %d produces a different track layout" % lvl)

	root.queue_free()
	await scene_tree.process_frame
