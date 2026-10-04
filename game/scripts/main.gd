extends Node2D
## Moon Pendulum: a small, deterministic musical physics toy with a learning loop.
## Pendulum motion uses a fixed physics timestep; all art is original vector drawing.

const BUILD = preload("res://build_info.gd")
const FONT = preload("res://assets/fonts/MoonSans.ttf")
const BELL_ANGLES = [-0.96, -0.66, -0.34, 0.0, 0.34, 0.66, 0.96]
const NOTE_NAMES = ["D3", "A3", "D4", "E4", "F♯4", "A4", "D5"]
const CHAPTERS = [
	{"name": "I · はじめの光", "subtitle": "ひと振りから、夜が目を覚ます。", "targets": [0.55, -0.55, 0.82]},
	{"name": "II · 水面の三重奏", "subtitle": "小さな弧と、大きな弧を奏で分ける。", "targets": [-0.34, 0.68, -0.91, 0.48]},
	{"name": "III · 月へ帰る旋律", "subtitle": "五つの光をつないで、夜を満たそう。", "targets": [0.90, -0.64, 0.35, -0.82, 0.60]},
	{"name": "IV · 連鎖の回廊", "subtitle": "鐘で蓄えた力が、小さな月へ。", "targets": [-0.68, 0.80, -0.86, 0.72], "kind": "relay"},
	{"name": "V · 二つの月の対話", "subtitle": "ひと振りから、二つの光を奏でる。", "targets": [0.65, 0.77, 0.86], "kind": "duet"}
]
const GOLD = Color("ecd7a4")
const TEAL = Color("85d4c9")
const INK = Color("071b28")
const MUTED = Color("86a4af")
const WHITE = Color("e8efea")
const PHYSICS_RATE = 5.1
const DAMPING = 0.055
const MAX_PULL = 1.22
const HIT_TOLERANCE = 0.15

var size := Vector2.ZERO
var pivot := Vector2.ZERO
var length := 330.0
var theta := 0.0
var omega := 0.0
var dragging := false
var keyboard_aim := false
var web_document: JavaScriptObject
var visibility_callback: JavaScriptObject
var started := false
var muted := false
var paused := false
var swinging := false
var cast_crossed_center := false
var cast_judged := false
var cast_start_angle := 0.0
var cast_seconds := 0.0
var elapsed := 0.0
var chapter := 0
var progress := 0
var casts := 0
var perfects := 0
var chapter_done := false
var show_help := false
var target_pulse := 0.0
var finish_time := 0.0
var feedback := "光の輪へ、反対側から月を届かせよう。"
var feedback_timer := 0.0
var note_label := ""
var bell_glows: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var bell_cooldowns: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var particles: Array[Dictionary] = []
var light_flights: Array[Dictionary] = []
var ripples: Array[Dictionary] = []
var trail: Array[Vector2] = []
var stars: Array[Dictionary] = []
var players: Array[AudioStreamPlayer] = []
var sounds: Array[AudioStreamWAV] = []
var voice := 0
var start_rect := Rect2()
var retry_rect := Rect2()
var next_rect := Rect2()
var reset_rect := Rect2()
var mute_rect := Rect2()
var help_rect := Rect2()
var pause_rect := Rect2()
var stage_rect := Rect2()
var best_chapters: Array = [0, 0, 0, 0, 0]
var testing := false
var duet_hits: Array[bool] = [false, false]
var duet_checked: Array[bool] = [false, false]
var reduced_motion := false
var echoes: Array[Dictionary] = []
var chain_rings := 0
var harmonic_time := 0.0
var cadence_notes: Array[Dictionary] = []
var free_play := false
var tempo_index := 1
const TEMPOS = [0.80, 1.0, 1.22]
const TEMPO_NAMES = ["ゆっくり", "ふつう", "はやく"]

func _ready() -> void:
	Engine.max_fps = 60
	RenderingServer.set_default_clear_color(INK)
	var rng := RandomNumberGenerator.new()
	rng.seed = 81204
	for i in range(58):
		stars.append({"x": rng.randf(), "y": rng.randf(), "r": rng.randf_range(0.7, 1.8), "phase": rng.randf_range(0.0, TAU)})
	for i in range(7):
		sounds.append(load("res://assets/audio/bell_%d.wav" % i))
	for i in range(12):
		var player := AudioStreamPlayer.new()
		player.volume_db = -7.0
		add_child(player)
		players.append(player)
	_load_save()
	_layout()
	_reset_echoes()
	if OS.has_feature("web"):
		reduced_motion = bool(JavaScriptBridge.eval("window.matchMedia('(prefers-reduced-motion: reduce)').matches"))
		web_document = JavaScriptBridge.get_interface("document")
		visibility_callback = JavaScriptBridge.create_callback(_on_web_visibility_changed)
		web_document.addEventListener("visibilitychange", visibility_callback)
	get_viewport().size_changed.connect(_layout)
	_publish_state()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and started:
		_pause_for_focus_loss()

func _pause_for_focus_loss() -> void:
	paused = true
	dragging = false
	keyboard_aim = false
	_stop_audio()
	_publish_state()

func _on_web_visibility_changed(_arguments: Array) -> void:
	if started and web_document != null and bool(web_document.hidden):
		_pause_for_focus_loss()

func _exit_tree() -> void:
	if web_document != null and visibility_callback != null:
		web_document.removeEventListener("visibilitychange", visibility_callback)

func _layout() -> void:
	size = get_viewport_rect().size
	var portrait := size.y > size.x * 1.20
	length = minf(size.x * 0.43, (size.y - 325.0) * 0.72)
	pivot = Vector2(size.x * 0.5, 139.0)
	if portrait:
		var stage_top := 142.0
		var stage_bottom := size.y - 263.0
		var spare := maxf(0.0, stage_bottom - stage_top - length - 102.0)
		pivot.y = stage_top + spare * 0.60 + 32.0
	stage_rect = Rect2(24.0, 112.0, size.x - 48.0, size.y - 369.0)
	var bottom_y := size.y - 86.0
	var bw := minf(220.0, (size.x - 92.0) / 3.0)
	retry_rect = Rect2(size.x * 0.5 - bw - 8.0, bottom_y - 20.0, bw, 72.0)
	next_rect = Rect2(size.x * 0.5 + 8.0, bottom_y - 20.0, bw, 72.0)
	reset_rect = Rect2(28.0, 72.0, 100.0, 46.0)
	mute_rect = Rect2(size.x - 128.0, 20.0, 104.0, 66.0)
	help_rect = Rect2(size.x - 202.0, 20.0, 66.0, 66.0)
	pause_rect = Rect2(size.x - 276.0, 20.0, 66.0, 66.0)
	start_rect = Rect2(size.x * 0.5 - 156.0, size.y * 0.66, 312.0, 62.0)

func _target() -> float:
	if chapter_done or free_play:
		return 0.0
	return float(CHAPTERS[chapter]["targets"][progress])

func _point(angle: float, radius: float = -1.0) -> Vector2:
	var r := length if radius < 0.0 else radius
	return pivot + Vector2(sin(angle), cos(angle)) * r

func _process(delta: float) -> void:
	if not paused and not show_help:
		elapsed += delta
		if dragging and keyboard_aim:
			var direction := float(Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_LEFT))
			_advance_keyboard_aim(delta, direction)
		harmonic_time += delta
		for note in cadence_notes.duplicate():
			if harmonic_time >= float(note["at"]):
				_sound(int(note["index"]), 0.72)
				cadence_notes.erase(note)
		for i in range(7):
			bell_glows[i] = maxf(0.0, bell_glows[i] - delta * 1.1)
			bell_cooldowns[i] = maxf(0.0, bell_cooldowns[i] - delta)
		target_pulse = maxf(0.0, target_pulse - delta * 0.55)
		feedback_timer = maxf(0.0, feedback_timer - delta)
		for p in particles:
			p["pos"] += p["velocity"] * delta
			p["velocity"] *= pow(0.42, delta)
			p["life"] -= delta
		particles = particles.filter(func(p): return p["life"] > 0.0)
		for flight in light_flights:
			flight["age"] += delta
		light_flights = light_flights.filter(func(f): return f["age"] < 1.45)
		for r in ripples:
			r["age"] += delta
		ripples = ripples.filter(func(r): return r["age"] < 2.2)
		if chapter_done:
			finish_time += delta
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not started or paused or show_help:
		return
	_echo_physics(delta)
	if dragging or not swinging:
		return
	var previous_theta := theta
	var previous_omega := omega
	omega += (-PHYSICS_RATE * pow(float(TEMPOS[tempo_index]), 2.0) * sin(theta) - DAMPING * omega) * delta
	theta += omega * delta
	cast_seconds += delta
	if previous_theta * theta < 0.0:
		cast_crossed_center = true
	for i in range(7):
		var a: float = BELL_ANGLES[i]
		if ((previous_theta - a) * (theta - a) <= 0.0) and absf(omega) > 0.12 and bell_cooldowns[i] <= 0.0:
			_ring(i, clampf(absf(omega) * 0.35, 0.3, 1.0))
	if cast_crossed_center and not cast_judged and previous_omega * omega < 0.0:
		_judge_turn()
	if not reduced_motion:
		trail.append(_point(theta))
		if trail.size() > 45:
			trail.pop_front()
	if cast_seconds > 5.0 and absf(omega) < 0.012 and absf(theta) < 0.012:
		swinging = false
		theta = 0.0
		omega = 0.0

func _ring(index: int, strength: float = 0.8) -> void:
	bell_glows[index] = strength
	bell_cooldowns[index] = 0.34
	note_label = NOTE_NAMES[index]
	_sound(index, strength)
	# An outer bell winds a little escapement. The returning central bell
	# releases it, so the echo is an actual second pendulum with its own motion.
	if chapter > 0:
		if index == 1 or index == 5:
			var side := 0 if index == 1 else 1
			echoes[side]["charged"] = true
			echoes[side]["stored"] = clampf(0.75 + absf(omega) * 1.12, 0.0, 3.6)
			if _goal_kind() in ["relay", "duet"]:
				omega *= 0.97
		elif index == 3:
			for e in echoes:
				if e["charged"]:
					var impulse: float = e["stored"] if _goal_kind() in ["relay", "duet"] else (1.8 + strength * 1.4)
					e["omega"] = clampf(float(e["omega"]) + (-1.0 if int(e["side"]) == 0 else 1.0) * impulse, -3.6, 3.6)
					e["cast_id"] = casts
					e["glow"] = 1.0
					e["charged"] = false
	var pos := _point(float(BELL_ANGLES[index]), length + 11.0)
	ripples.append({"pos": pos, "age": 0.0, "strength": strength})
	if not reduced_motion:
		for i in range(5):
			var a := float(i) * TAU / 5.0 + elapsed
			particles.append({"pos": pos, "velocity": Vector2(cos(a), sin(a)) * 33.0, "life": 0.9, "color": TEAL})


func _reset_echoes() -> void:
	echoes = [
		{"side":0, "theta":0.0, "omega":0.0, "charged":false, "glow":0.0, "cooldown":0.0, "stored":0.0, "cast_id":-1, "judged_cast":-1},
		{"side":1, "theta":0.0, "omega":0.0, "charged":false, "glow":0.0, "cooldown":0.0, "stored":0.0, "cast_id":-1, "judged_cast":-1}
	]
	chain_rings = 0
	duet_hits = [false, false]
	duet_checked = [false, false]

func _echo_pivot(side: int) -> Vector2:
	var spacing := 0.32 if _goal_kind() in ["relay", "duet"] else 0.73
	return pivot + Vector2((-1.0 if side == 0 else 1.0) * length * spacing, length * 0.11)

func _echo_length() -> float:
	return length * (0.42 if _goal_kind() in ["relay", "duet"] else 0.26)

func _echo_point(side: int, angle: float) -> Vector2:
	return _echo_pivot(side) + Vector2(sin(angle), cos(angle)) * _echo_length()

func _goal_kind() -> String:
	return "free" if free_play else str(CHAPTERS[chapter].get("kind", "main"))

func _echo_target(side: int) -> float:
	if _goal_kind() == "duet":
		return -absf(_target()) if side == 0 else absf(_target()) * 0.92
	return _target()

func _goal_position() -> Vector2:
	if _goal_kind() == "relay":
		return _echo_point(0 if _target() < 0 else 1, _target())
	if _goal_kind() == "duet":
		return _echo_point(0, _echo_target(0))
	return _point(_target())

func _echo_physics(delta: float) -> void:
	for e in echoes:
		var old: float = e["theta"]
		var old_omega: float = e["omega"]
		e["omega"] += (-11.4 * sin(float(e["theta"])) - 0.50 * float(e["omega"])) * delta
		e["theta"] += float(e["omega"]) * delta
		e["glow"] = maxf(0.0, float(e["glow"]) - delta * 0.70)
		e["cooldown"] = maxf(0.0, float(e["cooldown"]) - delta)
		if old_omega * float(e["omega"]) < 0.0 and absf(float(e["theta"])) > 0.08:
			if int(e["cast_id"]) == casts and int(e["judged_cast"]) != casts:
				e["judged_cast"] = casts
				_judge_echo_turn(int(e["side"]), float(e["theta"]))
		if old * float(e["theta"]) < 0.0 and absf(float(e["omega"])) > 0.25 and float(e["cooldown"]) <= 0.0:
			e["cooldown"] = 0.28
			e["glow"] = 1.0
			chain_rings += 1
			var index := 2 if int(e["side"]) == 0 else 5
			if chapter >= 2:
				index = 4 if int(e["side"]) == 0 else 6
			_sound(index, clampf(absf(float(e["omega"])) * 0.17, 0.25, 0.60))
			ripples.append({"pos": _echo_pivot(int(e["side"])) + Vector2(0.0, _echo_length()), "age":0.0, "strength":0.6})

func _draw_echoes() -> void:
	if chapter == 0 or not started:
		return
	if not chapter_done and _goal_kind() in ["relay", "duet"] and progress == 0 and (not swinging or dragging):
		var sign_hint := -1.0 if _goal_kind() == "duet" or _target() < 0.0 else 1.0
		var guide := _point(sign_hint * 1.0)
		draw_arc(guide, 19.0, 0.0, TAU, 32, Color(0.52,0.80,0.75,0.25), 1.0, true)
		_text("この側から放す", guide + Vector2(0,-34.0), 14, TEAL, true)
	for e in echoes:
		var side: int = e["side"]
		var ep := _echo_pivot(side)
		var el := _echo_length()
		var bob := ep + Vector2(sin(float(e["theta"])), cos(float(e["theta"]))) * el
		var glow: float = e["glow"]
		var feed := _point(-0.66 if side == 0 else 0.66, length + 15.0)
		var wire_color := GOLD if e["charged"] else Color("355358")
		draw_line(feed, ep + Vector2(0.0, el + 20.0), Color(wire_color, 0.55), 1.0, true)
		draw_line(ep + Vector2(0.0, el + 20.0), ep, Color(wire_color, 0.55), 1.0, true)
		draw_arc(ep, el, PI*0.5-0.9, PI*0.5+0.9, 32, Color(0.39,0.62,0.59,0.12), 1.0, true)
		draw_line(ep, bob, Color("80a497"), 1.0, true)
		draw_circle(ep, 4.0, GOLD if e["charged"] else MUTED)
		_glow(bob, 10.0, TEAL, glow * 1.3)
		draw_circle(bob, 10.0, Color("6a9690").lerp(TEAL, glow))
		draw_circle(bob + Vector2(3,-3), 7.0, Color("17363f"))
		if not chapter_done and _goal_kind() in ["relay", "duet"]:
			if _goal_kind() == "duet" or side == (0 if _target() < 0.0 else 1):
				var target_angle := _echo_target(side)
				var beacon := _echo_point(side, target_angle)
				_glow(beacon, 18.0, GOLD, 1.4)
				draw_arc(beacon, 20.0 + sin(elapsed * 2.5) * 1.2, 0.0, TAU, 32, GOLD, 1.5, true)
				draw_arc(ep, el, PI*0.5-target_angle-0.095, PI*0.5-target_angle+0.095, 14, Color(0.91,0.80,0.50,0.32), 4.0, true)
				if _goal_kind() == "duet" and duet_hits[side] and not cast_judged:
					draw_circle(beacon, 5.0, GOLD)
		_text("A4" if side == 1 and chapter == 1 else ("D4" if chapter == 1 else ("F♯4" if side == 0 else "D5")), ep + Vector2(0.0, el + 45.0), 11, MUTED, true)

func _sound(index: int, strength: float = 0.8) -> void:
	if muted or not started or paused:
		return
	var player := players[voice % players.size()]
	voice += 1
	player.stream = sounds[index]
	player.volume_db = -13.0 + strength * 6.0
	player.play()

func _stop_audio() -> void:
	for player in players:
		player.stop()

func _judge_turn() -> void:
	if _goal_kind() in ["relay", "duet"]:
		return
	cast_judged = true
	if chapter_done or free_play:
		return
	var target := _target()
	var error := absf(theta - target)
	if error <= HIT_TOLERANCE:
		_award_goal(error, _point(target))
	else:
		if signf(theta) != signf(target):
			feedback = "光の反対側へ引いてから、放してみよう。"
		elif absf(theta) < absf(target):
			feedback = "あと少し大きく引くと、光へ届きそう。"
		else:
			feedback = "少しやさしく。光の近くで折り返そう。"
		feedback_timer = 5.0
	_publish_state()

func _award_goal(error: float, where: Vector2) -> void:
	cast_judged = true
	if not reduced_motion:
		light_flights.append({"from":where, "index":progress, "age":0.0})
	var perfect := error <= 0.065
	if perfect:
		perfects += 1
	feedback = "澄んだ一音。光がつながった。" if perfect else "届いた！ 次の光へ奏でよう。"
	feedback_timer = 3.5
	target_pulse = 1.0
	var pos := where
	for i in range(22):
		var a := float(i) * TAU / 22.0
		particles.append({"pos": pos, "velocity": Vector2(cos(a), sin(a)) * (65.0 + float(i % 3) * 22.0), "life": 1.7, "color": GOLD})
	progress += 1
	_sound(4, 0.72)
	if progress >= CHAPTERS[chapter]["targets"].size():
		chapter_done = true
		finish_time = 0.0
		feedback = "夜に、あなたの旋律が残った。"
		var rating := 3 if casts <= progress + 1 else (2 if casts <= progress * 2 else 1)
		best_chapters[chapter] = maxi(int(best_chapters[chapter]), rating)
		_save()
		cadence_notes = [{"at": harmonic_time + 0.2, "index": 0}, {"at": harmonic_time + 0.42, "index": 2}, {"at": harmonic_time + 0.64, "index": 4}, {"at": harmonic_time + 0.88, "index": 5}, {"at": harmonic_time + 1.12, "index": 6}]
	_publish_state()

func _judge_echo_turn(side: int, angle: float) -> void:
	if chapter_done or free_play or cast_judged or not swinging:
		return
	var kind := _goal_kind()
	if kind not in ["relay", "duet"]:
		return
	if kind == "relay" and side != (0 if _target() < 0.0 else 1):
		return
	var target := _echo_target(side)
	var error := absf(angle - target)
	if kind == "relay":
		cast_judged = true
		if error <= 0.095:
			_award_goal(error, _echo_point(side, target))
		else:
			feedback = "鐘へ、もう少し強く力を渡そう。" if absf(angle) < absf(target) else "少し小さく引くと、小さな月が光へ届く。"
	else:
		duet_checked[side] = true
		duet_hits[side] = error <= 0.095
		if duet_hits[side]:
			feedback = "一つ届いた！ もう一つの月を聴こう。"
			_sound(4, 0.5)
		if duet_checked[0] and duet_checked[1]:
			cast_judged = true
			if duet_hits[0] and duet_hits[1]:
				_award_goal(error, _echo_point(side, target))
			else:
				feedback = "二つの月が、光で折り返す強さを探そう。"
	feedback_timer = 5.0
	_publish_state()

func _begin_pull(pos: Vector2) -> void:
	if chapter_done or show_help or paused:
		return
	dragging = true
	keyboard_aim = false
	swinging = false
	omega = 0.0
	trail.clear()
	_update_pull(pos)

func _advance_keyboard_aim(delta: float, direction: float) -> void:
	if dragging and keyboard_aim and not paused and not show_help:
		theta = clampf(theta + direction * delta * 0.80, -MAX_PULL, MAX_PULL)

func _update_pull(pos: Vector2) -> void:
	var v := pos - pivot
	if v.y < 25.0:
		v.y = 25.0
	theta = clampf(atan2(v.x, v.y), -MAX_PULL, MAX_PULL)

func _release() -> void:
	if not dragging:
		return
	dragging = false
	keyboard_aim = false
	if absf(theta) < 0.08:
		theta = 0.0
		feedback = "左右へ月を引いて、指を離してみよう。"
		feedback_timer = 3.0
		return
	casts += 1
	cast_start_angle = theta
	omega = 0.0
	swinging = true
	cast_crossed_center = false
	cast_judged = false
	cast_seconds = 0.0
	feedback = "月が光に届く、その一瞬を聴こう。" if not free_play else "鐘から振り子へ、あなたの音がつながる。"
	if _goal_kind() in ["relay", "duet"]:
		_reset_echoes()
		feedback = "鐘から小さな月へ、力がつながっていく。"
		var wanted_side := -1.0 if _goal_kind() == "duet" or _target() < 0.0 else 1.0
		if signf(theta) != wanted_side:
			cast_judged = true
			feedback = "光のある側から、放してみよう。"
	_publish_state()

func _resume_chapter() -> int:
	for i in range(CHAPTERS.size()):
		if int(best_chapters[i]) == 0:
			return i
	return CHAPTERS.size()

func _start() -> void:
	started = true
	_new_chapter(_resume_chapter())
	_sound(2, 0.5)
	_publish_state()

func _retry() -> void:
	dragging = false
	keyboard_aim = false
	swinging = false
	omega = 0.0
	theta = 0.0
	trail.clear()
	_stop_audio()
	_reset_echoes()
	cadence_notes.clear()
	feedback = "光の反対側へ引いて、もうひと振り。" if not free_play else "光のない夜を、好きな音で奏でよう。"
	feedback_timer = 0.0
	if _goal_kind() == "relay":
		feedback = "光のある小さな月の側へ、もうひと振り。"
	elif _goal_kind() == "duet":
		feedback = "左から放して、二つの小さな月へ力を届けよう。"
	_publish_state()

func _new_chapter(index: int) -> void:
	free_play = index == CHAPTERS.size()
	chapter = 2 if free_play else clampi(index, 0, CHAPTERS.size()-1)
	tempo_index = 1
	progress = 0
	casts = 0
	perfects = 0
	chapter_done = false
	finish_time = 0.0
	particles.clear()
	light_flights.clear()
	ripples.clear()
	_retry()
	if free_play:
		feedback = "光のない夜を、好きな音で奏でよう。"
	elif _goal_kind() == "relay":
		feedback = "鐘から小さな月へ、力を届けよう。"
	elif _goal_kind() == "duet":
		feedback = "左からひと振りで、二つの月を光へ。"

func _toggle_mute() -> void:
	muted = not muted
	if muted:
		_stop_audio()
	_save()
	_publish_state()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var pos: Vector2 = event.position
			if not started:
				if start_rect.has_point(pos):
					_start()
				return
			if mute_rect.has_point(pos):
				_toggle_mute()
			elif help_rect.has_point(pos):
				show_help = not show_help
				if show_help:
					_stop_audio()
				_publish_state()
			elif pause_rect.has_point(pos):
				paused = not paused
				if paused:
					_stop_audio()
				_publish_state()
			elif show_help:
				show_help = false
				_publish_state()
			elif retry_rect.has_point(pos):
				if chapter_done and chapter >= 2 and chapter < CHAPTERS.size()-1:
					_new_chapter(CHAPTERS.size())
				else:
					_new_chapter(chapter) if chapter_done else _retry()
			elif (chapter_done or free_play) and next_rect.has_point(pos):
				_new_chapter(0 if free_play else chapter + 1)
			elif reset_rect.has_point(pos):
				if free_play:
					tempo_index = (tempo_index + 1) % TEMPOS.size()
				else:
					_new_chapter(chapter)
			elif stage_rect.has_point(pos) and not paused:
				_begin_pull(pos)
		else:
			_release()
	elif event is InputEventMouseMotion and dragging:
		_update_pull(event.position)
	elif event is InputEventKey and event.pressed:
		if event.echo:
			return
		if show_help and event.keycode == KEY_ESCAPE:
			show_help = false
			_publish_state()
			return
		if show_help and event.keycode not in [KEY_H, KEY_ESCAPE, KEY_M]:
			return
		if not started:
			if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
				_start()
			return
		match event.keycode:
			KEY_M:
				_toggle_mute()
			KEY_H:
				show_help = not show_help
				if show_help:
					_stop_audio()
				_publish_state()
			KEY_P, KEY_ESCAPE:
				paused = not paused
				if paused:
					_stop_audio()
				_publish_state()
			KEY_R:
				_new_chapter(chapter) if chapter_done else _retry()
			KEY_ENTER:
				if chapter_done or free_play:
					_new_chapter(0 if free_play else chapter + 1)
			KEY_LEFT, KEY_RIGHT:
				if not chapter_done and not paused:
					if not dragging:
						_retry()
						dragging = true
					keyboard_aim = true
					var direction := -1.0 if event.keycode == KEY_LEFT else 1.0
					theta = clampf(theta + direction * 0.06, -MAX_PULL, MAX_PULL)
			KEY_SPACE:
				_release()

func _text(text: String, pos: Vector2, font_size: int, color: Color = WHITE, center: bool = false) -> void:
	var x := pos.x
	if center:
		var available := size.x - 62.0
		while font_size > 12 and FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > available:
			font_size -= 1
	if center:
		x -= FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * 0.5
	draw_string(FONT, Vector2(x, pos.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _panel(rect: Rect2, fill: Color, border: Color = Color.TRANSPARENT, radius: float = 14.0) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1 if border.a > 0.0 else 0)
	style.set_corner_radius_all(int(radius))
	draw_style_box(style, rect)

func _button(rect: Rect2, label: String, primary: bool = false, disabled: bool = false) -> void:
	var fill := Color("c5e5d5") if primary else Color("122d3a")
	var color := INK if primary else WHITE
	if disabled:
		fill = Color("0d2430")
		color = Color("46606b")
	_panel(rect, fill, Color("33515b") if not primary else Color.TRANSPARENT, 10.0)
	_text(label, Vector2(rect.get_center().x, rect.position.y + rect.size.y * 0.64), 20, color, true)

func _glow(pos: Vector2, radius: float, color: Color, strength: float = 1.0) -> void:
	for i in range(5, 0, -1):
		var c := color
		c.a = 0.021 * strength * (6.0 - float(i))
		draw_circle(pos, radius * (1.0 + float(i) * 0.35), c)

func _draw() -> void:
	if size.x <= 0.0:
		return
	_draw_background()
	_draw_sky_constellation()
	_draw_stage()
	_draw_echoes()
	_draw_light_flights()
	_draw_header()
	if started:
		_draw_score()
		_button(retry_rect, "余韻の庭へ" if chapter_done and chapter >= 2 and chapter < CHAPTERS.size()-1 else ("もう一度" if chapter_done else "引き直す  R"))
		_button(next_rect, "楽章へ戻る" if free_play else ("余韻の庭へ" if chapter == CHAPTERS.size()-1 else "次の楽章へ"), true, not chapter_done and not free_play)
	else:
		_draw_intro()
	if show_help and started:
		_draw_help()
	if paused and started and not show_help:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.03, 0.04, 0.78))
		_text("ひと休み", Vector2(size.x * 0.5, size.y * 0.46), 38, GOLD, true)
		_text("P または右上の ▶ で、夜を再開", Vector2(size.x * 0.5, size.y * 0.46 + 47.0), 21, WHITE, true)
		_button(pause_rect, "▶")

func _sky_position(index: int) -> Vector2:
	var count: int = 7 if free_play else CHAPTERS[chapter]["targets"].size()
	var span := minf(size.x * 0.60, 350.0)
	var t := float(index) / float(maxi(1,count-1))
	var sky_y := 109.0 + maxf(0.0, pivot.y - 220.0) * 0.40
	var wave := -sin(t * PI) * 14.0
	if chapter == 1 or chapter == 3:
		wave = sin(t * TAU) * 9.0
	return Vector2(size.x * 0.5 + (t - 0.5) * span, sky_y + wave)

func _draw_sky_constellation() -> void:
	if not started:
		return
	var count: int = 7 if free_play else CHAPTERS[chapter]["targets"].size()
	for i in range(count):
		var pos := _sky_position(i)
		var lit := free_play or i < progress
		if i > 0:
			var line_color := Color(0.72,0.68,0.48,0.32) if lit else Color(0.34,0.55,0.56,0.10)
			draw_line(_sky_position(i-1), pos, line_color, 1.0, true)
		if lit:
			_glow(pos, 7.0, GOLD, 1.0)
			draw_line(pos + Vector2(-6,0), pos + Vector2(6,0), Color(0.96,0.87,0.64,0.6), 1.0, true)
			draw_line(pos + Vector2(0,-6), pos + Vector2(0,6), Color(0.96,0.87,0.64,0.6), 1.0, true)
		draw_circle(pos, 2.3 if lit else 1.6, GOLD if lit else Color("335661"))
		if _goal_kind() == "duet":
			draw_circle(pos + Vector2(7,7), 1.8, GOLD if lit else Color("335661"))

func _flight_point(start: Vector2, finish: Vector2, t: float) -> Vector2:
	var ease_t := t*t*(3.0-2.0*t)
	return start.lerp(finish,ease_t) + Vector2(sin(t*TAU)*18.0, -sin(t*PI)*42.0)

func _draw_light_flights() -> void:
	for flight in light_flights:
		var t := clampf(float(flight["age"]) / 1.25, 0.0, 1.0)
		var finish := _sky_position(int(flight["index"]))
		var start: Vector2 = flight["from"]
		for i in range(6):
			var tail_t := maxf(0.0, t-float(i)*0.045)
			draw_circle(_flight_point(start, finish, tail_t), 2.8-float(i)*0.32, Color(0.96,0.85,0.61,0.8-float(i)*0.11))
		_glow(_flight_point(start,finish,t), 7.0, GOLD, 1.2)

func _draw_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), INK)
	for i in range(20):
		var y := size.y * float(i) / 20.0
		var c := Color("102c37").lerp(INK, float(i) / 20.0)
		c.a = 0.42
		draw_rect(Rect2(0.0, y, size.x, size.y / 20.0 + 1.0), c)
	for star in stars:
		var pos := Vector2(star["x"] * size.x, 90.0 + star["y"] * (size.y * 0.58))
		var alpha := 0.23 + 0.20 * sin(elapsed * 0.55 + star["phase"])
		draw_circle(pos, star["r"], Color(0.66, 0.8, 0.79, alpha))
	var pond_y := pivot.y + length + 71.0
	var horizon := minf(pond_y, size.y - 192.0)
	# Soft nocturnal ridges, reflected rings and reeds frame the instrument.
	for row in range(3):
		var pts := PackedVector2Array([Vector2(-20.0, size.y)])
		for i in range(27):
			var x := size.x * float(i) / 26.0
			var y := horizon - 14.0 + float(row) * 19.0 + sin(float(i) * 0.58 + float(row) * 1.9) * 19.0
			pts.append(Vector2(x, y))
		pts.append(Vector2(size.x + 20.0, size.y))
		draw_colored_polygon(pts, [Color("102c35"), Color("0c2630"), Color("0b202c")][row])
	for i in range(10):
		var y := horizon + 19.0 + float(i) * 14.0
		var width := 38.0 + float(i) * 15.0
		draw_line(Vector2(size.x * 0.5 - width, y), Vector2(size.x * 0.5 + width, y), Color(0.31, 0.56, 0.58, 0.07), 1.0)
	for side in [-1.0, 1.0]:
		for i in range(7):
			var x: float = size.x * 0.5 + side * (size.x * 0.40 + float(i) * 7.0)
			var y := horizon + 38.0
			var tip := Vector2(x + sin(elapsed * 0.45 + float(i)) * 5.0 + side * 10.0, y - 45.0 - float(i % 3) * 17.0)
			draw_line(Vector2(x, y), tip, Color("23464b"), 1.2)
			draw_line(tip - Vector2(0, -13), tip + Vector2(side * 12, 8), Color("315657"), 1.2)

func _draw_header() -> void:
	_text("月の振り子", Vector2(30.0, 49.0), 30, GOLD)
	_text("MOON PENDULUM", Vector2(31.0, 70.0), 11, MUTED)
	if started:
		_button(mute_rect, "音 OFF" if muted else "音 ON")
		_button(help_rect, "？")
		_button(pause_rect, "▶" if paused else "Ⅱ")
		_text(TEMPO_NAMES[tempo_index] + " →" if free_play else "最初から", Vector2(38.0, 96.0), 14, MUTED)

func _draw_stage() -> void:
	var arc_color := Color(0.38, 0.6, 0.59, 0.14)
	draw_arc(pivot, length, PI * 0.5 - MAX_PULL, PI * 0.5 + MAX_PULL, 80, arc_color, 1.3, true)
	draw_arc(pivot, length + 32.0, PI * 0.5 - 1.10, PI * 0.5 + 1.10, 60, Color(0.35, 0.56, 0.57, 0.055), 1.0, true)
	# Architectural frame: an open shrine, a fine brass crossbar and hanging bells.
	var top_y := pivot.y - 28.0
	var half_width := minf(size.x * 0.38, length * 0.90)
	for side in [-1.0, 1.0]:
		var x: float = pivot.x + side * half_width
		draw_line(Vector2(x, top_y + 21), Vector2(x, pivot.y + length + 42), Color("183c45"), 8.0)
		draw_line(Vector2(x - side * 7, top_y + 25), Vector2(x - side * 7, pivot.y + length + 40), Color("2c4b4d"), 1.0)
	draw_line(Vector2(pivot.x - half_width - 16, top_y + 13), Vector2(pivot.x + half_width + 16, top_y + 13), Color("294649"), 7.0)
	draw_line(Vector2(pivot.x - half_width - 16, top_y + 9), Vector2(pivot.x + half_width + 16, top_y + 9), Color("718779"), 1.2)
	for i in range(7):
		var pos := _point(float(BELL_ANGLES[i]), length + 15.0)
		var glow: float = bell_glows[i]
		var bob := sin(elapsed * 4.0 + float(i)) * glow * 4.0
		pos.x += bob
		draw_line(Vector2(pos.x, pos.y - 50.0), Vector2(pos.x, pos.y - 13.0), Color(0.31, 0.47, 0.49, 0.50), 1.0)
		_glow(pos, 12.0 + glow * 7.0, TEAL, glow * 3.0)
		var points := PackedVector2Array([pos + Vector2(-8,-11), pos + Vector2(8,-11), pos + Vector2(11,7), pos + Vector2(-11,7)])
		draw_colored_polygon(points, Color("446a6b").lerp(TEAL, glow))
		draw_line(pos + Vector2(-11,7), pos + Vector2(11,7), Color("a9b69b").lerp(WHITE, glow), 1.5)
		draw_circle(pos + Vector2(0,10), 2.0, GOLD)
		_text(NOTE_NAMES[i], pos + Vector2(0, 35), 11, MUTED, true)
	if started and not chapter_done and _goal_kind() == "main":
		var target := _target()
		var target_pos := _point(target)
		var pulse := 0.75 + sin(elapsed * 2.5) * 0.15
		_glow(target_pos, 20.0, GOLD, pulse * 1.6)
		draw_arc(pivot, length, PI * 0.5 - target - HIT_TOLERANCE, PI * 0.5 - target + HIT_TOLERANCE, 18, Color(0.91,0.80,0.50,0.28), 5.0, true)
		draw_arc(target_pos, 26.0 + sin(elapsed * 2.5) * 2.0, 0, TAU, 48, Color(0.94,0.84,0.61,0.8), 1.5, true)
		_text("光の輪", target_pos + Vector2(0, -40.0), 16, GOLD, true)
		if not swinging or dragging:
			var guide := _point(-target * 1.055)
			draw_arc(guide, 19.0, 0.0, TAU, 32, Color(0.52,0.80,0.75,0.25), 1.0, true)
			_text("ここから放す", guide + Vector2(0, -33), 14, Color(0.52,0.80,0.75,0.6), true)
	for i in range(1, trail.size()):
		var c := GOLD
		c.a = float(i) / float(trail.size()) * 0.22
		draw_line(trail[i-1], trail[i], c, 2.0)
	for r in ripples:
		var c := TEAL
		c.a = maxf(0.0, 1.0 - float(r["age"]) / 2.2) * 0.26
		draw_arc(r["pos"], 8.0 + float(r["age"]) * 45.0, 0, TAU, 32, c, 1.0, true)
	var moon := _point(theta)
	_glow(moon, 25.0, GOLD, 1.4)
	draw_line(pivot, moon, Color("86aaa2"), 1.8, true)
	draw_circle(pivot, 6.0, GOLD)
	draw_circle(pivot, 2.0, INK)
	draw_circle(moon, 25.0, GOLD)
	draw_circle(moon + Vector2(9,-7), 21.0, Color("203940"))
	draw_arc(moon, 30.0, 0, TAU, 48, Color(0.92,0.84,0.65,0.15), 1.0, true)
	if dragging:
		draw_arc(moon, 38.0, 0, TAU, 48, Color(0.64,0.89,0.82,0.4), 1.0, true)
		_text("指を離して放す", moon + Vector2(0, 59), 16, WHITE, true)
	elif started and not swinging and not chapter_done:
		_text("← 月を引いて放す →", moon + Vector2(0, 68), 17, MUTED, true)
	for p in particles:
		var c: Color = p["color"]
		c.a = clampf(float(p["life"]), 0.0, 1.0) * 0.8
		draw_circle(p["pos"], 1.8, c)
	if chapter_done:
		var glow := (0.5 + sin(elapsed) * 0.1) * minf(1.0, finish_time)
		_glow(Vector2(pivot.x, pivot.y + 80), 75, GOLD, glow * 2.0)

func _draw_score() -> void:
	var card_y := size.y - 245.0
	var card := Rect2(28.0, card_y, size.x - 56.0, 137.0)
	_panel(card, Color(0.045, 0.12, 0.15, 0.82), Color("29454d"), 16.0)
	_text("余韻の庭" if free_play else CHAPTERS[chapter]["name"], Vector2(49.0, card_y + 34.0), 23, GOLD)
	var total: int = 0 if free_play else CHAPTERS[chapter]["targets"].size()
	for i in range(total):
		var pos := Vector2(size.x - 57.0 - float(total - 1 - i) * 26.0, card_y + 27.0)
		draw_circle(pos, 6.0, GOLD if i < progress else Color("2d4a50"))
		if i == progress and not chapter_done:
			draw_arc(pos, 9.0, 0, TAU, 24, GOLD, 1.0, true)
	_text(feedback, Vector2(size.x * 0.5, card_y + 76.0), 20, WHITE, true)
	var summary := "左右へドラッグ → 離す  /  ← → で調整、Space で放す"
	if free_play:
		summary = "回数も目標もなし。左上で振り子の速さを変えられる。"
	elif chapter_done:
		var unit := "組の光" if _goal_kind() == "duet" else "個の光"
		summary = "%d %s · %d 回のひと振り · 澄んだ一音 %d 回" % [progress, unit, casts, perfects]
	elif dragging:
		summary = "引く大きさで、届く場所が変わる。"
	elif swinging:
		summary = "鐘は D メジャーの五音。月の動きが旋律になる。"
		if chapter > 0:
			summary = "左右の鐘から、もう一つの振り子へ音がつながる。"
	if not chapter_done and _goal_kind() == "relay":
		summary = "光は小さな月に。引く強さが、鐘で渡す力になる。"
	elif not chapter_done and _goal_kind() == "duet":
		summary = "左から放す。左右の鐘を通り、二つの光をつなぐ。"
	_text(summary, Vector2(size.x * 0.5, card_y + 108.0), 15, MUTED, true)

func _draw_intro() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02,0.05,0.07,0.52))
	var y := size.y * 0.36
	_text("夜を、ひと振り。", Vector2(size.x * 0.5, y), 45, GOLD, true)
	_text("月を引いて放つと、鐘が歌いはじめる。", Vector2(size.x * 0.5, y + 55.0), 22, WHITE, true)
	_text("光の輪へ、そっと届かせてみよう。", Vector2(size.x * 0.5, y + 92.0), 22, WHITE, true)
	_text("5つの楽章 / マウス・タッチ・キーボード", Vector2(size.x * 0.5, start_rect.position.y - 25.0), 15, MUTED, true)
	_button(start_rect, "つづきの夜を奏でる" if _resume_chapter() > 0 else "音のある夜をはじめる", true)
	_text("この操作で音が有効になります。途中でミュートできます。", Vector2(size.x * 0.5, start_rect.end.y + 34.0), 14, MUTED, true)
	_text("つくる・奏でる・もう一度。", Vector2(size.x * 0.5, size.y - 44.0), 15, Color("7b9da2"), true)

func _draw_help() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02,0.04,0.06,0.87))
	var cx := size.x * 0.5
	var y := size.y * 0.26
	_text("月の奏で方", Vector2(cx,y), 34,GOLD,true)
	var lines := ["1. 光の輪と反対側へ、月を引く。", "2. 指を離すと、月が反対側へ揺れる。", "3. 光の近くで折り返すと、光がつながる。", "", "小さく引けば近くへ、大きく引けば遠くへ。", "薄い緑の輪は、放す場所の目安。", "失敗しても音は残る。何度でも奏でよう。", "", "← →：角度を調整　Space：放す", "R：引き直す　M：ミュート　P：一時停止"]
	if _goal_kind() in ["relay", "duet"]:
		lines[0] = "今度は、小さな月の光を狙う。"
		lines[1] = "外側の鐘を通して、中央の鐘へ戻す。"
		lines[2] = "蓄えた力が、小さな月を揺らす。"
		lines[5] = "光のある側から、少し大きく引いてみよう。"
		if _goal_kind() == "duet":
			lines[5] = "左から放して、左右の光をひと振りで。"
	if free_play:
		lines[0] = "光の輪のない、自由な夜。"
		lines[1] = "月を引いて放すと、鐘が歌う。"
		lines[2] = "左上で速さを変えて、音を奏で分けよう。"
		lines[5] = "鐘から副振り子へ、音がつながる。"
	for i in range(lines.size()):
		_text(lines[i],Vector2(cx,y+54.0+float(i)*34.0),20,WHITE,true)
	_text("どこかをタップして閉じる / H",Vector2(cx,y+440.0),17,MUTED,true)

func _load_save() -> void:
	var config := ConfigFile.new()
	if config.load("user://moon_pendulum.cfg") == OK:
		muted = bool(config.get_value("settings", "muted", false))
		for i in range(CHAPTERS.size()):
			best_chapters[i] = int(config.get_value("best", str(i), 0))

func _save() -> void:
	if testing:
		return
	var config := ConfigFile.new()
	config.set_value("settings", "muted", muted)
	for i in range(CHAPTERS.size()):
		config.set_value("best", str(i), best_chapters[i])
	config.save("user://moon_pendulum.cfg")

func _publish_state() -> void:
	# A read-only public QA snapshot. It cannot alter gameplay or storage.
	if OS.has_feature("web"):
		var state := {"started":started,"chapter":chapter,"kind":_goal_kind(),"progress":progress,"casts":casts,"launch":cast_start_angle,"complete":chapter_done,"freePlay":free_play,"muted":muted,"paused":paused,"help":show_help,"build":BUILD.COMMIT,"engine":Engine.get_version_info()["string"]}
		JavaScriptBridge.eval("window.moonPendulumState = " + JSON.stringify(state) + ";")
