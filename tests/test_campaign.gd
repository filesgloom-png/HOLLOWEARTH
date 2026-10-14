extends SceneTree

const GAME_SCRIPT = preload("res://scripts/main.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	_test_region_specializations()
	_test_containment_specialization()
	_test_legacy_save_compatibility()
	_test_app_relaunch_persistence()
	_test_upgrade_purchase_persistence()
	_test_completed_campaign_restore()
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


func _test_app_relaunch_persistence() -> void:
	var game = GAME_SCRIPT.new()
	game.influence = [18.0, 14.0, 22.0, 13.0, 20.0, 12.0]
	game.resilience = [48.0, 35.0, 54.0, 30.0, 58.0, 28.0]
	game.research = 67
	game.day = 42
	game.selected_region = 4
	game.upgrades = [true, false, true, false]
	game.event_text = "Relaunch persistence test"
	game.ended = false
	game.log_lines = ["DAY 042  •  Relaunch persistence test"]
	game._save_game()
	var relaunched = GAME_SCRIPT.new()
	relaunched._load_game()
	_check(relaunched.day == 42 and relaunched.research == 67, "A fresh app instance must restore day and research after relaunch.")
	_check(relaunched.selected_region == 4, "A fresh app instance must restore the selected region.")
	_check(relaunched.influence[0] == 18.0 and relaunched.resilience[4] == 58.0, "A fresh app instance must restore regional state.")
	_check(relaunched.upgrades[0] and relaunched.upgrades[2] and not relaunched.upgrades[1], "A fresh app instance must restore unlocked upgrades.")
	_check(relaunched.event_text == "Relaunch persistence test" and relaunched.log_lines.size() == 1, "A fresh app instance must restore event and log state.")
	relaunched._restart()
	var restarted = GAME_SCRIPT.new()
	restarted._load_game()
	_check(restarted.day == 1 and restarted.research == 20, "Restart must persist the new campaign's initial day and research.")
	_check(restarted.selected_region == 2 and not restarted.ended, "Restart must restore the default region and running state.")
	_check(restarted.upgrades.size() == 4 and not restarted.upgrades.any(func(value): return value), "Restart must clear all previously purchased upgrades.")
	_check(restarted.influence[0] == 8.0 and restarted.resilience[4] == 48.0, "Restart must persist default regional values.")
	game.free()
	relaunched.free()
	restarted.free()
	_cleanup_test_save()

func _test_upgrade_purchase_persistence() -> void:
	var game = GAME_SCRIPT.new()
	game.research = 100
	game.upgrades = [false, false, false, false]
	game.log_lines.clear()
	game._buy_upgrade(1)
	_check(game.research == 80, "Buying Adaptive architecture must deduct its 20 RP cost.")
	_check(game.upgrades[1], "Buying an upgrade must mark it as owned before saving.")
	var relaunched = GAME_SCRIPT.new()
	relaunched._load_game()
	_check(relaunched.research == 80, "Research balance after an upgrade purchase must survive relaunch.")
	_check(relaunched.upgrades[1], "Purchased upgrade ownership must survive relaunch.")
	_check(not relaunched.upgrades[0] and not relaunched.upgrades[2] and not relaunched.upgrades[3], "Unpurchased upgrades must remain locked after relaunch.")
	var saved_file := FileAccess.open("user://campaign_save.json", FileAccess.READ)
	if saved_file != null:
		var parsed: Variant = JSON.parse_string(saved_file.get_as_text())
		saved_file.close()
		_check(parsed is Dictionary and int(parsed.get("version", 0)) == 1, "Upgrade purchase must keep the version-1 save format.")
	else:
		_check(false, "Upgrade purchase must leave a readable save file.")
	game.free()
	relaunched.free()
	_cleanup_test_save()

func _test_completed_campaign_restore() -> void:
	var game = GAME_SCRIPT.new()
	game.influence = [99.0, 91.0, 92.0, 93.0, 94.0, 95.0]
	game.resilience = [80.0, 81.0, 82.0, 83.0, 84.0, 85.0]
	game.research = 211
	game.day = 180
	game.selected_region = 5
	game.upgrades = [true, true, false, true]
	game.ended = true
	game.event_text = "CONTAINMENT: humanity stabilised the network."
	game.log_lines = ["DAY 180  •  " + game.event_text]
	game._save_game()
	var relaunched = GAME_SCRIPT.new()
	relaunched._load_game()
	_check(relaunched.ended, "A completed campaign must remain completed after relaunch.")
	_check(relaunched.day == 180 and relaunched.selected_region == 5, "Completed campaign day and selected region must be restored.")
	_check(relaunched.event_text == "CONTAINMENT: humanity stabilised the network.", "The completed campaign result must be restored.")
	_check(relaunched.upgrades[0] and relaunched.upgrades[1] and relaunched.upgrades[3], "Completed campaign upgrade ownership must be restored.")
	_check(relaunched.influence[0] == 99.0 and relaunched.resilience[5] == 85.0, "Completed campaign regional values must be restored.")
	var saved_file := FileAccess.open("user://campaign_save.json", FileAccess.READ)
	if saved_file != null:
		var parsed: Variant = JSON.parse_string(saved_file.get_as_text())
		saved_file.close()
		_check(parsed is Dictionary and int(parsed.get("version", 0)) == 1, "Completed campaign save must remain version 1.")
	else:
		_check(false, "Completed campaign must have a readable save file.")
	game.free()
	relaunched.free()
	_cleanup_test_save()

func _cleanup_test_save() -> void:
	var path := ProjectSettings.globalize_path("user://campaign_save.json")
	if FileAccess.file_exists("user://campaign_save.json"):
		DirAccess.remove_absolute(path)
