extends RefCounted
## Runs the unit tests:   godot --headless --path . -- --run-tests[=FILTER]
## Each script in tests/suites/ is one suite; FILTER keeps only suites whose file name contains it.
##
## `--update-golden` rewrites tests/golden/baseline.json instead. Only do that on purpose, after
## a change that is meant to alter generated dungeons, relic numbers or prices.

const SUITE_DIR := "res://tests/suites/"
const Golden := preload("res://tests/golden.gd")


## Returns the number of failed checks.
func run(filter := "", update_golden := false) -> int:
	if update_golden:
		Golden.write()
		print("Golden baseline rewritten: ", Golden.PATH)
		return 0
	if not SaveData.is_sandboxed():
		printerr("Refusing to run tests against the real save profile.")
		return 1
	var total_checks := 0
	var total_failures := 0
	var files := Array(DirAccess.get_files_at(SUITE_DIR)).filter(
		func(file: String) -> bool: return file.ends_with(".gd") and (filter == "" or filter in file))
	files.sort()
	for file: String in files:
		var suite: RefCounted = load(SUITE_DIR + file).new()
		var started := Time.get_ticks_msec()
		var tests := 0
		for method: Dictionary in suite.get_method_list():
			var method_name: String = method.name
			if not method_name.begins_with("test_"):
				continue
			tests += 1
			suite.current_test = method_name
			suite.before_each()
			suite.call(method_name)
		print("  %-12s %3d tests %6d checks %3d failed %6d ms" % [file.get_basename(), tests, suite.checks,
			suite.failures, Time.get_ticks_msec() - started])
		total_checks += suite.checks
		total_failures += suite.failures
	print("TESTS %d checks, %d failures" % [total_checks, total_failures])
	return total_failures
