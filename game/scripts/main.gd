extends Node2D
## Moon Pendulum: a small, deterministic musical physics toy with a learning loop.
## Pendulum motion uses a fixed physics timestep; all art is original vector drawing.

const FONT = preload("res://assets/fonts/MoonSans.ttf")
const BELL_ANGLES = [-0.96, -0.66, -0.34, 0.0, 0.34, 0.66, 0.96]
const NOTE_NAMES = ["D3", "A3", "D4", "E4", "F♯4", "A4", "D5"]
const CHAPTERS = [
	{"name": "I · はじめの光", "subtitle": "ひと振りから、夜が目を覚ます。", "targets": [0.55, -0.55, 0.82]},
	{"name": "II · 水面の三重奏", "subtitle": "小さな弧と、大きな弧を奏で分ける。", "targets": [-0.34, 0.68, -0.91, 0.48]},
	{"name": "III · 月へ帰る旋律", "subtitle": "五つの光をつないで、夜を満たそう。", "targets": [0.90, -0.64, 0.35, -0.82, 0.60]}
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
var best_chapters: Array = [0, 0, 0]
var reduced_motion := false

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
	if OS.has_feature("web"):
		reduced_motion = bool(JavaScriptBridge.eval("window.matchMedia('(prefers-reduced-motion: reduce)').matches"))
	get_viewport().size_changed.connect(_layout)
	_publish_state()

func _layout() -> void:
	size = get_viewport_rect().size
	var portrait := size.y > size.x * 1.20
	length = minf(size.x * 0.43, (size.y - 325.0) * 0.72)
	pivot = Vector2(size.x * 0.5, 158.0 + maxf(0.0, size.y - 860.0) * 0.23)
	if not portrait:
		pivot.y = 139.0
	stage_rect = Rect2(24.0, 112.0, size.x - 48.0, size.y - 350.0)
	stage_rect.size.y = maxf(stage_rect.size.y, length + 115.0)
	var bottom_y := size.y - 86.0
	var bw := minf(220.0, (size.x - 92.0) / 3.0)
	retry_rect = Rect2(size.x * 0.5 - bw - 8.0, bottom_y, bw, 52.0)
	next_rect = Rect2(size.x * 0.5 + 8.0, bottom_y, bw, 52.0)
	reset_rect = Rect2(28.0, 72.0, 100.0, 34.0)
	mute_rect = Rect2(size.x - 144.0, 27.0, 112.0, 42.0)
	help_rect = Rect2(size.x - 196.0, 27.0, 42.0, 42.0)
	pause_rect = Rect2(size.x - 250.0, 27.0, 42.0, 42.0)
	start_rect = Rect2(size.x * 0.5 - 156.0, size.y * 0.66, 312.0, 62.0)

func _target() -> float:
	if chapter_done:
		return 0.0
	return float(CHAPTERS[chapter]["targets"][progress])

func _point(angle: float, radius: float = -1.0) -> Vector2:
	var r := length if radius < 0.0 else radius
	return pivot + Vector2(sin(angle), cos(angle)) * r

func _process(delta: float) -> void:
	if not paused:
		elapsed += delta
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
		for r in ripples:
			r["age"] += delta
		ripples = ripples.filter(func(r): return r["age"] < 2.2)
		if chapter_done:
			finish_time += delta
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not started or paused or show_help or dragging or not swinging:
		return
	var previous_theta := theta
	var previous_omega := omega
	omega += (-PHYSICS_RATE * sin(theta) - DAMPING * omega) * delta
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
	var pos := _point(float(BELL_ANGLES[index]), length + 11.0)
	ripples.append({"pos": pos, "age": 0.0, "strength": strength})
	if not reduced_motion:
		for i in range(5):
			var a := float(i) * TAU / 5.0 + elapsed
			particles.append({"pos": pos, "velocity": Vector2(cos(a), sin(a)) * 33.0, "life": 0.9, "color": TEAL})

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
	cast_judged = true
	if chapter_done:
		return
	var target := _target()
	var error := absf(theta - target)
	if error <= HIT_TOLERANCE:
		var perfect := error <= 0.065
		if perfect:
			perfects += 1
		feedback = "澄んだ一音。光がつながった。" if perfect else "届いた！ 次の光へ奏でよう。"
		feedback_timer = 3.5
		target_pulse = 1.0
		var pos := _point(target)
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
	else:
		if signf(theta) != signf(target):
			feedback = "光の反対側へ引いてから、放してみよう。"
		elif absf(theta) < absf(target):
			feedback = "あと少し大きく引くと、光へ届きそう。"
		else:
			feedback = "少しやさしく。光の近くで折り返そう。"
		feedback_timer = 5.0
	_publish_state()

func _begin_pull(pos: Vector2) -> void:
	if chapter_done or show_help or paused:
		return
	dragging = true
	swinging = false
	omega = 0.0
	trail.clear()
	_update_pull(pos)

func _update_pull(pos: Vector2) -> void:
	var v := pos - pivot
	if v.y < 25.0:
		v.y = 25.0
	theta = clampf(atan2(v.x, v.y), -MAX_PULL, MAX_PULL)

func _release() -> void:
	if not dragging:
		return
	dragging = false
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
	feedback = "月が光に届く、その一瞬を聴こう。"
	_publish_state()

func _start() -> void:
	started = true
	_sound(2, 0.5)
	feedback = "月を引いて放す。光の輪で折り返そう。"
	_publish_state()

func _retry() -> void:
	dragging = false
	swinging = false
	omega = 0.0
	theta = 0.0
	trail.clear()
	_stop_audio()
	feedback = "光の反対側へ引いて、もうひと振り。"
	feedback_timer = 0.0
	_publish_state()

func _new_chapter(index: int) -> void:
	chapter = index
	progress = 0
	casts = 0
	perfects = 0
	chapter_done = false
	finish_time = 0.0
	particles.clear()
	ripples.clear()
	_retry()

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
			elif pause_rect.has_point(pos):
				paused = not paused
				if paused:
					_stop_audio()
			elif show_help:
				show_help = false
			elif retry_rect.has_point(pos):
				_new_chapter(chapter) if chapter_done else _retry()
			elif chapter_done and next_rect.has_point(pos):
				_new_chapter((chapter + 1) % CHAPTERS.size())
			elif reset_rect.has_point(pos):
				_new_chapter(chapter)
			elif stage_rect.has_point(pos) and not paused:
				_begin_pull(pos)
		else:
			_release()
	elif event is InputEventMouseMotion and dragging:
		_update_pull(event.position)
	elif event is InputEventKey and event.pressed and not event.echo:
		if not started:
			if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
				_start()
			return
		match event.keycode:
			KEY_M:
				_toggle_mute()
			KEY_H:
				show_help = not show_help
			KEY_P, KEY_ESCAPE:
				paused = not paused
				if paused:
					_stop_audio()
			KEY_R:
				_new_chapter(chapter) if chapter_done else _retry()
			KEY_ENTER:
				if chapter_done:
					_new_chapter((chapter + 1) % CHAPTERS.size())
			KEY_LEFT, KEY_RIGHT:
				if not chapter_done and not paused:
					if not dragging:
						_retry()
						dragging = true
					var direction := -1.0 if event.keycode == KEY_LEFT else 1.0
					theta = clampf(theta + direction * 0.06, -MAX_PULL, MAX_PULL)
			KEY_SPACE:
				_release()

func _text(text: String, pos: Vector2, font_size: int, color: Color = WHITE, center: bool = false) -> void:
	var x := pos.x
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
	_draw_stage()
	_draw_header()
	if started:
		_draw_score()
		_button(retry_rect, "もう一度" if chapter_done else "引き直す  R")
		_button(next_rect, "余韻でもう一周" if chapter == 2 else "次の楽章へ", true, not chapter_done)
		_text("GODOT 4.7.2  /  AN ORIGINAL 4BAND STUDY", Vector2(size.x * 0.5, size.y - 13.0), 11, Color("50717b"), true)
	else:
		_draw_intro()
	if show_help and started:
		_draw_help()
	if paused and started:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.03, 0.04, 0.78))
		_text("ひと休み", Vector2(size.x * 0.5, size.y * 0.46), 38, GOLD, true)
		_text("P または右上の ▶ で、夜を再開", Vector2(size.x * 0.5, size.y * 0.46 + 47.0), 21, WHITE, true)
		_button(pause_rect, "▶")

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
		_text("最初から", Vector2(38.0, 96.0), 14, MUTED)
	else:
		_text("4BAND / INTERACTIVE STUDY 08", Vector2(size.x - 286.0, 51.0), 12, MUTED, false)

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
	if started and not chapter_done:
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
	_text(CHAPTERS[chapter]["name"], Vector2(49.0, card_y + 34.0), 23, GOLD)
	var total: int = CHAPTERS[chapter]["targets"].size()
	for i in range(total):
		var pos := Vector2(size.x - 57.0 - float(total - 1 - i) * 26.0, card_y + 27.0)
		draw_circle(pos, 6.0, GOLD if i < progress else Color("2d4a50"))
		if i == progress and not chapter_done:
			draw_arc(pos, 9.0, 0, TAU, 24, GOLD, 1.0, true)
	_text(feedback, Vector2(size.x * 0.5, card_y + 76.0), 20, WHITE, true)
	var summary := "左右へドラッグ → 離す  /  ← → で調整、Space で放す"
	if chapter_done:
		summary = "%d 個の光 · %d 回のひと振り · 澄んだ一音 %d 回" % [progress, casts, perfects]
	elif dragging:
		summary = "引く大きさで、届く場所が変わる。"
	elif swinging:
		summary = "鐘は D メジャーの五音。月の動きが旋律になる。"
	_text(summary, Vector2(size.x * 0.5, card_y + 108.0), 15, MUTED, true)

func _draw_intro() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02,0.05,0.07,0.52))
	var y := size.y * 0.36
	_text("夜を、ひと振り。", Vector2(size.x * 0.5, y), 45, GOLD, true)
	_text("月を引いて放つと、鐘が歌いはじめる。", Vector2(size.x * 0.5, y + 55.0), 22, WHITE, true)
	_text("光の輪へ、そっと届かせてみよう。", Vector2(size.x * 0.5, y + 92.0), 22, WHITE, true)
	_text("3つの楽章 / 1〜3分 / マウス・タッチ・キーボード", Vector2(size.x * 0.5, start_rect.position.y - 25.0), 15, MUTED, true)
	_button(start_rect, "音のある夜をはじめる", true)
	_text("この操作で音が有効になります。途中でミュートできます。", Vector2(size.x * 0.5, start_rect.end.y + 34.0), 14, MUTED, true)
	_text("つくる・奏でる・もう一度。", Vector2(size.x * 0.5, size.y - 44.0), 15, Color("7b9da2"), true)

func _draw_help() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02,0.04,0.06,0.87))
	var cx := size.x * 0.5
	var y := size.y * 0.26
	_text("月の奏で方", Vector2(cx,y), 34,GOLD,true)
	var lines := ["1. 光の輪と反対側へ、月を引く。", "2. 指を離すと、月が反対側へ揺れる。", "3. 光の近くで折り返すと、光がつながる。", "", "小さく引けば近くへ、大きく引けば遠くへ。", "薄い緑の輪は、放す場所の目安。", "失敗しても音は残る。何度でも奏でよう。", "", "← →：角度を調整　Space：放す", "R：引き直す　M：ミュート　P：一時停止"]
	for i in range(lines.size()):
		_text(lines[i],Vector2(cx,y+54.0+float(i)*34.0),20,WHITE,true)
	_text("どこかをタップして閉じる / H",Vector2(cx,y+440.0),17,MUTED,true)

func _load_save() -> void:
	var config := ConfigFile.new()
	if config.load("user://moon_pendulum.cfg") == OK:
		muted = bool(config.get_value("settings", "muted", false))
		for i in range(3):
			best_chapters[i] = int(config.get_value("best", str(i), 0))

func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("settings", "muted", muted)
	for i in range(3):
		config.set_value("best", str(i), best_chapters[i])
	config.save("user://moon_pendulum.cfg")

func _publish_state() -> void:
	# A read-only public QA snapshot. It cannot alter gameplay or storage.
	if OS.has_feature("web"):
		var state := {"started":started,"chapter":chapter,"progress":progress,"casts":casts,"complete":chapter_done,"muted":muted,"engine":Engine.get_version_info()["string"]}
		JavaScriptBridge.eval("window.moonPendulumState = " + JSON.stringify(state) + ";")
