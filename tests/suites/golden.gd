extends "res://tests/test_suite.gd"
## Compares what the code computes now with tests/golden/baseline.json, which was written by the
## code before it was restructured. A failure here means behaviour changed, not just structure.

const Golden := preload("res://tests/golden.gd")

var _expected := {}
var _actual := {}


func _init() -> void:
	_expected = Golden.load_baseline()
	_actual = Golden.as_json(Golden.build())


func _section(section: String) -> void:
	check(_expected.has(section), "baseline has section " + section)
	var differences := Golden.diff(_actual.get(section), _expected.get(section))
	check(differences.is_empty(), "%s differs from baseline: %s" % [section, "; ".join(differences)])


func test_dungeon_layouts() -> void:
	equal(_expected.dungeon.size(), Depths.FINAL * Golden.DUNGEON_SEEDS, "layouts in baseline")
	_section("dungeon")


func test_relic_stats() -> void:
	_section("stats")


func test_wave_composition() -> void:
	_section("waves")


func test_relic_rolls() -> void:
	_section("rolls")


func test_haggle_clamp() -> void:
	_section("clamp")


func test_text_helpers() -> void:
	_section("wrap")
	_section("clean")
	_section("times")


func test_prices() -> void:
	_section("prices")


func test_depth_names() -> void:
	_section("titles")
	_section("biomes")
