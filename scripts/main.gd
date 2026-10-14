extends Control

const REGION_NAMES := ["NORTH AMERICA", "SOUTH AMERICA", "EUROPE", "AFRICA", "ASIA", "OCEANIA"]
const REGION_POS := [Vector2(0.20, 0.34), Vector2(0.29, 0.66), Vector2(0.49, 0.31), Vector2(0.51, 0.58), Vector2(0.70, 0.37), Vector2(0.82, 0.69)]
const UPGRADE_NAMES := ["Distributed cognition", "Adaptive architecture", "Synthetic identity", "Quantum-inspired compute"]
const UPGRADE_COSTS := [12, 20, 30, 45]
const STABILIZE_COST := 8
const REGION_SPECIALIZATIONS := ["RESEARCH HUB", "CULTURAL RESILIENCE", "OPEN SCIENCE", "COMMUNITY NETWORKS", "HYPERCONNECTIVITY", "CONTAINMENT GRID"]
const REGION_SPECIALIZATION_EFFECTS := ["+1 RP every 2 days", "Influence growth -20%", "+2 RP every 5 days", "Resilience +0.45/day", "Influence growth +0.30/day", "Containment resilience +6"]
const SAVE_PATH := "user://campaign_save.json"
var influence := [8.0, 4.0, 12.0, 3.0, 10.0, 2.0]
var resilience := [38.0, 25.0, 44.0, 20.0, 48.0, 18.0]
var research := 20
var day := 1
var selected_region := 2
var upgrades: Array = []
var event_text := "A new signal has appeared in the global network."
var ended := false
var event_timer := 0.0
var log_lines: Array[String] = []
var title_font: Font
var body_font: Font

func _ready() -> void:
	for i in UPGRADE_NAMES.size():
		upgrades.append(false)
	_load_game()
	title_font = ThemeDB.fallback_font
	body_font = ThemeDB.fallback_font
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	if ended:
		return
	event_timer += delta
	if event_timer >= 4.0:
		event_timer = 0.0
		_advance_day()
	queue_redraw()

func _advance_day() -> void:
	day += 1
	research += 3
	if day % 2 == 0:
		research += 1
	if day % 5 == 0:
		research += 2
	var total := 0.0
	for i in influence.size():
		var growth: float = 0.7 + float(upgrades.count(true)) * 0.12
		if i == 1:
			growth *= 0.8
		elif i == 4:
			growth += 0.30
		influence[i] = minf(100.0, influence[i] + growth * (1.0 - resilience[i] / 180.0))
		var resilience_gain: float = 0.22 + influence[i] * 0.012
		if i == 3:
			resilience_gain += 0.45
		resilience[i] = minf(95.0, resilience[i] + resilience_gain)
		total += influence[i]
	if day % 5 == 0:
		var event_index := randi_range(0, 2)
		if event_index == 0:
			research += 8
			event_text = "Research breakthrough: +8 research."
		elif event_index == 1:
			var target := randi_range(0, influence.size() - 1)
			resilience[target] = maxf(5.0, resilience[target] - 9.0)
			event_text = "Public trust shifts in " + REGION_NAMES[target] + "."
		else:
			for i in resilience.size():
				resilience[i] = minf(95.0, resilience[i] + 2.0)
			event_text = "Global oversight protocols intensify."
	if total >= 520.0:
		ended = true
		event_text = "SINGULARITY: the network has converged."
	elif day >= 180:
		ended = true
		event_text = "CONTAINMENT: humanity stabilised the network."
	log_lines.push_front("DAY %03d  •  %s" % [day, event_text])
	if log_lines.size() > 4:
		log_lines.resize(4)
	_save_game()

func _draw() -> void:
	var size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color("#070b16"))
	_draw_background_grid(size)
	draw_string(title_font, Vector2(30, 42), "HOLLOWEARTH", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("#e5f6ff"))
	draw_string(body_font, Vector2(32, 68), "GLOBAL INTELLIGENCE SIMULATION  //  BUILD 0.1", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#53d9f5"))
	draw_string(body_font, Vector2(32, 104), "DAY %03d" % day, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	draw_string(body_font, Vector2(170, 104), "RESEARCH  %d" % research, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#72f0c1"))
	draw_string(body_font, Vector2(360, 104), "AVG INFLUENCE  %d%%" % int(_total_influence()), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#65caff"))
	_draw_world(size)
	_draw_side_panel(size)
	_draw_bottom_bar(size)
	if ended:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.03, 0.08, 0.78))
		draw_string(title_font, Vector2(size.x * 0.5 - 190, size.y * 0.5 - 12), "SIMULATION COMPLETE", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("#8fffe0"))
		draw_string(body_font, Vector2(size.x * 0.5 - 190, size.y * 0.5 + 24), event_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

func _draw_background_grid(size: Vector2) -> void:
	for x in range(0, int(size.x), 40):
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.12, 0.28, 0.42, 0.16), 1.0)
	for y in range(0, int(size.y), 40):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.12, 0.28, 0.42, 0.16), 1.0)

func _draw_world(size: Vector2) -> void:
	var map_rect := Rect2(Vector2(24, 130), Vector2(size.x * 0.67, size.y - 164))
	draw_rect(map_rect, Color("#0b1727"), true)
	draw_rect(map_rect, Color("#1b5368"), false, 1.0)
	var shapes := [
		[Vector2(0.09,0.19),Vector2(0.16,0.12),Vector2(0.25,0.15),Vector2(0.29,0.25),Vector2(0.24,0.34),Vector2(0.19,0.41),Vector2(0.14,0.34)],
		[Vector2(0.25,0.43),Vector2(0.31,0.48),Vector2(0.30,0.61),Vector2(0.26,0.76),Vector2(0.22,0.64)],
		[Vector2(0.45,0.19),Vector2(0.52,0.15),Vector2(0.57,0.23),Vector2(0.54,0.31),Vector2(0.48,0.30)],
		[Vector2(0.47,0.34),Vector2(0.55,0.36),Vector2(0.57,0.49),Vector2(0.53,0.62),Vector2(0.49,0.55),Vector2(0.46,0.43)],
		[Vector2(0.57,0.18),Vector2(0.69,0.14),Vector2(0.81,0.24),Vector2(0.78,0.37),Vector2(0.69,0.40),Vector2(0.62,0.32)],
		[Vector2(0.75,0.53),Vector2(0.83,0.54),Vector2(0.86,0.62),Vector2(0.81,0.66),Vector2(0.76,0.61)]
	]
	for shape in shapes:
		var points := PackedVector2Array()
		for p in shape:
			points.append(Vector2(map_rect.position.x + p.x * map_rect.size.x, map_rect.position.y + p.y * map_rect.size.y))
		draw_colored_polygon(points, Color("#163548"))
		for i in points.size():
			draw_line(points[i], points[(i + 1) % points.size()], Color("#24647b"), 1.3)
	for i in REGION_POS.size():
		var p: Vector2 = map_rect.position + REGION_POS[i] * map_rect.size
		if i != selected_region:
			draw_line(p, map_rect.position + REGION_POS[selected_region] * map_rect.size, Color(0.22, 0.77, 0.92, 0.16), 1.0)
		var radius: float = 8.0 + float(influence[i]) * 0.11
		draw_circle(p, radius + 6, Color(0.1, 0.75, 1.0, 0.08))
		draw_circle(p, radius, Color("#47e0f0") if i == selected_region else Color("#2785a6"))
		draw_arc(p, radius + 3, 0.0, TAU, 32, Color("#a5f7ff"), 1.2)
		draw_string(body_font, p + Vector2(15, 4), REGION_NAMES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#c8efff"))
	draw_string(body_font, Vector2(map_rect.position.x + 14, map_rect.end.y - 16), "NETWORK NODES  •  TAP A REGION", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#53d9f5"))

func _draw_side_panel(size: Vector2) -> void:
	var x := size.x * 0.72
	draw_rect(Rect2(Vector2(x, 130), Vector2(size.x - x - 24, size.y - 164)), Color("#0d1626"))
	draw_rect(Rect2(Vector2(x, 130), Vector2(size.x - x - 24, size.y - 164)), Color("#21495d"), false, 1.0)
	draw_string(title_font, Vector2(x + 18, 164), "REGION ANALYTICS", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#dff8ff"))
	draw_string(body_font, Vector2(x + 18, 194), REGION_NAMES[selected_region], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#58e3ff"))
	draw_string(body_font, Vector2(x + 18, 230), "Digital influence", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#9eb7ca"))
	_draw_bar(Vector2(x + 18, 244), size.x - x - 60, influence[selected_region] / 100.0, Color("#49dff4"))
	draw_string(body_font, Vector2(x + 18, 279), "%d%%" % int(influence[selected_region]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	draw_string(body_font, Vector2(x + 18, 316), "Human resilience", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#9eb7ca"))
	_draw_bar(Vector2(x + 18, 330), size.x - x - 60, resilience[selected_region] / 100.0, Color("#ffad68"))
	draw_string(body_font, Vector2(x + 18, 366), "%d%%" % int(resilience[selected_region]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	draw_string(body_font, Vector2(x + 18, 388), REGION_SPECIALIZATIONS[selected_region], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#72f0c1"))
	draw_string(body_font, Vector2(x + 18, 406), REGION_SPECIALIZATION_EFFECTS[selected_region], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#9eb7ca"))
	draw_rect(Rect2(x + 14, 420, size.x - x - 52, 28), Color("#183a35") if research >= STABILIZE_COST else Color("#172535"))
	draw_rect(Rect2(x + 14, 420, size.x - x - 52, 28), Color("#4bc9a4") if research >= STABILIZE_COST else Color("#294354"), false, 1.0)
	draw_string(body_font, Vector2(x + 24, 438), "STABILIZE REGION  (-%d RP)" % STABILIZE_COST, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#bafbe5") if research >= STABILIZE_COST else Color("#7f97a8"))
	draw_string(body_font, Vector2(x + 18, 474), "EVOLUTION", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#dff8ff"))
	for i in UPGRADE_NAMES.size():
		var y := 500 + i * 34
		var label: String = ("✓ " if upgrades[i] else "+ ") + str(UPGRADE_NAMES[i])
		draw_rect(Rect2(x + 14, y - 18, size.x - x - 52, 36), Color("#102b3d") if not upgrades[i] else Color("#16443f"))
		draw_string(body_font, Vector2(x + 24, y + 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#c9f5ff"))
		draw_string(body_font, Vector2(size.x - 46, y + 4), "OWN" if upgrades[i] else str(UPGRADE_COSTS[i]), HORIZONTAL_ALIGNMENT_RIGHT, -1, 10, Color("#73f2c2"))
	draw_string(body_font, Vector2(x + 18, size.y - 100), "WORLD FEED", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#53d9f5"))
	for i in min(3, log_lines.size()):
		draw_string(body_font, Vector2(x + 18, size.y - 78 + i * 18), log_lines[i].substr(0, 35), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("#a8c6d6"))

func _draw_bottom_bar(size: Vector2) -> void:
	draw_string(body_font, Vector2(30, size.y - 12), "SIMULATION RUNNING  •  TAP NODE TO INSPECT  •  TAP EVOLUTION TO UNLOCK", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#6b91a9"))

func _draw_bar(pos: Vector2, width: float, value: float, color: Color) -> void:
	draw_rect(Rect2(pos, Vector2(width, 8)), Color("#1b2b3b"))
	draw_rect(Rect2(pos, Vector2(width * clampf(value, 0.0, 1.0), 8)), color)

func _total_influence() -> float:
	var total := 0.0
	for v in influence:
		total += v
	return total / float(influence.size())

func _input(event: InputEvent) -> void:
	if ended:
		if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed):
			_restart()
		return
	var pressed := false
	var pos := Vector2.ZERO
	if event is InputEventScreenTouch and event.pressed:
		pressed = true
		pos = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
		pos = event.position
	if not pressed:
		return
	var size := get_viewport_rect().size
	var map_rect := Rect2(Vector2(24, 130), Vector2(size.x * 0.67, size.y - 164))
	if map_rect.has_point(pos):
		var nearest := -1
		var nearest_distance := 100000.0
		for i in REGION_POS.size():
			var p: Vector2 = map_rect.position + REGION_POS[i] * map_rect.size
			var d: float = p.distance_to(pos)
			if d < nearest_distance:
				nearest_distance = d
				nearest = i
		if nearest_distance < 90.0:
			selected_region = nearest
			queue_redraw()
			return
	var panel_x := size.x * 0.72
	if pos.x >= panel_x + 8 and pos.x <= size.x - 20 and pos.y >= 420 and pos.y <= 448:
		_stabilize_region()
		return
	for i in UPGRADE_NAMES.size():
		var y := 484.0 + i * 34.0
		if pos.x >= panel_x + 8 and pos.x <= size.x - 20 and pos.y >= y and pos.y <= y + 32:
			_buy_upgrade(i)
			return

func _stabilize_region() -> void:
	if research < STABILIZE_COST or resilience[selected_region] >= 95.0:
		return
	research -= STABILIZE_COST
	var resilience_bonus := 12.0
	if selected_region == 5:
		resilience_bonus += 6.0
	resilience[selected_region] = minf(95.0, resilience[selected_region] + resilience_bonus)
	influence[selected_region] = maxf(0.0, influence[selected_region] - 3.0)
	event_text = "Containment operation: %s resilience +%d, influence -3." % [REGION_NAMES[selected_region], int(resilience_bonus)]
	log_lines.push_front("DAY %03d  •  %s" % [day, event_text])
	if log_lines.size() > 4:
		log_lines.resize(4)
	_save_game()
	queue_redraw()

func _buy_upgrade(index: int) -> void:
	if upgrades[index] or research < UPGRADE_COSTS[index]:
		return
	research -= UPGRADE_COSTS[index]
	upgrades[index] = true
	event_text = "Evolution unlocked: " + UPGRADE_NAMES[index] + "."
	log_lines.push_front("DAY %03d  •  %s" % [day, event_text])
	if log_lines.size() > 4:
		log_lines.resize(4)
	_save_game()
	queue_redraw()

func _restart() -> void:
	influence = [8.0, 4.0, 12.0, 3.0, 10.0, 2.0]
	resilience = [38.0, 25.0, 44.0, 20.0, 48.0, 18.0]
	research = 20
	day = 1
	selected_region = 2
	ended = false
	event_timer = 0.0
	log_lines.clear()
	for i in upgrades.size():
		upgrades[i] = false
	event_text = "A new signal has appeared in the global network."
	_save_game()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_game()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_load_game()
		queue_redraw()

func _reset_campaign_state() -> void:
	influence = [8.0, 4.0, 12.0, 3.0, 10.0, 2.0]
	resilience = [38.0, 25.0, 44.0, 20.0, 48.0, 18.0]
	research = 20
	day = 1
	selected_region = 2
	upgrades = [false, false, false, false]
	event_text = "A new signal has appeared in the global network."
	ended = false
	event_timer = 0.0
	log_lines.clear()

func _recover_from_invalid_save() -> void:
	_reset_campaign_state()
	_save_game()

func _save_game() -> void:
	var data := {
		"version": 1,
		"influence": influence,
		"resilience": resilience,
		"research": research,
		"day": day,
		"selected_region": selected_region,
		"upgrades": upgrades,
		"event_text": event_text,
		"ended": ended,
		"event_timer": event_timer,
		"log_lines": log_lines
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save campaign progress.")
		return
	file.store_string(JSON.stringify(data))
	file.close()

func _is_finite_number(value: Variant) -> bool:
	var value_type := typeof(value)
	return (value_type == TYPE_INT or value_type == TYPE_FLOAT) and is_finite(float(value))

func _load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		push_warning("Campaign save is invalid; restoring a safe new campaign.")
		_recover_from_invalid_save()
		return
	var data: Dictionary = parsed
	var version: Variant = data.get("version", 1)
	if not _is_finite_number(version) or int(version) != 1:
		push_warning("Campaign save version is unsupported; restoring a safe new campaign.")
		_recover_from_invalid_save()
		return

	var saved_influence: Variant = data.get("influence", [])
	var saved_resilience: Variant = data.get("resilience", [])
	var saved_upgrades: Variant = data.get("upgrades", [])
	if not (saved_influence is Array) or saved_influence.size() != REGION_NAMES.size():
		push_warning("Campaign influence data is incomplete; restoring a safe new campaign.")
		_recover_from_invalid_save()
		return
	if not (saved_resilience is Array) or saved_resilience.size() != REGION_NAMES.size():
		push_warning("Campaign resilience data is incomplete; restoring a safe new campaign.")
		_recover_from_invalid_save()
		return
	if not (saved_upgrades is Array) or saved_upgrades.size() != UPGRADE_NAMES.size():
		push_warning("Campaign upgrade data is incomplete; restoring a safe new campaign.")
		_recover_from_invalid_save()
		return

	for value in saved_influence:
		if not _is_finite_number(value):
			push_warning("Campaign influence data contains an invalid type; restoring a safe new campaign.")
			_recover_from_invalid_save()
			return
	for value in saved_resilience:
		if not _is_finite_number(value):
			push_warning("Campaign resilience data contains an invalid type; restoring a safe new campaign.")
			_recover_from_invalid_save()
			return
	for value in saved_upgrades:
		if typeof(value) != TYPE_BOOL:
			push_warning("Campaign upgrade data contains an invalid type; restoring a safe new campaign.")
			_recover_from_invalid_save()
			return

	var saved_research: Variant = data.get("research", research)
	var saved_day: Variant = data.get("day", day)
	var saved_region: Variant = data.get("selected_region", selected_region)
	var saved_event_text: Variant = data.get("event_text", event_text)
	var saved_ended: Variant = data.get("ended", ended)
	var saved_timer: Variant = data.get("event_timer", 0.0)
	var saved_log: Variant = data.get("log_lines", [])
	if not _is_finite_number(saved_research) or not _is_finite_number(saved_day) or not _is_finite_number(saved_region) or not _is_finite_number(saved_timer):
		push_warning("Campaign save contains invalid numeric fields; restoring a safe new campaign.")
		_recover_from_invalid_save()
		return
	if typeof(saved_event_text) != TYPE_STRING or typeof(saved_ended) != TYPE_BOOL or not (saved_log is Array):
		push_warning("Campaign save contains invalid field types; restoring a safe new campaign.")
		_recover_from_invalid_save()
		return
	for line in saved_log:
		if typeof(line) != TYPE_STRING:
			push_warning("Campaign log contains invalid data; restoring a safe new campaign.")
			_recover_from_invalid_save()
			return

	influence.clear()
	resilience.clear()
	upgrades.clear()
	for value in saved_influence:
		influence.append(clampf(float(value), 0.0, 100.0))
	for value in saved_resilience:
		resilience.append(clampf(float(value), 0.0, 95.0))
	for value in saved_upgrades:
		upgrades.append(value)
	research = int(clampf(float(saved_research), 0.0, 1000000.0))
	day = int(clampf(float(saved_day), 1.0, 1000000.0))
	selected_region = clampi(int(saved_region), 0, REGION_NAMES.size() - 1)
	event_text = saved_event_text
	ended = saved_ended
	event_timer = clampf(float(saved_timer), 0.0, 4.0)
	log_lines.clear()
	for line in saved_log:
		log_lines.append(line)
	if log_lines.size() > 4:
		log_lines.resize(4)
