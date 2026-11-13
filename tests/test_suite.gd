extends RefCounted
## Base class for the test suites in tests/suites/. Every method whose name starts with `test_`
## is run in declaration order; before_each() runs before each of them.
##
## Tests run inside the game (so the autoloads exist) but in a sandbox profile: nothing here can
## touch a real save file or settings.

var checks := 0
var failures := 0
var current_test := ""


func before_each() -> void:
	pass


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("  FAIL %s: %s" % [current_test, message])


func equal(actual: Variant, expected: Variant, message: String) -> void:
	check(typeof(actual) == typeof(expected) and actual == expected,
		"%s (expected %s, got %s)" % [message, str(expected), str(actual)])


func approx(actual: float, expected: float, message: String) -> void:
	check(is_equal_approx(actual, expected), "%s (expected %s, got %s)" % [message, expected, actual])


## Start every Run-related test from the same blank, AI-less run.
func fresh_run(seed_value := 1) -> void:
	Settings.ai_enabled = false
	SaveData.reset()
	Run.new_run(seed_value)
