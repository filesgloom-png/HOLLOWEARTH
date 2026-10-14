extends SceneTree

const GAME_SCRIPT = preload("res://scripts/main.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	_test_region_specializations()
	_test_containment_specialization()
	_test_legacy_save_compatibility()
	if failures > 0:
		push_error("HOLLOWEARTH campaign tests failed: %d" % failures)
		quit(1)
	else:
		print("HOLLOWEARTH campaign tests passed: six regional effects, containment, and version-1 save compatibility.")
		quit(0)

func _test_region_specializations() -> void:
	var game = GAME_SCRIPT.new()
	_check(game.REGION_NAMES.size() == 6, "There must be six regions.")
	_check(game.REGION_SPECIALIZATIONS.size() == 6, "Every region must have a specialization.")
	_check(game.REGION_SPECIALIZATION_EFFECTS.size() == 6, "Every region must describe its effect.")
	game.influence = [8.0, 4.0, 12.0, 3.0, 10.0, 2.0]
	game.resilience = [38.0, 25.0, 44.0, 20.0, 48.0, 18.0]
	game.research = 20
	game.day = 1
	game.upgrades = [false, false, false, false]
	game.log_lines.clear()
	var south_before: float = game.influence[1]
	var asia_before: float = game.influence[4]
	var africa_resilience_before: float = game.resilience[3]
	game._advance_day()
	_check(game.day == 2, "Daily simulation must advance the campaign day.")
	_check(game.research == 24, "North America research hub must grant +1 RP on even days alongside the +3 daily RP.")
	var south_expected: float = south_before + (0.7 * 0.8) * (1.0 - 25.0 / 180.0)
	_check(absf(game.influence[1] - south_expected) < 0.001, "South America must reduce influence growth by 20%.")
	var asia_expected: float = asia_before + (0.7 + 0.30) * (1.0 - 48.0 / 180.0)
	_check(absf(game.influence[4] - asia_expected) < 0.001, "Asia must add 0.30 to daily influence growth.")
	var africa_expected: float = africa_resilience_before + 0.22 + game.influence[3] * 0.012 + 0.45
	_check(absf(game.resilience[3] - africa_expected) < 0.001, "Africa must add 0.45 daily resilience.")
	game.day = 4
	game.research = 100
	game.event_text = "test"
	game._advance_day()
	_check(game.day == 5, "The five-day research check must advance to day five.")
	_check(game.research >= 105, "Europe open science must grant +2 RP on day five, in addition to daily research.")
	game.free()

func _test_containment_specialization() -> void:
	var game = GAME_SCRIPT.new()
	game.influence = [8.0, 4.0, 12.0, 3.0, 10.0, 20.0]
	game.resilience = [38.0, 25.0, 44.0, 20.0, 48.0, 18.0]
	game.research = 8
	game.selected_region = 5
	game.log_lines.clear()
	game._stabilize_region()
	_check(game.research == 0, "Containment must consume the established 8 RP cost.")
	_check(absf(game.resilience[5] - 36.0) < 0.001, "Oceania containment grid must add 18 resilience.")
	_check(absf(game.influence[5] - 17.0) < 0.001, "Containment must reduce selected-region influence by 3.")
	game.free()

func _test_legacy_save_compatibility() -> void:
	var legacy_save := {
		"version": 1,
		"influence": [8.0, 4.0, 12.0, 3.0, 10.0, 2.0],
		"resilience": [38.0, 25.0, 44.0, 20.0, 48.0, 18.0],
		"research": 37,
		"day": 9,
		"selected_region": 4,
		"upgrades": [true, false, true, false],
		"event_text": "Legacy save test",
		"ended": false,
		"event_timer": 1.25,
		"log_lines": ["DAY 009  •  Legacy save test"]
	}
	var file := FileAccess.open("user://campaign_save.json", FileAccess.WRITE)
	_check(file != null, "Test must be able to create a version-1 save.")
	if file == null:
		return
	file.store_string(JSON.stringify(legacy_save))
	file.close()
	var game = GAME_SCRIPT.new()
	game._load_game()
	_check(game.day == 9, "Version-1 save day must load.")
	_check(game.research == 37, "Version-1 save research must load.")
	_check(game.selected_region == 4, "Version-1 selected region must load.")
	_check(game.upgrades.size() == 4 and game.upgrades[0] and game.upgrades[2], "Version-1 upgrades must load unchanged.")
	_check(game.influence.size() == 6 and game.resilience.size() == 6, "Version-1 regional arrays must remain compatible.")
	game._save_game()
	var saved_file := FileAccess.open("user://campaign_save.json", FileAccess.READ)
	_check(saved_file != null, "Saving after legacy load must create a readable save.")
	if saved_file != null:
		var parsed: Variant = JSON.parse_string(saved_file.get_as_text())
		saved_file.close()
		_check(parsed is Dictionary, "Saved campaign must remain valid JSON.")
		if parsed is Dictionary:
			_check(int(parsed.get("version", 0)) == 1, "Existing save version must remain unchanged.")
			_check((parsed.get("influence", []) as Array).size() == 6, "Saved influence array must retain six regions.")
	game.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://campaign_save.json"))

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("TEST FAILED: " + message)
