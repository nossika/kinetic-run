extends TestBase


func run() -> void:
	await _test_track_length_scaling_and_seamless_alignment()
	await _test_chunk_variety_and_funnel_level_gate()


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

	# Level 1 & 2 must NOT spawn FunnelGauntlet
	for s in range(1, 8):
		var info_early: Dictionary = gen.generate_track(1, s * 77)
		for ch in info_early["chunks"]:
			assert_true(ch.chunk_type != "FunnelGauntlet", "FunnelGauntlet is gated until Level 3+")

	# Across seeded Level 5 tracks, all 6 chunk types appear
	var seen_types: Dictionary = {}
	for s in range(1, 15):
		var info_mid: Dictionary = gen.generate_track(5, s * 131)
		for ch in info_mid["chunks"]:
			seen_types[ch.chunk_type] = true

	for expected_type in [
		"StraightWide",
		"NarrowBridge",
		"SplitPath",
		"RampGap",
		"PinballAlley",
		"FunnelGauntlet"
	]:
		assert_true(seen_types.has(expected_type), "Chunk type '%s' spawns by Level 5" % expected_type)

	root.queue_free()
	await scene_tree.process_frame
