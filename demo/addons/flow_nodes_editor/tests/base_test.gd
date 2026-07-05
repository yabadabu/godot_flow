@tool
class_name BaseTest
extends RefCounted

var _failures: Array[String] = []

func assert_eq(actual, expected, message := "") -> void:
	if actual != expected:
		_failures.append("Expected '%s' but got '%s'. %s" % [expected, actual, message])

func assert_approx_eq(actual, expected, diff, message := "") -> void:
	if absf( actual - expected ) > diff:
		_failures.append("Expected '%s' but got '%s'. %s" % [expected, actual, message])

func assert_true(condition: bool, message := "") -> void:
	if not condition:
		_failures.append("Expected true. %s" % message)

func assert_false(condition: bool, message := "") -> void:
	if condition:
		_failures.append("Expected false. %s" % message)

func assert_null(value, message := "") -> void:
	if value != null:
		_failures.append("Expected null but got '%s'. %s" % [value, message])

func get_failures() -> Array[String]:
	return _failures
