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
	_test_corrupt_save_recovery()
	_test_incomplete_save_recovery()
	_test_pause_resume_persistence()
	_test_invalid_save_types_recovery()
	_test_wrong_region_array_lengths()
	_test_partial_corruption_recovery()
	_test_numeric_bounds()
	_test_missing_individual_fields()
	_test_invalid_timer_and_selected_region()
	_test_empty_object_recovery()
	_test_save_again_after_recovery()
	_test_valid_save_full_round_trip()
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
	_check(game.influence[2] == 12.0 and game.resilience[4] == 48.0, "Valid version-1 regional progress must load without modification.")
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


func _test_corrupt_save_recovery() -> void:
	var file := FileAccess.open("user://campaign_save.json", FileAccess.WRITE)
	_check(file != null, "Test must be able to write a corrupted save.")
	if file == null:
		return
	file.store_string("{ definitely not valid JSON")
	file.close()
	var game = GAME_SCRIPT.new()
	game.research = 999
	game.day = 88
	game.influence = [99.0, 99.0, 99.0, 99.0, 99.0, 99.0]
	game._load_game()
	_check(game.research == 20 and game.day == 1, "Corrupted JSON must restore safe initial research and day.")
	_check(game.influence[0] == 8.0 and game.resilience[5] == 18.0, "Corrupted JSON must restore safe regional defaults.")
	_check(game.upgrades.size() == 4 and not game.upgrades.any(func(value): return value), "Corrupted JSON must clear all upgrades.")
	_check(not game.ended and game.selected_region == 2, "Corrupted JSON must restore a running campaign at the default region.")
	_check(_saved_file_is_valid_v1(), "Corrupted save must be replaced by a valid version-1 save.")
	game.free()
	_cleanup_test_save()

func _test_incomplete_save_recovery() -> void:
	var incomplete := {"version": 1, "research": 74, "day": 12, "influence": [1.0, 2.0]}
	var file := FileAccess.open("user://campaign_save.json", FileAccess.WRITE)
	_check(file != null, "Test must be able to write an incomplete save.")
	if file == null:
		return
	file.store_string(JSON.stringify(incomplete))
	file.close()
	var game = GAME_SCRIPT.new()
	game.research = 777
	game.day = 55
	game._load_game()
	_check(game.research == 20 and game.day == 1, "Incomplete version-1 save must not partially apply stale progress.")
	_check(game.influence.size() == 6 and game.resilience.size() == 6, "Incomplete save must restore all six regional entries.")
	_check(game.upgrades.size() == 4 and not game.upgrades.any(func(value): return value), "Incomplete save must reset upgrade ownership safely.")
	_check(_saved_file_is_valid_v1(), "Incomplete save must be replaced by a complete valid version-1 save.")
	game.free()
	_cleanup_test_save()

func _test_pause_resume_persistence() -> void:
	var game = GAME_SCRIPT.new()
	game.research = 53
	game.day = 27
	game.selected_region = 3
	game.influence = [15.0, 16.0, 17.0, 18.0, 19.0, 20.0]
	game.resilience = [40.0, 41.0, 42.0, 43.0, 44.0, 45.0]
	game.upgrades = [true, false, true, false]
	game.event_text = "Background persistence test"
	game._notification(game.NOTIFICATION_APPLICATION_PAUSED)
	_check(_saved_file_is_valid_v1(), "Application pause notification must write a valid version-1 save.")
	game.research = 1
	game.day = 2
	game.influence[3] = 1.0
	game.upgrades = [false, false, false, false]
	game._notification(game.NOTIFICATION_APPLICATION_RESUMED)
	_check(game.research == 53 and game.day == 27, "Application resume must restore persisted research and day.")
	_check(game.influence[3] == 18.0 and game.resilience[5] == 45.0, "Application resume must restore regional values.")
	_check(game.selected_region == 3 and game.upgrades[0] and game.upgrades[2], "Application resume must restore selected region and purchased upgrades.")
	_check(game.event_text == "Background persistence test", "Application resume must restore the saved event text.")
	game.free()
	_cleanup_test_save()

func _valid_test_save() -> Dictionary:
	return {
		"version": 1,
		"influence": [8.0, 4.0, 12.0, 3.0, 10.0, 2.0],
		"resilience": [38.0, 25.0, 44.0, 20.0, 48.0, 18.0],
		"research": 37,
		"day": 9,
		"selected_region": 4,
		"upgrades": [true, false, true, false],
		"event_text": "Save validation test",
		"ended": false,
		"event_timer": 1.25,
		"log_lines": ["DAY 009  •  Save validation test"]
	}

func _write_test_save(data: Dictionary) -> void:
	var file := FileAccess.open("user://campaign_save.json", FileAccess.WRITE)
	_check(file != null, "Test must be able to write a save fixture.")
	if file == null:
		return
	file.store_string(JSON.stringify(data))
	file.close()

func _assert_invalid_save_recovery(data: Dictionary, label: String) -> void:
	_write_test_save(data)
	var game = GAME_SCRIPT.new()
	game.research = 999
	game.day = 99
	game._load_game()
	_check(game.research == 20 and game.day == 1, label + " must reset progress instead of applying partial values.")
	_check(game.influence.size() == 6 and game.resilience.size() == 6, label + " must restore six valid regions.")
	_check(game.influence[0] == 8.0 and game.resilience[5] == 18.0, label + " must restore safe regional defaults.")
	_check(game.upgrades.size() == 4 and not game.upgrades.any(func(value): return value), label + " must clear invalid upgrade state.")
	_check(_saved_file_is_valid_v1(), label + " must be replaced with a complete version-1 save.")
	game.free()
	_cleanup_test_save()

func _test_invalid_save_types_recovery() -> void:
	var bad := _valid_test_save()
	bad["research"] = "thirty-seven"
	_assert_invalid_save_recovery(bad, "String research value")

	bad = _valid_test_save()
	bad["influence"] = [8.0, 4.0, "damaged", 3.0, 10.0, 2.0]
	_assert_invalid_save_recovery(bad, "String influence entry")

	bad = _valid_test_save()
	bad["resilience"] = [38.0, 25.0, 44.0, false, 48.0, 18.0]
	_assert_invalid_save_recovery(bad, "Boolean resilience entry")

	bad = _valid_test_save()
	bad["upgrades"] = [true, 1, false, false]
	_assert_invalid_save_recovery(bad, "Non-Boolean upgrade entry")

	bad = _valid_test_save()
	bad["ended"] = "false"
	_assert_invalid_save_recovery(bad, "String ended flag")

	bad = _valid_test_save()
	bad["event_text"] = 123
	_assert_invalid_save_recovery(bad, "Numeric event text")

	bad = _valid_test_save()
	bad["log_lines"] = ["valid line", 7]
	_assert_invalid_save_recovery(bad, "Non-string campaign log")

	bad = _valid_test_save()
	bad["version"] = 2
	_assert_invalid_save_recovery(bad, "Unsupported save version")

func _test_wrong_region_array_lengths() -> void:
	var bad := _valid_test_save()
	bad["influence"] = [8.0, 4.0]
	_assert_invalid_save_recovery(bad, "Short influence array")

	bad = _valid_test_save()
	bad["resilience"] = [38.0, 25.0, 44.0, 20.0, 48.0, 18.0, 50.0]
	_assert_invalid_save_recovery(bad, "Oversized resilience array")

	bad = _valid_test_save()
	bad["upgrades"] = [true, false]
	_assert_invalid_save_recovery(bad, "Short upgrades array")

func _test_partial_corruption_recovery() -> void:
	var bad := _valid_test_save()
	bad["day"] = 77
	bad["research"] = 123
	bad["resilience"] = [38.0, 25.0, "corrupt", 20.0, 48.0, 18.0]
	_assert_invalid_save_recovery(bad, "Partially corrupted save")

func _test_numeric_bounds() -> void:
	var bounded := _valid_test_save()
	bounded["influence"] = [-50.0, 1e30, 12.0, 3.0, 10.0, 2.0]
	bounded["resilience"] = [-50.0, 1e30, 44.0, 20.0, 48.0, 18.0]
	bounded["research"] = -999
	bounded["day"] = 1e30
	bounded["selected_region"] = -99
	bounded["event_timer"] = 99.0
	_write_test_save(bounded)
	var game = GAME_SCRIPT.new()
	game._load_game()
	_check(game.influence[0] == 0.0 and game.influence[1] == 100.0, "Negative and oversized influence must be clamped to 0..100.")
	_check(game.resilience[0] == 0.0 and game.resilience[1] == 95.0, "Negative and oversized resilience must be clamped to 0..95.")
	_check(game.research == 0, "Negative research must be clamped to zero.")
	_check(game.day == 1000000, "Oversized day must be clamped to the supported upper bound.")
	_check(game.selected_region == 0, "Negative selected region must be clamped to the first region.")
	_check(game.event_timer == 4.0, "Oversized event timer must be clamped to four seconds.")
	game.free()
	_cleanup_test_save()

func _test_missing_individual_fields() -> void:
	for field in ["version", "influence", "resilience", "research", "day", "selected_region", "upgrades", "event_text", "ended", "event_timer", "log_lines"]:
		var bad := _valid_test_save()
		bad.erase(field)
		_assert_invalid_save_recovery(bad, "Save missing field " + field)

func _test_invalid_timer_and_selected_region() -> void:
	var bad := _valid_test_save()
	bad["event_timer"] = "not-a-number"
	_assert_invalid_save_recovery(bad, "String event_timer")

	bad = _valid_test_save()
	bad["selected_region"] = "Asia"
	_assert_invalid_save_recovery(bad, "String selected_region")

	bad = _valid_test_save()
	bad["event_timer"] = -1.0
	_write_test_save(bad)
	var game = GAME_SCRIPT.new()
	game._load_game()
	_check(game.event_timer == 0.0, "Negative event_timer must be clamped to zero.")
	game.free()
	_cleanup_test_save()

func _test_empty_object_recovery() -> void:
	_assert_invalid_save_recovery({}, "Empty JSON object")

func _test_save_again_after_recovery() -> void:
	var bad := _valid_test_save()
	bad["selected_region"] = "damaged"
	_write_test_save(bad)
	var recovered = GAME_SCRIPT.new()
	recovered._load_game()
	_check(recovered.day == 1 and recovered.research == 20, "Recovery must discard all progress from a partially damaged save.")
	recovered._save_game()
	_check(_saved_file_is_valid_v1(), "Saving immediately after recovery must produce a complete version-1 save.")
	var relaunched = GAME_SCRIPT.new()
	relaunched._load_game()
	_check(relaunched.day == 1 and relaunched.research == 20 and relaunched.selected_region == 2, "A second load must preserve the recovered default campaign.")
	_check(relaunched.influence[0] == 8.0 and relaunched.resilience[5] == 18.0, "A second load must retain safe default region values.")
	recovered.free()
	relaunched.free()
	_cleanup_test_save()

func _test_valid_save_full_round_trip() -> void:
	_write_test_save(_valid_test_save())
	var game = GAME_SCRIPT.new()
	game._load_game()
	_check(game.day == 9 and game.research == 37, "Valid version-1 save must preserve day and research exactly.")
	_check(game.selected_region == 4 and game.upgrades[0] and game.upgrades[2], "Valid version-1 save must preserve selected region and upgrades.")
	_check(game.influence[2] == 12.0 and game.resilience[4] == 48.0, "Valid version-1 save must preserve all region values exactly.")
	_check(game.event_text == "Save validation test" and game.event_timer == 1.25, "Valid version-1 save must preserve event text and timer.")
	_check(game.log_lines.size() == 1 and game.log_lines[0] == "DAY 009  •  Save validation test", "Valid version-1 save must preserve campaign log.")
	game._save_game()
	var relaunched = GAME_SCRIPT.new()
	relaunched._load_game()
	_check(relaunched.day == 9 and relaunched.research == 37 and relaunched.selected_region == 4, "Saving and reloading valid version-1 data must preserve progress.")
	_check(relaunched.event_timer == 1.25 and relaunched.event_text == "Save validation test", "Saving and reloading must preserve event state.")
	game.free()
	relaunched.free()
	_cleanup_test_save()

func _saved_file_is_valid_v1() -> bool:
	var file := FileAccess.open("user://campaign_save.json", FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed is Dictionary and int(parsed.get("version", 0)) == 1 and (parsed.get("influence", []) as Array).size() == 6 and (parsed.get("resilience", []) as Array).size() == 6 and (parsed.get("upgrades", []) as Array).size() == 4
