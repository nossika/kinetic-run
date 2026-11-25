extends SceneTree

const SUITES: Array[String] = [
	"res://tests/test_core_stats.gd",
	"res://tests/test_synergy_and_upgrades.gd",
	"res://tests/test_ball_and_gravity.gd",
	"res://tests/test_entities.gd",
	"res://tests/test_track_generator.gd",
	"res://tests/test_game_loop.gd",
]


func _initialize() -> void:
	call_deferred("_execute_all")


func _execute_all() -> void:
	var total_assertions := 0
	var total_failures := 0
	var suite_count := 0

	var sanity := TestBase.new()
	sanity.assert_true(true, "Sanity check")
	suite_count += 1
	total_assertions += sanity.passed_assertions

	for suite_path in SUITES:
		var script_res: GDScript = load(suite_path)
		if script_res == null:
			printerr("FAIL: Could not load suite: %s" % suite_path)
			total_failures += 1
			continue
		var suite: TestBase = script_res.new()
		suite.scene_tree = self
		suite_count += 1
		if suite.has_method("run"):
			await suite.run()
		total_assertions += suite.passed_assertions
		if suite.failures.size() > 0:
			printerr("SUITE FAILED: %s" % suite_path)
			for msg in suite.failures:
				printerr("  - %s" % msg)
			total_failures += suite.failures.size()
		else:
			print("SUITE PASS: %s (%d assertions)" % [suite_path, suite.passed_assertions])

	if total_failures > 0:
		printerr("TEST SUMMARY: FAILED (%d failures across %d suites)" % [total_failures, suite_count])
		quit(1)
	else:
		print("TEST SUMMARY: PASS (%d suites, %d assertions, 0 failures)" % [suite_count, total_assertions])
		quit(0)
