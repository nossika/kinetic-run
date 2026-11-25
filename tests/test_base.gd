class_name TestBase
extends RefCounted

var passed_assertions: int = 0
var failures: Array[String] = []
var scene_tree: SceneTree = null


func assert_true(condition: bool, message: String = "Expected condition to be true") -> void:
	if condition:
		passed_assertions += 1
	else:
		failures.append(message)


func assert_false(condition: bool, message: String = "Expected condition to be false") -> void:
	assert_true(not condition, message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual == expected:
		passed_assertions += 1
	else:
		var detail := message if message != "" else "Values not equal"
		failures.append("%s (expected=%s, actual=%s)" % [detail, str(expected), str(actual)])


func assert_approx(actual: float, expected: float, eps: float = 0.001, message: String = "") -> void:
	if absf(actual - expected) <= eps:
		passed_assertions += 1
	else:
		var detail := message if message != "" else "Floats not approximately equal"
		failures.append("%s (expected=%0.4f ± %0.4f, actual=%0.4f)" % [detail, expected, eps, actual])


func assert_gt(actual: float, threshold: float, message: String = "") -> void:
	if actual > threshold:
		passed_assertions += 1
	else:
		var detail := message if message != "" else "Expected value > threshold"
		failures.append("%s (actual=%0.4f <= threshold=%0.4f)" % [detail, actual, threshold])


func assert_lt(actual: float, threshold: float, message: String = "") -> void:
	if actual < threshold:
		passed_assertions += 1
	else:
		var detail := message if message != "" else "Expected value < threshold"
		failures.append("%s (actual=%0.4f >= threshold=%0.4f)" % [detail, actual, threshold])
