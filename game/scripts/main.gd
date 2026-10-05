extends Node2D
## Moon Pendulum: a small, deterministic musical physics toy with a learning loop.
## Pendulum motion uses a fixed physics timestep; all art is original vector drawing.

const BUILD = preload("res://build_info.gd")
const NIGHT_MUSIC = preload("res://scripts/night_music.gd")
const FONT = preload("res://assets/fonts/MoonSerifUI.tres")
const BELL_ANGLES = [-0.96, -0.66, -0.34, 0.0, 0.34, 0.66, 0.96]
const NOTE_NAMES = ["D3", "A3", "D4", "E4", "F♯4", "B4", "D5"]
const CHAPTERS = [
	{"name":"I · はじめの光", "targets":[0.55,-0.80,0.68], "kinds":["main","main","relay"]},
	{"name":"II · 二つの月", "targets":[0.65,0.77], "kind":"duet"},
	{"name":"III · 音の残り香", "targets":[-0.92,-0.72], "kinds":["main","relay"]},
	{"name":"IV · 連鎖の回廊", "targets":[-0.80,0.86], "kind":"relay"},
	{"name":"V · 月へ帰る旋律", "targets":[0.78,0.86], "kind":"duet"}
]
const PALETTES = [
	{"name":"蒼の夜", "ink":Color("071b28"), "deep":Color("102c37"), "gold":Color("ecd7a4"), "teal":Color("85d4c9")},
	{"name":"灯りの夜", "ink":Color("211c26"), "deep":Color("3e2a35"), "gold":Color("f3cf95"), "teal":Color("d6aaa1")},
	{"name":"白む夜", "ink":Color("182a35"), "deep":Color("354d5b"), "gold":Color("f4ead4"), "teal":Color("b1d9d8")}
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
const WEB_SAVE_KEY = "moon-pendulum.demo8.save.v1"
# Geometric area centroid, upper-side bail and a thick shoulder connection.
# These remain separate so a future measured pendant can adjust its balance.
const MOON_COM = Vector2(-0.33865537,0.26339862)
const MOON_BAIL = Vector2(-0.54,-1.03)
const MOON_SHOULDER = Vector2(-0.55,-0.60)
const BELL_VOICES = 12

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
var crescent_outline := PackedVector2Array()
var stars: Array[Dictionary] = []
var players: Array[AudioStreamPlayer] = []
var audio_base: Array[float] = []
var audio_gain: Array[float] = []
var audio_from: Array[float] = []
var audio_to: Array[float] = []
var audio_age: Array[float] = []
var audio_duration: Array[float] = []
var audio_stop_after: Array[bool] = []
var sounds: Array[AudioStreamWAV] = []
var sound_banks: Array = []
var echo_banks: Array = []
var coda_started := false
var night_music
var palette_index := 0
var palette_from := 0
var palette_mix := 1.0
var palette_origin: Dictionary = {}
var garden_energy := 0.0
var garden_lights: Array[float] = [0,0,0,0,0,0,0]
var garden_flight_cooldowns: Array[float] = [0,0,0,0,0,0,0]
var journey_resume: Dictionary = {}
var listening_resume: Dictionary = {}
var garden_scene: Dictionary = {}
var last_turn := 0.0
var has_last_turn := false
var last_echo_turns: Array[float] = [0,0]
var has_last_echo_turn: Array[bool] = [false,false]
var turn_advice: Array[Dictionary] = []
var miss_streak := 0
var advice_cast := -1
const TURN_ADVICE_SECONDS = 1.8
var last_pull_note := -1
var pull_note_cooldown := 0.0
var voice := 0
var start_rect := Rect2()
var tour_rect := Rect2()
var help_restart_rect := Rect2()
var retry_rect := Rect2()
var next_rect := Rect2()
var reset_rect := Rect2()
var mute_rect := Rect2()
var help_rect := Rect2()
var pause_rect := Rect2()
var stage_rect := Rect2()
var best_chapters: Array = [0, 0, 0, 0, 0]
var testing := false
var save_revision := 0
var duet_hits: Array[bool] = [false, false]
var duet_checked: Array[bool] = [false, false]
var duet_errors: Array[float] = [0.0, 0.0]
var duet_offsets: Array[float] = [0.0, 0.0]
var reduced_motion := false
var echoes: Array[Dictionary] = []
var chain_rings := 0
var harmonic_time := 0.0
var state_clock := 0.0
var transition_phase := 0
var transition_time := 0.0
var transition_action := ""
var transition_chapter := 0
var transition_resume: Dictionary = {}
const TRANSITION_OUT = 0.32
const TRANSITION_IN = 0.34
var cadence_notes: Array[Dictionary] = []
var free_play := false
var gravity_index := 1
var saved_gravity_index := 1
const GRAVITY_FACTORS = [0.64, 1.0, 1.4884]
const GRAVITY_NAMES = ["重力 弱", "重力 標準", "重力 強"]

func _ready() -> void:
	Engine.max_fps = 60
	RenderingServer.set_default_clear_color(INK)
	var rng := RandomNumberGenerator.new()
	rng.seed = 81204
	for i in range(58):
		stars.append({"x": rng.randf(), "y": rng.randf(), "r": rng.randf_range(0.7, 1.8), "phase": rng.randf_range(0.0, TAU)})
	for prefix in ["bell","warm","air"]:
		var bank: Array[AudioStreamWAV] = []
		for i in range(7):
			bank.append(load("res://assets/audio/%s_%d.wav" % [prefix,i]))
		sound_banks.append(bank)
		var echoes_bank: Array[AudioStreamWAV] = []
		for name in ["left_low","right_low","left_high","right_high"]:
			echoes_bank.append(load("res://assets/audio/%s_echo_%s.wav" % [prefix,name]))
		echo_banks.append(echoes_bank)
	for stream in sound_banks[0]:
		sounds.append(stream)
	# Keep the physical bell pool independent of the continuing night score.
	for i in range(BELL_VOICES):
		var player := AudioStreamPlayer.new()
		player.volume_db = -7.0
		add_child(player)
		players.append(player)
		audio_base.append(-13.0)
		audio_gain.append(1.0)
		audio_from.append(1.0)
		audio_to.append(1.0)
		audio_age.append(0.0)
		audio_duration.append(0.0)
		audio_stop_after.append(false)
	night_music = NIGHT_MUSIC.new()
	add_child(night_music)
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

func _cancel_aim() -> void:
	_clear_turn_advice()
	if dragging:
		dragging = false
		keyboard_aim = false
		theta = 0.0
		omega = 0.0
		trail.clear()

func _pause_for_focus_loss() -> void:
	_cancel_aim()
	paused = true
	dragging = false
	keyboard_aim = false
	_stop_audio(true)
	_save()
	_publish_state()

func _on_web_visibility_changed(_arguments: Array) -> void:
	if started and web_document != null and bool(web_document.hidden):
		_pause_for_focus_loss()

func _exit_tree() -> void:
	_stop_audio(true)
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
	var bw := minf(220.0,(size.x-80.0)/2.0)
	retry_rect = Rect2(size.x * 0.5 - bw - 8.0, bottom_y - 20.0, bw, 72.0)
	next_rect = Rect2(size.x * 0.5 + 8.0, bottom_y - 20.0, bw, 72.0)
	reset_rect = Rect2(28.0, 72.0, 100.0, 66.0)
	if started and not free_play:
		if chapter_done:
			reset_rect = Rect2()
			if chapter==CHAPTERS.size()-1:
				retry_rect = Rect2()
				next_rect = Rect2(size.x*0.5-110.0,bottom_y-20.0,220.0,72.0)
		else:
			retry_rect = Rect2(size.x*0.5-110.0,bottom_y-20.0,220.0,72.0)
			next_rect = Rect2()
	mute_rect = Rect2(size.x - 128.0, 20.0, 104.0, 66.0)
	help_rect = Rect2(size.x - 202.0, 20.0, 66.0, 66.0)
	pause_rect = Rect2(size.x - 276.0, 20.0, 66.0, 66.0)
	var start_y := clampf(pivot.y+length+91.0,size.y*0.55,size.y-180.0)
	start_rect = Rect2(size.x * 0.5 - 72.0, start_y, 144.0, 66.0)
	tour_rect = Rect2(size.x*0.5-100.0,start_rect.end.y+20.0,200.0,66.0)
	help_restart_rect = Rect2(size.x*0.5-126.0,size.y*0.26+470.0,252.0,66.0)

func _target() -> float:
	if chapter_done or free_play:
		return 0.0
	return float(CHAPTERS[chapter]["targets"][progress])

func _point(angle: float, radius: float = -1.0) -> Vector2:
	var r := length if radius < 0.0 else radius
	return pivot + Vector2(sin(angle), cos(angle)) * r

func _process(delta: float) -> void:
	_advance_audio_envelopes(delta)
	night_music.advance(delta,started and not free_play and not muted and not paused and not show_help and transition_phase!=1,_transition_audio_gain())
	state_clock += delta
	if state_clock >= 0.5:
		state_clock = 0.0
		_publish_state()
	if not paused and not show_help:
		_advance_transition(delta)
		elapsed += delta
		palette_mix = minf(1.0, palette_mix + delta * 0.58)
		pull_note_cooldown = maxf(0.0, pull_note_cooldown-delta)
		if free_play:
			garden_energy = maxf(0.0, garden_energy-delta*0.004)
			for i in range(7):
				garden_lights[i] = maxf(0.0, garden_lights[i]-delta*0.012)
				garden_flight_cooldowns[i] = maxf(0.0,garden_flight_cooldowns[i]-delta)
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
		for cue in turn_advice:
			cue["remaining"] -= delta
		turn_advice = turn_advice.filter(func(cue): return float(cue["remaining"])>0.0)
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
	if not started or paused or show_help or transition_phase!=0:
		return
	_echo_physics(delta)
	if dragging or not swinging:
		return
	var previous_theta := theta
	var previous_omega := omega
	omega += (-PHYSICS_RATE * float(GRAVITY_FACTORS[gravity_index]) * sin(theta) - (0.22 if free_play else DAMPING) * omega) * delta
	theta += omega * delta
	cast_seconds += delta
	if previous_theta * theta < 0.0:
		cast_crossed_center = true
	for i in range(7):
		var a: float = BELL_ANGLES[i]
		if ((previous_theta - a) * (theta - a) <= 0.0) and absf(omega) > 0.12 and bell_cooldowns[i] <= 0.0:
			_ring(i, clampf(absf(omega) * 0.35, 0.3, 1.0))
	if cast_crossed_center and previous_omega * omega < 0.0:
		if not has_last_turn:
			last_turn = theta
			has_last_turn = true
		if not cast_judged:
			_judge_turn()
	if not reduced_motion:
		trail.append(_point(theta))
		if trail.size() > 115:
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
	if free_play:
		garden_energy = minf(1.0, garden_energy + strength * 0.028)
		garden_lights[index] = minf(1.0, garden_lights[index] + strength * 0.48)
		if garden_flight_cooldowns[index] <= 0.0 and not reduced_motion:
			light_flights.append({"from":_point(float(BELL_ANGLES[index]),length+15.0),"index":index,"age":0.0})
			garden_flight_cooldowns[index] = 1.4
	if chapter > 0 or _goal_kind() in ["relay","duet"]:
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
	if not reduced_motion:
		ripples.append({"pos": pos, "age": 0.0, "strength": strength})
	if not reduced_motion:
		for i in range(5):
			var a := float(i) * TAU / 5.0 + elapsed
			particles.append({"pos": pos, "velocity": Vector2(cos(a), sin(a)) * 33.0, "life": 0.9, "color": _tone_color("teal")})


func _reset_echoes() -> void:
	echoes = [
		{"side":0, "theta":0.0, "omega":0.0, "charged":false, "glow":0.0, "cooldown":0.0, "stored":0.0, "cast_id":-1, "judged_cast":-1},
		{"side":1, "theta":0.0, "omega":0.0, "charged":false, "glow":0.0, "cooldown":0.0, "stored":0.0, "cast_id":-1, "judged_cast":-1}
	]
	chain_rings = 0
	duet_hits = [false, false]
	duet_checked = [false, false]
	duet_errors = [0.0, 0.0]
	duet_offsets = [0.0, 0.0]

func _echo_pivot(side: int) -> Vector2:
	var spacing := 0.32 if _goal_kind() in ["relay", "duet"] else 0.73
	return pivot + Vector2((-1.0 if side == 0 else 1.0) * length * spacing, length * 0.11)

func _echo_length() -> float:
	return length * (0.42 if _goal_kind() in ["relay", "duet"] else 0.26)

func _echo_point(side: int, angle: float) -> Vector2:
	return _echo_pivot(side) + Vector2(sin(angle), cos(angle)) * _echo_length()

func _goal_kind() -> String:
	if free_play:
		return "free"
	if CHAPTERS[chapter].has("kinds"):
		var kinds: Array = CHAPTERS[chapter]["kinds"]
		return str(kinds[mini(progress,kinds.size()-1)])
	return str(CHAPTERS[chapter].get("kind","main"))

func _echo_target(side: int) -> float:
	if _goal_kind() == "duet":
		return (-1.0 if side == 0 else 1.0) * absf(_target()) * 0.96
	return _target()

func _clear_turn_advice() -> void:
	turn_advice.clear()
	miss_streak = 0
	advice_cast = -1

func _record_turn_advice(side: int, angle: float, target: float, word: String = "") -> void:
	if advice_cast!=casts:
		miss_streak += 1
		advice_cast = casts
	if word.is_empty():
		word = "反対側から" if signf(angle)!=signf(target) else ("もう少し大きく" if absf(angle)<absf(target) else "少しやさしく")
	turn_advice = turn_advice.filter(func(cue): return int(cue["side"])!=side)
	turn_advice.append({"side":side,"angle":angle,"target":target,"remaining":TURN_ADVICE_SECONDS,"word":word if miss_streak>=2 else ""})
	feedback_timer = 0.0

func _turn_advice_for(side: int) -> Dictionary:
	for cue in turn_advice:
		if int(cue["side"])==side:
			return cue
	return {}

func _turn_advice_word_rect(cue: Dictionary) -> Rect2:
	if str(cue["word"]).is_empty():
		return Rect2()
	var side := int(cue["side"])
	var font_size := 17 if side<0 else 15
	var width := FONT.get_string_size(str(cue["word"]),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var at := _point(float(cue["angle"])) if side<0 else _echo_point(side,float(cue["angle"]))
	var blockers: Array[Rect2] = []
	for i in range(7):
		var bell_at := _point(float(BELL_ANGLES[i]),length+15.0)
		blockers.append(Rect2(bell_at-Vector2(17,17),Vector2(34,34)))
		if _pitch_labels_visible():
			var note_width := FONT.get_string_size(NOTE_NAMES[i],HORIZONTAL_ALIGNMENT_LEFT,-1,11).x
			var note_at := bell_at+Vector2(0,35)
			blockers.append(Rect2(note_at-Vector2(note_width*0.5+6,16),Vector2(note_width+12,22)))
	for e in echoes:
		if chapter==0 and _goal_kind()=="main":
			continue
		var echo_side := int(e["side"])
		var ep := _echo_pivot(echo_side)
		blockers.append(Rect2(ep-Vector2(13,13),Vector2(26,26)))
		if side<0 and _goal_kind() in ["relay","duet"]:
			# An uncharged moon can remain still for the whole comparison.
			blockers.append(Rect2(_echo_point(echo_side,0.0)-Vector2(18,18),Vector2(36,36)))
			if _goal_kind()=="duet" or echo_side==(0 if _target()<0.0 else 1):
				blockers.append(Rect2(_echo_point(echo_side,_echo_target(echo_side))-Vector2(21,21),Vector2(42,42)))
		if _pitch_labels_visible():
			blockers.append(Rect2(ep+Vector2(-20,_echo_length()+29),Vector2(40,22)))
	var rect := Rect2()
	var outward := signf(at.x-size.x*0.5)
	var above := -44.0 if side<0 else -32.0
	var below := 68.0 if side<0 else 50.0
	# Choose against fixed scenery so the word stays still while moons move.
	for vertical_offset in [above,below,above-24.0,above-48.0,above-72.0]:
		for move in [0.0,width*0.5+18.0,width+24.0]:
			var baseline := Vector2(clampf(at.x+outward*move,width*0.5+18.0,size.x-width*0.5-18.0),at.y+vertical_offset)
			var candidate := Rect2(baseline-Vector2(width*0.5,font_size*1.1),Vector2(width,font_size*1.3))
			if Rect2(Vector2.ZERO,size).encloses(candidate) and not blockers.any(func(other): return candidate.intersects(other)):
				rect = candidate
				break
		if rect.has_area():
			break
	# Hide briefly when a moving pendant crosses the chosen word's space.
	if rect.intersects(Rect2(_point(theta)-Vector2(36,36),Vector2(72,72))):
		return Rect2()
	for e in echoes:
		if chapter==0 and _goal_kind()=="main":
			continue
		if rect.intersects(Rect2(_echo_point(int(e["side"]),float(e["theta"]))-Vector2(15,15),Vector2(30,30))):
			return Rect2()
	return rect

func _draw_turn_advice() -> void:
	if not started or free_play or chapter_done or transition_phase!=0:
		return
	for cue in turn_advice:
		var side := int(cue["side"])
		var origin := pivot if side<0 else _echo_pivot(side)
		var radius := length if side<0 else _echo_length()
		var at := _point(float(cue["angle"])) if side<0 else _echo_point(side,float(cue["angle"]))
		var a := PI*0.5-float(cue["angle"])
		var b := PI*0.5-float(cue["target"])
		var alpha := 1.0 if reduced_motion else minf(1.0,float(cue["remaining"])/0.25)
		draw_arc(at,8.0 if side<0 else 6.0,0.0,TAU,24,Color(WHITE,0.88*alpha),2.0,true)
		if absf(a-b)>0.01:
			draw_arc(origin,radius,minf(a,b),maxf(a,b),32,Color(WHITE,0.46*alpha),2.0,true)
		var word_rect := _turn_advice_word_rect(cue)
		if word_rect.has_area():
			var font_size := 17 if side<0 else 15
			_text(str(cue["word"]),Vector2(word_rect.get_center().x,word_rect.position.y+font_size*1.1),font_size,Color(WHITE,alpha),true)

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
		e["omega"] += (-11.4 * float(GRAVITY_FACTORS[gravity_index]) * sin(float(e["theta"])) - 0.50 * float(e["omega"])) * delta
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
			_play_echo(int(e["side"]),clampf(absf(float(e["omega"])) * 0.17,0.25,0.60))
			if not reduced_motion:
				ripples.append({"pos": _echo_pivot(int(e["side"])) + Vector2(0.0, _echo_length()), "age":0.0, "strength":0.6})

func _draw_echoes() -> void:
	if not started or (chapter == 0 and _goal_kind() == "main"):
		return
	for e in echoes:
		var side: int = e["side"]
		var ep := _echo_pivot(side)
		var el := _echo_length()
		var bob := ep + Vector2(sin(float(e["theta"])), cos(float(e["theta"]))) * el
		var glow: float = e["glow"]
		var feed := _point(-0.66 if side == 0 else 0.66, length + 15.0)
		var wire_color := _tone_color("gold") if e["charged"] else Color("355358")
		draw_line(feed, ep + Vector2(0.0, el + 20.0), Color(wire_color, 0.55), 1.0, true)
		draw_line(ep + Vector2(0.0, el + 20.0), ep, Color(wire_color, 0.55), 1.0, true)
		draw_arc(ep, el, PI*0.5-0.9, PI*0.5+0.9, 32, Color(0.39,0.62,0.59,0.12), 1.0, true)
		draw_circle(ep, 4.0, _tone_color("gold") if e["charged"] else MUTED)
		_draw_moon(ep,bob,float(e["theta"]),10.0,Color("6a9690").lerp(_tone_color("teal"),glow),glow*1.3,Color("80a497"),1.0)
		if not chapter_done and _goal_kind() in ["relay", "duet"]:
			if _goal_kind() == "duet" or side == (0 if _target() < 0.0 else 1):
				var target_angle := _echo_target(side)
				var beacon := _echo_point(side, target_angle)
				_glow(beacon, 18.0, _tone_color("gold"), 1.4)
				draw_arc(beacon, 20.0 if reduced_motion else 20.0 + sin(elapsed * 2.5) * 1.2, 0.0, TAU, 32, _tone_color("gold"), 1.5, true)
				draw_arc(ep, el, PI*0.5-target_angle-0.095, PI*0.5-target_angle+0.095, 14, Color(0.91,0.80,0.50,0.32), 4.0, true)
				if _goal_kind()=="duet" and duet_hits[side] and not cast_judged:
					draw_circle(beacon,5.0,_tone_color("gold"))
				if has_last_echo_turn[side] and (not swinging or cast_judged or dragging) and _turn_advice_for(side).is_empty():
					var previous := _echo_point(side,last_echo_turns[side])
					draw_arc(previous,6.0,0.0,TAU,20,Color(WHITE,0.50),1.0,true)
		if _pitch_labels_visible():
			_text(("D4" if side==0 else "B4") if chapter<2 else ("F♯4" if side==0 else "D5"),ep+Vector2(0.0,el+45.0),11,MUTED,true)

func _tone_color(key: String) -> Color:
	var a: Color = palette_origin.get(key,PALETTES[palette_from][key])
	var b: Color = PALETTES[palette_index][key]
	return a.lerp(b,palette_mix*palette_mix*(3.0-2.0*palette_mix))

func _cycle_palette() -> void:
	var current: Dictionary = {}
	for key in ["ink","deep","gold","teal"]:
		current[key] = _tone_color(key)
	palette_origin = current
	palette_from = palette_index
	palette_index = (palette_index+1)%PALETTES.size()
	palette_mix = 0.0
	feedback = ["澄んだ鐘が、水面へひろがる。","柔らかな響きと、あたたかな灯り。","透きとおる響きで、夜が少し白む。"][palette_index]
	_save()
	_publish_state()

func _play_sample(stream: AudioStreamWAV, strength: float, base_db: float = -13.0) -> void:
	if muted or not started or paused or show_help:
		return
	night_music.duck()
	var slot := voice % BELL_VOICES
	voice += 1
	_play_voice(stream,strength,base_db,slot)

func _play_voice(stream: AudioStreamWAV, strength: float, base_db: float, slot: int) -> void:
	if muted or not started or paused or show_help:
		return
	var player := players[slot]
	player.stream = stream
	audio_base[slot] = base_db + strength*6.0
	audio_gain[slot] = _transition_audio_gain()
	audio_duration[slot] = 0.0
	audio_stop_after[slot] = false
	_apply_voice_gain(slot)
	player.play()
	if transition_phase==1:
		_fade_voice(slot,0.0,maxf(0.001,TRANSITION_OUT-transition_time))
	elif transition_phase==2:
		_fade_voice(slot,1.0,maxf(0.001,TRANSITION_IN-transition_time))

func _play_coda() -> void:
	if coda_started or free_play:
		return
	coda_started = true
	night_music.unlock(_music_piece_count(),true,_goal_kind()=="duet")

func _music_piece_count() -> int:
	var count := 0
	var score: Dictionary = CHAPTERS[chapter]
	var kinds: Array = score.get("kinds",[])
	for index in range(mini(progress,score["targets"].size())):
		var kind := str(kinds[index] if index<kinds.size() else score.get("kind","main"))
		count += 2 if kind=="duet" else 1
	return count

func _coda_light() -> float:
	if reduced_motion:
		return 0.65
	var pulse := 0.0
	for at in [0.06,0.44,0.72,1.16,1.74,2.16,2.66]:
		var distance := (finish_time-float(at))/0.24
		pulse += exp(-distance*distance)*0.50
	return 0.42+pulse

func _sound(index: int, strength: float = 0.8) -> void:
	_play_sample(sound_banks[palette_index][index],strength)

func _play_echo(side: int, strength: float) -> void:
	var index := side + (2 if chapter >= 2 else 0)
	_play_sample(echo_banks[palette_index][index],strength,-15.0)

func _preview_pull() -> void:
	var note := clampi(int(round((theta+0.96)/0.32)),0,6)
	if note != last_pull_note and pull_note_cooldown <= 0.0:
		last_pull_note = note
		pull_note_cooldown = 0.10
		_play_sample(sound_banks[1][note],0.25,-24.0)


func _apply_voice_gain(slot: int) -> void:
	players[slot].volume_db = audio_base[slot]+linear_to_db(maxf(0.0001,audio_gain[slot]))

func _fade_voice(slot: int, target: float, duration: float, stop_after: bool = false) -> void:
	audio_from[slot] = audio_gain[slot]
	audio_to[slot] = target
	audio_age[slot] = 0.0
	audio_duration[slot] = duration
	audio_stop_after[slot] = stop_after

func _advance_audio_envelopes(delta: float) -> void:
	for i in range(players.size()):
		if audio_duration[i]<=0.0:
			continue
		audio_age[i] += delta
		var t := clampf(audio_age[i]/audio_duration[i],0.0,1.0)
		var ease := t*t*(3.0-2.0*t)
		audio_gain[i] = lerpf(audio_from[i],audio_to[i],ease)
		_apply_voice_gain(i)
		if t>=1.0:
			audio_duration[i] = 0.0
			if audio_stop_after[i]:
				players[i].stop()
				audio_stop_after[i] = false

func _stop_audio(immediate: bool = false) -> void:
	night_music.suspend(immediate)
	for i in range(players.size()):
		if immediate:
			players[i].stop()
			audio_duration[i] = 0.0
			audio_gain[i] = 0.0
		elif players[i].playing:
			_fade_voice(i,0.0,0.035,true)

func _transition_audio_gain() -> float:
	if transition_phase==0:
		return 1.0
	var t := clampf(transition_time/(TRANSITION_OUT if transition_phase==1 else TRANSITION_IN),0.0,1.0)
	var ease := t*t*(3.0-2.0*t)
	return 1.0-ease if transition_phase==1 else ease

func _request_transition(action: String, index: int = 0) -> void:
	if action not in ["chapter","garden","journey","restart"] or (transition_phase!=0 and action!="restart"):
		return
	if action=="chapter" and (index<0 or index>=CHAPTERS.size()):
		return
	var continue_time := 0.0
	if transition_phase==1:
		continue_time = transition_time
	elif transition_phase==2:
		# Reverse the curtain at its present opacity, without a bright flash.
		continue_time = TRANSITION_OUT*(1.0-clampf(transition_time/TRANSITION_IN,0.0,1.0))
	_cancel_aim()
	transition_phase = 1
	transition_time = continue_time
	transition_action = action
	transition_chapter = index
	transition_resume = {}
	if action in ["chapter","restart"]:
		listening_resume = {}
		transition_resume = {"chapter":index if action=="chapter" else 0,"progress":0,"casts":0,"perfects":0}
	elif action=="garden" and not free_play:
		transition_resume = _snapshot_journey()
		_finish_cycle_for_garden()
	# Commit navigation intent now, not after the visual curtain. An immediate
	# refresh must not undo the explicit "start over" the player just chose.
	_save()
	night_music.leave(maxf(0.001,TRANSITION_OUT-transition_time)+TRANSITION_IN)
	for i in range(players.size()):
		if players[i].playing:
			var duration := maxf(0.001,TRANSITION_OUT-transition_time)
			_fade_voice(i,0.0,duration)
	_publish_state()

func _advance_transition(delta: float) -> void:
	if transition_phase==0:
		return
	transition_time += delta
	if transition_phase==1 and transition_time>=TRANSITION_OUT:
		transition_phase = 2
		transition_time -= TRANSITION_OUT
		match transition_action:
			"chapter": _new_chapter(transition_chapter)
			"garden": _enter_garden()
			"journey": _return_to_journey()
			"restart": _return_to_journey(true)
		_sound(2,0.30)
		transition_resume = {}
		_publish_state()
	if transition_phase==2 and transition_time>=TRANSITION_IN:
		transition_phase = 0
		transition_time = 0.0
		_publish_state()

func _judge_turn() -> void:
	if _goal_kind() in ["relay", "duet"]:
		var required_sides: Array = [0,1] if _goal_kind() == "duet" else [0 if _target() < 0.0 else 1]
		for side in required_sides:
			var e: Dictionary = echoes[side]
			if int(e["cast_id"]) != casts and not bool(e["charged"]):
				cast_judged = true
				feedback = "もう少し大きく引いて、外側の鐘へ。"
				feedback_timer = 5.0
				_record_turn_advice(-1,theta,signf(theta)*0.66,"もう少し大きく")
				_publish_state()
				return
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
		_record_turn_advice(-1,theta,target)
	_publish_state()

func _award_goal(error: float, where: Vector2) -> void:
	if chapter_done or free_play:
		return
	_clear_turn_advice()
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
	if not reduced_motion:
		for i in range(22):
			var a := float(i) * TAU / 22.0
			particles.append({"pos": pos, "velocity": Vector2(cos(a), sin(a)) * (65.0 + float(i % 3) * 22.0), "life": 1.7, "color": _tone_color("gold")})
	var previous_kind := _goal_kind()
	progress += 1
	var unit := "組" if previous_kind == "duet" else "つ"
	feedback = "星が %d/%d %s灯った。次の光へ。" % [progress,CHAPTERS[chapter]["targets"].size(),unit]
	if _goal_kind() != previous_kind:
		has_last_turn = false
		has_last_echo_turn = [false,false]
		feedback = "星が灯った。今度は小さな月へ。"
	_sound(4, 0.72)
	if progress >= CHAPTERS[chapter]["targets"].size():
		chapter_done = true
		finish_time = 0.0
		feedback = "星座が灯った。夜に、旋律が残った。"
		var rating := 3 if casts <= progress + 1 else (2 if casts <= progress * 2 else 1)
		best_chapters[chapter] = maxi(int(best_chapters[chapter]), rating)
		_save()
		_play_coda()
	else:
		night_music.unlock(_music_piece_count(),false,previous_kind=="duet")
	_save()
	_layout()
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
	last_echo_turns[side] = angle
	has_last_echo_turn[side] = true
	var error := absf(angle - target)
	if kind == "relay":
		cast_judged = true
		if error <= 0.095:
			_award_goal(error, _echo_point(side, target))
		else:
			feedback = "鐘へ、もう少し強く力を渡そう。" if absf(angle) < absf(target) else "少し小さく引くと、小さな月が光へ届く。"
			_record_turn_advice(side,angle,target)
	else:
		duet_checked[side] = true
		duet_errors[side] = error
		duet_offsets[side] = absf(angle) - absf(target)
		duet_hits[side] = error <= 0.095
		if not duet_hits[side]:
			_record_turn_advice(side,angle,target)
		if duet_hits[side]:
			feedback = "一つ届いた！ もう一つの月を聴こう。"
			_sound(4, 0.5)
			night_music.reply(casts,side)
		if duet_checked[0] and duet_checked[1]:
			cast_judged = true
			if duet_hits[0] and duet_hits[1]:
				_award_goal(maxf(duet_errors[0], duet_errors[1]), _echo_point(side, target))
			elif duet_offsets[0] < 0.0 and duet_offsets[1] < 0.0:
				night_music.clear_replies()
				feedback = "二つの月へ、もう少し強く力を渡そう。"
			elif duet_offsets[0] > 0.0 and duet_offsets[1] > 0.0:
				night_music.clear_replies()
				feedback = "少しやさしく。二つの月を光へ。"
			else:
				night_music.clear_replies()
				feedback = "二つの月が、光で折り返す強さを探そう。"
	feedback_timer = 5.0
	if not turn_advice.is_empty():
		feedback_timer = 0.0
	_publish_state()

func _begin_pull(pos: Vector2) -> void:
	if chapter_done or show_help or paused:
		return
	turn_advice.clear()
	dragging = true
	keyboard_aim = false
	swinging = false
	omega = 0.0
	trail.clear()
	_update_pull(pos)

func _set_pull_angle(angle: float) -> void:
	# All present inputs share a single angle boundary, independent of expression.
	theta = clampf(angle,-MAX_PULL,MAX_PULL)
	_preview_pull()

func _advance_keyboard_aim(delta: float, direction: float) -> void:
	if dragging and keyboard_aim and not paused and not show_help:
		_set_pull_angle(theta + direction * delta * 0.80)

func _update_pull(pos: Vector2) -> void:
	var v := pos - pivot
	if v.y < 25.0:
		v.y = 25.0
	_set_pull_angle(atan2(v.x,v.y))

func _release() -> void:
	if paused or show_help:
		_cancel_aim()
		return
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
	turn_advice.clear()
	has_last_turn = false
	has_last_echo_turn = [false,false]
	cast_start_angle = theta
	omega = 0.0
	swinging = true
	cast_crossed_center = false
	cast_judged = false
	cast_seconds = 0.0
	feedback = "月が光に届く、その一瞬を聴こう。" if not free_play else "鐘から振り子へ、あなたの音がつながる。"
	feedback_timer = 3.0
	if _goal_kind() in ["relay", "duet"]:
		_reset_echoes()
		feedback = "鐘から小さな月へ、力がつながっていく。"
		if _goal_kind() == "relay" and signf(theta) != signf(_target()):
			cast_judged = true
			feedback = "光のある側から、放してみよう。"
	_save()
	_publish_state()

func _resume_chapter() -> int:
	for i in range(CHAPTERS.size()):
		if int(best_chapters[i]) == 0:
			return i
	return CHAPTERS.size()

func _finish_cycle_for_garden() -> void:
	# A completed V may be restored for listening until the player chooses
	# the garden. That explicit exit ends the cycle, including legacy saves.
	if (not free_play and chapter_done and chapter==CHAPTERS.size()-1) or int(listening_resume.get("chapter",-1))==CHAPTERS.size()-1:
		listening_resume = {}
		journey_resume = {"chapter":0,"progress":0,"casts":0,"perfects":0}

func _journey_entry_label(intro: bool = false) -> String:
	if intro and not listening_resume.is_empty():
		return "音のつづき"
	var fresh_cycle := journey_resume.is_empty() or (int(journey_resume.get("chapter",0))==0 and int(journey_resume.get("progress",0))==0 and int(journey_resume.get("casts",0))==0)
	if listening_resume.is_empty() and _resume_chapter()==CHAPTERS.size() and fresh_cycle:
		return "もう一度"
	if not journey_resume.is_empty() or _resume_chapter()>0:
		return "星のつづき" if intro else "つづきへ"
	return "星を灯す遊び"

func _snapshot_journey() -> Dictionary:
	if chapter_done:
		return {"chapter":(chapter+1)%CHAPTERS.size(),"progress":0,"casts":0,"perfects":0}
	return {"chapter":chapter,"progress":progress,"casts":casts,"perfects":perfects}

func _start_art() -> void:
	started = true
	_enter_garden(false)
	_sound(2,0.5)

func _start() -> void:
	started = true
	_return_to_journey()
	_sound(2,0.5)

func _enter_garden(capture: bool = true) -> void:
	if capture and not free_play:
		journey_resume = _snapshot_journey()
	_finish_cycle_for_garden()
	_new_chapter(CHAPTERS.size())
	if garden_scene.has("lights"):
		garden_lights.assign(garden_scene["lights"])
		garden_energy = float(garden_scene.get("energy",0.0))
	feedback = "月を引いて、あなたの夜を奏でよう。"
	_save()
	_publish_state()

func _return_to_journey(restart: bool = false) -> void:
	if free_play:
		garden_scene = {"lights":garden_lights.duplicate(),"energy":garden_energy}
		_finish_cycle_for_garden()
	var resume: Dictionary = journey_resume if not restart else {}
	var listening: Dictionary = listening_resume.duplicate() if not restart else {}
	if restart:
		listening_resume = {}
	var index: int = int(listening.get("chapter",resume.get("chapter",0 if restart else _resume_chapter())))
	if index >= CHAPTERS.size():
		index = 0
	_new_chapter(index)
	progress = clampi(int(resume.get("progress",0)),0,CHAPTERS[chapter]["targets"].size()-1)
	casts = maxi(0,int(resume.get("casts",0)))
	perfects = maxi(0,int(resume.get("perfects",0)))
	if not listening.is_empty():
		progress = CHAPTERS[chapter]["targets"].size()
		casts = int(listening["casts"])
		perfects = int(listening["perfects"])
		chapter_done = true
		coda_started = true
		finish_time = 7.0
	night_music.restore(_music_piece_count(),chapter_done)
	_layout()
	feedback = "金の輪で折り返すと、上の星が灯る。" if _goal_kind()=="main" else "鐘の力を、小さな月の光へ届けよう。"
	if chapter_done:
		feedback_timer = 0.0
	_save()
	_publish_state()


func _retry(clear_cadence: bool = true) -> void:
	turn_advice.clear()
	night_music.clear_replies()
	dragging = false
	keyboard_aim = false
	swinging = false
	omega = 0.0
	theta = 0.0
	trail.clear()
	_reset_echoes()
	if clear_cadence:
		cadence_notes.clear()
	feedback = "光の反対側へ引いて、もうひと振り。" if not free_play else "光のない夜を、好きな音で奏でよう。"
	feedback_timer = 3.0
	if _goal_kind() == "relay":
		feedback = "光のある小さな月の側へ、もうひと振り。"
	elif _goal_kind() == "duet":
		feedback = "左でも右でも、二つの月へ。"
	_publish_state()

func _new_chapter(index: int) -> void:
	_clear_turn_advice()
	free_play = index == CHAPTERS.size()
	chapter = 2 if free_play else clampi(index, 0, CHAPTERS.size()-1)
	if free_play:
		night_music.leave(TRANSITION_OUT+TRANSITION_IN)
	else:
		night_music.begin(chapter)
	gravity_index = saved_gravity_index if free_play else 1
	has_last_turn = false
	has_last_echo_turn = [false,false]
	last_pull_note = -1
	progress = 0
	casts = 0
	perfects = 0
	chapter_done = false
	coda_started = false
	finish_time = 0.0
	particles.clear()
	light_flights.clear()
	ripples.clear()
	_retry(false)
	_layout()
	if free_play:
		feedback = "光のない夜を、好きな音で奏でよう。"
	elif _goal_kind() == "relay":
		feedback = "鐘から小さな月へ、力を届けよう。"
	elif _goal_kind() == "duet":
		feedback = "左でも右でも、二つの月を光へ。"

func _toggle_mute() -> void:
	muted = not muted
	if muted:
		_stop_audio()
	_save()
	_publish_state()

func _input(event: InputEvent) -> void:
	if transition_phase!=0 and not show_help:
		var interruption := false
		if event is InputEventKey:
			interruption = event.keycode in [KEY_M,KEY_P,KEY_ESCAPE,KEY_H]
		elif event is InputEventMouseButton and event.pressed:
			interruption = mute_rect.has_point(event.position) or pause_rect.has_point(event.position) or help_rect.has_point(event.position)
		if not interruption:
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var pos: Vector2 = event.position
			if not started:
				if start_rect.has_point(pos):
					_start_art()
				elif tour_rect.has_point(pos):
					_start()
				return
			if show_help:
				show_help = false
				if help_restart_rect.has_point(pos):
					paused = false
					_request_transition("restart")
				_publish_state()
				return
			if paused:
				if pause_rect.has_point(pos):
					paused = false
					_publish_state()
				return
			if mute_rect.has_point(pos):
				_toggle_mute()
			elif help_rect.has_point(pos):
				show_help = not show_help
				if show_help:
					_cancel_aim()
					_stop_audio()
				_publish_state()
			elif pause_rect.has_point(pos):
				paused = not paused
				if paused:
					_cancel_aim()
					_stop_audio()
				_publish_state()
			elif show_help:
				show_help = false
				_publish_state()
			elif retry_rect.has_point(pos):
				if free_play:
					_request_transition("journey")
				elif chapter_done:
					_request_transition("garden")
				else:
					_new_chapter(chapter) if chapter_done else _retry()
			elif (chapter_done or free_play) and next_rect.has_point(pos):
				if free_play:
					_cycle_palette()
				elif chapter+1 >= CHAPTERS.size():
					_request_transition("garden")
				else:
					_request_transition("chapter",chapter+1)
			elif reset_rect.has_point(pos):
				if free_play:
					gravity_index = (gravity_index + 1) % GRAVITY_FACTORS.size()
					_save()
					_publish_state()
				else:
					_request_transition("garden")
			elif stage_rect.has_point(pos) and not paused:
				_begin_pull(pos)
		else:
			_release()
	elif event is InputEventMouseMotion and dragging and not keyboard_aim and not paused and not show_help:
		_update_pull(event.position)
	elif event is InputEventKey and event.pressed:
		if event.echo:
			return
		if paused and event.keycode not in [KEY_P, KEY_ESCAPE, KEY_M, KEY_H]:
			return
		if show_help and event.keycode == KEY_ESCAPE:
			show_help = false
			_publish_state()
			return
		if show_help and event.keycode not in [KEY_H, KEY_ESCAPE, KEY_M]:
			return
		if not started:
			if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
				_start_art()
			return
		match event.keycode:
			KEY_M:
				_toggle_mute()
			KEY_H:
				show_help = not show_help
				if show_help:
					_cancel_aim()
					_stop_audio()
				_publish_state()
			KEY_P, KEY_ESCAPE:
				paused = not paused
				if paused:
					_cancel_aim()
					_stop_audio()
				_publish_state()
			KEY_R:
				_request_transition("chapter",chapter) if chapter_done else _retry()
			KEY_N:
				if free_play:
					_cycle_palette()
			KEY_ENTER:
				if free_play:
					_request_transition("journey")
				elif chapter_done:
					_request_transition("garden") if chapter+1>=CHAPTERS.size() else _request_transition("chapter",chapter+1)
			KEY_LEFT, KEY_RIGHT:
				if not chapter_done and not paused:
					if not dragging:
						if free_play:
							swinging = false
							omega = 0.0
							trail.clear()
						else:
							_retry()
						dragging = true
					keyboard_aim = true
					var direction := -1.0 if event.keycode == KEY_LEFT else 1.0
					_set_pull_angle(theta + direction*0.06)
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
	var fill := Color("c5e5d5") if primary else _tone_color("deep").darkened(0.18)
	var color := INK if primary else WHITE
	if disabled:
		fill = Color("0d2430")
		color = Color("46606b")
	_panel(rect, fill, Color("33515b") if not primary else Color.TRANSPARENT, 10.0)
	var font_size := 20
	while font_size>14 and FONT.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>rect.size.x-16.0:
		font_size -= 1
	_text(label,Vector2(rect.get_center().x,rect.position.y+rect.size.y*0.64),font_size,color,true)

func _pause_button() -> void:
	_panel(pause_rect,_tone_color("deep").darkened(0.18),Color("33515b"),10.0)
	var center := pause_rect.get_center()
	if paused:
		draw_colored_polygon(PackedVector2Array([center+Vector2(-8,-12),center+Vector2(-8,12),center+Vector2(12,0)]),WHITE)
	else:
		draw_rect(Rect2(center+Vector2(-11,-12),Vector2(7,24)),WHITE)
		draw_rect(Rect2(center+Vector2(4,-12),Vector2(7,24)),WHITE)

func _crescent_shape() -> PackedVector2Array:
	if crescent_outline.is_empty():
		# Trace the outer exposed arc, then the inner arc between intersections.
		# This is one concave polygon, with actual empty sky in the missing part.
		var offset := Vector2(0.36,-0.28)
		var distance := offset.length()
		var direction := offset.angle()
		var intersection := (1.0-0.84*0.84+distance*distance)/(2.0*distance)
		var outer := acos(intersection)
		var inner := acos((intersection-distance)/0.84)
		for i in range(65):
			var angle := direction+outer+(TAU-2.0*outer)*float(i)/64.0
			crescent_outline.append(Vector2(cos(angle),sin(angle)))
		for i in range(1,64):
			var angle := direction+TAU-inner-(TAU-2.0*inner)*float(i)/64.0
			crescent_outline.append(offset+Vector2(cos(angle),sin(angle))*0.84)
	return crescent_outline

func _moon_rotation(angle: float) -> float:
	# The bail-to-centroid vector rests downwards, then follows the swing.
	var balance := MOON_COM-MOON_BAIL
	return -angle+atan2(balance.x,balance.y)

func _moon_origin(mass_pos: Vector2, angle: float, radius: float) -> Vector2:
	return mass_pos-MOON_COM.rotated(_moon_rotation(angle))*radius

func _draw_moon(anchor: Vector2, mass_pos: Vector2, angle: float, radius: float, color: Color, glow: float, strand: Color, line_width: float = 1.8) -> void:
	var rotation := _moon_rotation(angle)
	var origin := _moon_origin(mass_pos,angle,radius)
	var ring_center := origin+MOON_BAIL.rotated(rotation)*radius
	var ring_radius := maxf(1.5,radius*0.10)
	var connection := ring_center+(anchor-ring_center).normalized()*ring_radius
	draw_line(anchor,connection,strand,line_width,true)
	_glow(origin,radius,color,glow)
	var shoulder := origin+MOON_SHOULDER.rotated(rotation)*radius
	var ring_bottom := ring_center+Vector2(0,ring_radius).rotated(rotation)
	draw_line(shoulder,ring_bottom,color,maxf(1.2,radius*0.08),true)
	var points := PackedVector2Array()
	for point in _crescent_shape():
		points.append(origin+point.rotated(rotation)*radius)
	draw_colored_polygon(points,color)
	points.append(points[0])
	draw_polyline(points,color,0.8,true)
	draw_arc(ring_center,ring_radius,0,TAU,24,color,1.2,true)

func _glow(pos: Vector2, radius: float, color: Color, strength: float = 1.0) -> void:
	if strength<=0.0:
		return
	# Small overlapping steps keep the glow soft at desktop and phone scales.
	for i in range(28, 0, -1):
		var t := float(i) / 28.0
		var c := color
		c.a = 0.630 * strength * (1.0 - t) / 28.0
		draw_circle(pos, radius * (1.05 + t * 1.70), c)

func _draw() -> void:
	if size.x <= 0.0:
		return
	_draw_background()
	_draw_sky_constellation()
	_draw_stage()
	_draw_echoes()
	_draw_turn_advice()
	_draw_light_flights()
	_draw_header()
	if started:
		_draw_score()
		if retry_rect.size.x>0.0:
			_button(retry_rect, _journey_entry_label() if free_play else ("庭で奏でる" if chapter_done else "引き直す  R"))
		if next_rect.size.x>0.0:
			_button(next_rect, "夜を変える" if free_play else ("庭で奏でる" if chapter==CHAPTERS.size()-1 else "次の夜へ"), true)
	else:
		_draw_intro()
	if transition_phase!=0:
		var t := clampf(transition_time/(TRANSITION_OUT if transition_phase==1 else TRANSITION_IN),0.0,1.0)
		var ease := t*t*(3.0-2.0*t)
		draw_rect(Rect2(Vector2.ZERO,size),Color(_tone_color("ink"),ease if transition_phase==1 else 1.0-ease))
	if show_help and started:
		_draw_help()
	if paused and started and not show_help:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.03, 0.04, 0.78))
		_text("ひと休み", Vector2(size.x * 0.5, size.y * 0.46), 38, _tone_color("gold"), true)
		_text("P または右上で、夜を再開", Vector2(size.x * 0.5, size.y * 0.46 + 47.0), 21, WHITE, true)
		_pause_button()

func _sky_position(index: int) -> Vector2:
	var count: int = 7 if free_play else CHAPTERS[chapter]["targets"].size()
	var span := minf(size.x * 0.60, 350.0)
	var t := float(index) / float(maxi(1,count-1))
	var sky_y := 109.0 + maxf(0.0, pivot.y - 220.0) * 0.40
	if size.y > size.x * 1.20:
		sky_y = maxf(sky_y, 150.0)
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
		var lit := garden_lights[i]>0.23 if free_play else i<progress
		if i > 0:
			var line_color := Color(_tone_color("gold"),0.32) if lit else Color(_tone_color("teal"),0.10)
			draw_line(_sky_position(i-1), pos, line_color, 1.0, true)
		if lit:
			_glow(pos, 7.0, _tone_color("gold"), _coda_light()*1.55 if chapter_done else 1.0)
			draw_line(pos + Vector2(-6,0), pos + Vector2(6,0), Color(0.96,0.87,0.64,0.6), 1.0, true)
			draw_line(pos + Vector2(0,-6), pos + Vector2(0,6), Color(0.96,0.87,0.64,0.6), 1.0, true)
		draw_circle(pos, 2.3 if lit else 1.6, _tone_color("gold") if lit else Color("335661"))
		if _goal_kind() == "duet":
			draw_circle(pos + Vector2(7,7), 1.8, _tone_color("gold") if lit else Color("335661"))

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
		_glow(_flight_point(start,finish,t), 7.0, _tone_color("gold"), 1.2)

func _draw_background() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),_tone_color("ink").lerp(_tone_color("deep"),garden_energy*0.10))
	for i in range(20):
		var y := size.y * float(i) / 20.0
		var c := _tone_color("deep").lerp(_tone_color("ink"),float(i)/20.0)
		c.a = 0.42
		draw_rect(Rect2(0.0, y, size.x, size.y / 20.0 + 1.0), c)
	for star in stars:
		var pos := Vector2(star["x"] * size.x, 90.0 + star["y"] * (size.y * 0.58))
		var alpha: float = 0.32 if reduced_motion else 0.23 + 0.20 * sin(elapsed * 0.55 + star["phase"])
		draw_circle(pos, star["r"], Color(0.66, 0.8, 0.79, alpha))
	var pond_y := pivot.y + length + 71.0
	# Keep the resonant water visible above the score, including wide windows.
	var horizon := minf(pond_y, size.y - 321.0)
	# Soft nocturnal ridges, reflected rings and reeds frame the instrument.
	for row in range(3):
		var pts := PackedVector2Array([Vector2(-20.0, size.y)])
		for i in range(27):
			var x := size.x * float(i) / 26.0
			var y := horizon - 14.0 + float(row) * 19.0 + sin(float(i) * 0.58 + float(row) * 1.9) * 19.0
			pts.append(Vector2(x, y))
		pts.append(Vector2(size.x + 20.0, size.y))
		draw_colored_polygon(pts, _tone_color("deep").darkened(0.16+float(row)*0.15))
	for i in range(10):
		var y := horizon + 19.0 + float(i) * 14.0
		var width := 38.0 + float(i) * 15.0
		draw_line(Vector2(size.x * 0.5 - width, y), Vector2(size.x * 0.5 + width, y), Color(0.31, 0.56, 0.58, 0.07), 1.0)
	if free_play:
		for ring in ripples:
			var age: float = ring["age"]
			var center := Vector2(float(ring["pos"].x),horizon+27.0)
			var width := 12.0+age*28.0
			var ellipse := PackedVector2Array()
			for j in range(33):
				var angle := float(j)*TAU/32.0
				ellipse.append(center+Vector2(cos(angle)*width,sin(angle)*width*0.12))
			var c := _tone_color("teal")
			c.a = (1.0-age/2.2)*float(ring["strength"])*0.22
			draw_polyline(ellipse,c,1.0,true)
		for i in range(7):
			var level: float = garden_lights[i]
			if level > 0.10:
				var pos := Vector2(_sky_position(i).x,horizon+24.0+float(i%3)*12.0)
				_glow(pos,8.0+level*11.0,_tone_color("gold"),level*0.65)
				for j in range(4):
					var half := 5.0+float(j)*6.0+level*8.0
					var c := _tone_color("gold")
					c.a = level*(0.15-float(j)*0.026)
					draw_line(pos+Vector2(-half,float(j)*8.0),pos+Vector2(half,float(j)*8.0),c,1.0,true)
	elif chapter_done:
		var bloom := _coda_light()
		var reflection := Vector2(size.x*0.5,horizon+28.0)
		_glow(reflection,28.0,_tone_color("gold"),bloom*0.45)
		for j in range(5):
			var half := 18.0+float(j)*15.0
			draw_line(reflection+Vector2(-half,float(j)*7.0),reflection+Vector2(half,float(j)*7.0),Color(_tone_color("gold"),bloom*(0.14-float(j)*0.02)),1.0,true)
	for side in [-1.0, 1.0]:
		for i in range(7):
			var x: float = size.x * 0.5 + side * (size.x * 0.40 + float(i) * 7.0)
			var y := horizon + 38.0
			var tip := Vector2(x + sin((0.0 if reduced_motion else elapsed * 0.45) + float(i)) * 5.0 + side * 10.0, y - 45.0 - float(i % 3) * 17.0)
			draw_line(Vector2(x, y), tip, Color("23464b"), 1.2)
			draw_line(tip - Vector2(0, -13), tip + Vector2(side * 12, 8), Color("315657"), 1.2)

func _draw_header() -> void:
	if not started:
		var title_y := clampf(pivot.y-70.0,size.y*0.11,size.y*0.19)
		_text("月の振り子",Vector2(size.x*0.5,title_y),42,_tone_color("gold"),true)
		return
	_text("月の振り子", Vector2(30.0, 49.0), 30, _tone_color("gold"))
	if started:
		_button(mute_rect, "音 OFF" if muted else "音 ON")
		_button(help_rect, "？")
		_pause_button()
		if reset_rect.size.x>0.0:
			_button(reset_rect,GRAVITY_NAMES[gravity_index] if free_play else "庭へ")

func _moon_hint() -> String:
	if not started:
		return ""
	if dragging:
		return "離す"
	if not swinging and not chapter_done and (not free_play or casts==0):
		return "← 左へ引いて、離す" if chapter==0 and progress==0 and casts==0 and not free_play else "月を引いて、離す"
	return ""

func _pitch_labels_visible() -> bool:
	# A note name must not sit behind the nearby gesture instruction.
	return started and _moon_hint().is_empty()

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
		var bob := 0.0 if reduced_motion else sin(elapsed * 4.0 + float(i)) * glow * 4.0
		pos.x += bob
		draw_line(Vector2(pos.x, pos.y - 50.0), Vector2(pos.x, pos.y - 13.0), Color(0.31, 0.47, 0.49, 0.50), 1.0)
		_glow(pos, 12.0 + glow * 7.0, _tone_color("teal"), glow * 3.0)
		var points := PackedVector2Array([pos + Vector2(-8,-11), pos + Vector2(8,-11), pos + Vector2(11,7), pos + Vector2(-11,7)])
		draw_colored_polygon(points, Color("446a6b").lerp(_tone_color("teal"), glow))
		draw_line(pos + Vector2(-11,7), pos + Vector2(11,7), Color("a9b69b").lerp(WHITE, glow), 1.5)
		draw_circle(pos + Vector2(0,10), 2.0, _tone_color("gold"))
		if _pitch_labels_visible():
			_text(NOTE_NAMES[i], pos + Vector2(0, 35), 11, MUTED, true)
	if started and not chapter_done and _goal_kind() == "main":
		var target := _target()
		var target_pos := _point(target)
		var pulse := 0.75 if reduced_motion else 0.75 + sin(elapsed * 2.5) * 0.15
		_glow(target_pos, 20.0, _tone_color("gold"), pulse * 1.6)
		draw_arc(pivot, length, PI * 0.5 - target - HIT_TOLERANCE, PI * 0.5 - target + HIT_TOLERANCE, 18, Color(0.91,0.80,0.50,0.28), 5.0, true)
		draw_arc(target_pos, 26.0 if reduced_motion else 26.0 + sin(elapsed * 2.5) * 2.0, 0, TAU, 48, Color(0.94,0.84,0.61,0.8), 1.5, true)
		if str(_turn_advice_for(-1).get("word","")).is_empty():
			_text("ここで折り返す",target_pos+Vector2(0,-40),16,_tone_color("gold"),true)
		draw_colored_polygon(PackedVector2Array([target_pos+Vector2(0,-6),target_pos+Vector2(5,0),target_pos+Vector2(0,6),target_pos+Vector2(-5,0)]),_tone_color("gold"))
		if has_last_turn and (not swinging or cast_judged or dragging) and _turn_advice_for(-1).is_empty():
			var previous := _point(last_turn)
			draw_arc(previous,8.0,0.0,TAU,24,Color(WHITE,0.5),1.0,true)
			_text("前の折り返し",previous+Vector2(0,24),13,MUTED,true)

	for i in range(1, trail.size()):
		var c := _tone_color("gold")
		c.a = float(i)/float(trail.size())*0.26
		draw_line(trail[i-1],trail[i],c,1.0+float(i)/float(trail.size())*2.1)
	for r in ripples:
		var c := _tone_color("teal")
		c.a = maxf(0.0, 1.0 - float(r["age"]) / 2.2) * 0.26
		draw_arc(r["pos"], 8.0 + float(r["age"]) * 45.0, 0, TAU, 32, c, 1.0, true)
	var moon := _point(theta)
	var moon_radius := 25.0 if started else 42.0
	_draw_moon(pivot,moon,theta,moon_radius,_tone_color("gold"),1.4,Color("86aaa2"))
	draw_circle(pivot, 6.0, _tone_color("gold"))
	draw_circle(pivot, 2.0, INK)
	if dragging:
		draw_arc(moon, 38.0, 0, TAU, 48, Color(0.64,0.89,0.82,0.4), 1.0, true)
	var hint := _moon_hint()
	if not hint.is_empty():
		var where := moon+Vector2(0,59) if dragging else Vector2(moon.x,minf(moon.y+61.0,size.y-266.0))
		_text(hint,where,16 if dragging else 17,WHITE if dragging else MUTED,true)
	for p in particles:
		var c: Color = p["color"]
		c.a = clampf(float(p["life"]), 0.0, 1.0) * 0.8
		draw_circle(p["pos"], 1.8, c)
	if chapter_done:
		var glow := _coda_light()*minf(1.0,finish_time*1.8)
		_glow(Vector2(pivot.x, pivot.y + 80), 75, _tone_color("gold"), glow * 2.0)

func _draw_score() -> void:
	if free_play:
		_text(PALETTES[palette_index]["name"],Vector2(size.x*0.5,size.y-137.0),18,_tone_color("gold"),true)
		return
	var card_y := size.y - 245.0
	var card := Rect2(28.0, card_y, size.x - 56.0, 137.0)
	_panel(card,Color(_tone_color("ink").lightened(0.025),0.90),_tone_color("teal").darkened(0.62),16.0)
	_text(PALETTES[palette_index]["name"] if free_play else CHAPTERS[chapter]["name"], Vector2(49.0, card_y + 34.0), 23, _tone_color("gold"))
	var total: int = 0 if free_play else CHAPTERS[chapter]["targets"].size()
	for i in range(total):
		var pos := Vector2(size.x - 57.0 - float(total - 1 - i) * 26.0, card_y + 27.0)
		draw_circle(pos, 6.0, _tone_color("gold") if i < progress else Color("2d4a50"))
		if i == progress and not chapter_done:
			draw_arc(pos, 9.0, 0, TAU, 24, _tone_color("gold"), 1.0, true)
	if feedback_timer > 0.0:
		_text(feedback, Vector2(size.x * 0.5, card_y + 76.0), 20, WHITE, true)

func _draw_intro() -> void:
	_button(start_rect,"奏でる",true)
	_text(_journey_entry_label(true),Vector2(tour_rect.get_center().x,tour_rect.position.y+43.0),16,MUTED,true)
	# A quiet speaker mark conveys sound without another paragraph of copy.
	var at := Vector2(start_rect.end.x+21.0,start_rect.get_center().y)
	var c := Color(MUTED,0.68)
	draw_colored_polygon(PackedVector2Array([at+Vector2(-5,-4),at+Vector2(0,-4),at+Vector2(6,-9),at+Vector2(6,9),at+Vector2(0,4),at+Vector2(-5,4)]),c)
	if muted:
		draw_line(at+Vector2(10,-7),at+Vector2(18,7),c,1.0,true)
	else:
		draw_arc(at+Vector2(6,0),8.0,-0.7,0.7,12,c,1.0,true)
		draw_arc(at+Vector2(6,0),13.0,-0.7,0.7,16,c,1.0,true)

func _draw_help() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02,0.04,0.06,0.87))
	var cx := size.x * 0.5
	var y := size.y * 0.26
	_text("月の奏で方", Vector2(cx,y), 34,_tone_color("gold"),true)
	var lines := ["1. 光の輪と反対側へ、月を引く。", "2. 指を離すと、月が反対側へ揺れる。", "3. 光の近くで折り返すと、光がつながる。", "", "小さく引けば近くへ、大きく引けば遠くへ。", "金の輪と、前の折り返しを見比べよう。", "失敗しても音は残る。何度でも奏でよう。", "", "← →：角度を調整　Space：放す", "R：引き直す　M：ミュート　P：一時停止 / 再開"]
	if _goal_kind() in ["relay", "duet"]:
		lines[0] = "今度は、小さな月の光を狙う。"
		lines[1] = "外側の鐘を通して、中央の鐘へ戻す。"
		lines[2] = "蓄えた力が、小さな月を揺らす。"
		lines[5] = "光のある側から、少し大きく引いてみよう。"
		if _goal_kind() == "duet":
			lines[5] = "左でも右でも、二つの光をひと振りで。"
	if free_play:
		lines[0] = "光の輪のない、自由な夜。"
		lines[1] = "月を引いて放すと、鐘が歌う。"
		lines[2] = "左上の重力で、振れ方を奏で分けよう。"
		lines[5] = "右下で夜の色と、響きの手触りが変わる。"
	for i in range(lines.size()):
		_text(lines[i],Vector2(cx,y+54.0+float(i)*34.0),20,WHITE,true)
	_text("どこかをタップして閉じる / H",Vector2(cx,y+440.0),17,MUTED,true)
	_button(help_restart_rect,"最初から星を灯す遊び")

func _load_save() -> void:
	var config := ConfigFile.new()
	var loaded := config.load("user://moon_pendulum.cfg") == OK
	if OS.has_feature("web"):
		# The tiny synchronous checkpoint survives an immediate refresh. Godot's
		# user:// IndexedDB filesystem remains the fallback for older saves.
		var stored = JavaScriptBridge.eval("(function(){try{return window.localStorage.getItem("+JSON.stringify(WEB_SAVE_KEY)+");}catch(e){return null;}})()")
		if stored is String and not stored.is_empty() and stored.length()<32768:
			var data = JSON.parse_string(stored)
			var checkpoint := _config_from_checkpoint(data)
			if checkpoint!=null and (not loaded or int(checkpoint.get_value("meta","revision",0))>=int(config.get_value("meta","revision",0))):
				config = checkpoint
				loaded = true
	if loaded:
		save_revision = maxi(0,int(config.get_value("meta","revision",0)))
		muted = bool(config.get_value("settings","muted",false))
		palette_index = clampi(int(config.get_value("settings","palette",0)),0,2)
		palette_from = palette_index
		saved_gravity_index = clampi(int(config.get_value("settings","gravity",1)),0,2)
		var stored_resume = config.get_value("journey","resume",{})
		if stored_resume is Dictionary:
			journey_resume = stored_resume
		var stored_garden = config.get_value("garden","scene",{})
		if stored_garden is Dictionary:
			garden_scene = stored_garden
		for i in range(CHAPTERS.size()):
			best_chapters[i] = int(config.get_value("best", str(i), 0))
		var listening = _validated_listening(config.get_value("music","listening",{}),best_chapters)
		listening_resume = listening if listening is Dictionary else {}

func _validated_listening(value: Variant, best: Array) -> Variant:
	if not value is Dictionary:
		return null
	if value.is_empty():
		return {}
	if not _checkpoint_number(value.get("chapter"),0,CHAPTERS.size()-1,true) or not _checkpoint_number(value.get("casts"),0,1e7,true) or not _checkpoint_number(value.get("perfects"),0,1e7,true):
		return null
	var index := int(value["chapter"])
	if int(best[index])<1:
		return null
	return {"chapter":index,"casts":int(value["casts"]),"perfects":int(value["perfects"])}

func _checkpoint_number(value: Variant, minimum: float, maximum: float, integer: bool = false) -> bool:
	if typeof(value) not in [TYPE_INT,TYPE_FLOAT]:
		return false
	var number := float(value)
	return is_finite(number) and number>=minimum and number<=maximum and (not integer or number==floorf(number))

func _config_from_checkpoint(data: Variant) -> ConfigFile:
	# JSON basic types only: do not parse Object/Resource-capable Variant text.
	if not data is Dictionary:
		return null
	if not _checkpoint_number(data.get("version"),1,1,true):
		return null
	if not _checkpoint_number(data.get("revision"),0,1e9,true) or not data.get("muted") is bool or not _checkpoint_number(data.get("palette"),0,2,true):
		return null
	var gravity = data.get("gravity",1)
	if not _checkpoint_number(gravity,0,2,true):
		return null
	var best = data.get("best")
	var journey = data.get("journey")
	var garden = data.get("garden")
	if not best is Array or best.size()!=CHAPTERS.size() or not journey is Dictionary or not garden is Dictionary:
		return null
	for rating in best:
		if not _checkpoint_number(rating,0,3,true):
			return null
	var listening = _validated_listening(data.get("listening",{}),best)
	if listening==null:
		return null
	var clean_journey: Dictionary = {}
	if not journey.is_empty():
		if not _checkpoint_number(journey.get("chapter"),0,CHAPTERS.size()-1,true):
			return null
		var index := int(journey["chapter"])
		if not _checkpoint_number(journey.get("progress"),0,CHAPTERS[index]["targets"].size()-1,true) or not _checkpoint_number(journey.get("casts"),0,1e7,true) or not _checkpoint_number(journey.get("perfects"),0,1e7,true):
			return null
		for key in ["chapter","progress","casts","perfects"]:
			clean_journey[key] = int(journey[key])
	var clean_garden: Dictionary = {}
	if not garden.is_empty():
		var lights = garden.get("lights")
		if not lights is Array or lights.size()!=7 or not _checkpoint_number(garden.get("energy"),0,1):
			return null
		var levels: Array[float] = []
		for level in lights:
			if not _checkpoint_number(level,0,1):
				return null
			levels.append(float(level))
		clean_garden = {"lights":levels,"energy":float(garden["energy"])}
	var config := ConfigFile.new()
	config.set_value("meta","revision",int(data["revision"]))
	config.set_value("settings","muted",data["muted"])
	config.set_value("settings","palette",int(data["palette"]))
	config.set_value("settings","gravity",int(gravity))
	config.set_value("journey","resume",clean_journey)
	config.set_value("garden","scene",clean_garden)
	config.set_value("music","listening",listening)
	for i in range(best.size()):
		config.set_value("best",str(i),int(best[i]))
	return config

func _save() -> void:
	if testing:
		return
	var config := ConfigFile.new()
	save_revision += 1
	config.set_value("meta","revision",save_revision)
	config.set_value("settings","muted",muted)
	config.set_value("settings","palette",palette_index)
	if free_play:
		saved_gravity_index = gravity_index
	config.set_value("settings","gravity",saved_gravity_index)
	if transition_phase==1 and not transition_resume.is_empty():
		journey_resume = transition_resume.duplicate()
	elif not free_play:
		journey_resume = _snapshot_journey()
	config.set_value("journey","resume",journey_resume)
	if started and not free_play and chapter_done and transition_phase==0:
		listening_resume = {"chapter":chapter,"casts":casts,"perfects":perfects}
	config.set_value("music","listening",listening_resume)
	if free_play:
		garden_scene = {"lights":garden_lights.duplicate(),"energy":garden_energy}
	config.set_value("garden","scene",garden_scene)
	for i in range(CHAPTERS.size()):
		config.set_value("best", str(i), best_chapters[i])
	config.save("user://moon_pendulum.cfg")
	if OS.has_feature("web"):
		# A versioned JSON checkpoint contains only the small game-state schema.
		# Storage may be blocked by browser policy; keep filesystem saving intact.
		var checkpoint := {"version":1,"revision":save_revision,"muted":muted,"palette":palette_index,"gravity":saved_gravity_index,"journey":journey_resume,"garden":garden_scene,"best":best_chapters,"listening":listening_resume}
		JavaScriptBridge.eval("(function(){try{window.localStorage.setItem("+JSON.stringify(WEB_SAVE_KEY)+","+JSON.stringify(JSON.stringify(checkpoint))+");}catch(e){}})()")

func _publish_state() -> void:
	# A read-only public QA snapshot. It cannot alter gameplay or storage.
	if OS.has_feature("web"):
		var state := {"started":started,"chapter":chapter,"kind":_goal_kind(),"palette":palette_index,"gravity":gravity_index,"energy":garden_energy,"progress":progress,"casts":casts,"launch":cast_start_angle,"complete":chapter_done,"freePlay":free_play,"muted":muted,"paused":paused,"help":show_help,"transition":transition_phase,"saveRevision":save_revision,"build":BUILD.COMMIT,"engine":Engine.get_version_info()["string"]}
		state["music"] = night_music.snapshot()
		state["journeyEntry"] = _journey_entry_label(not started)
		var cues: Array = []
		for cue in turn_advice:
			var word_rect := _turn_advice_word_rect(cue)
			cues.append({"side":cue["side"],"remaining":cue["remaining"],"word":cue["word"],"wordRect":[word_rect.position.x,word_rect.position.y,word_rect.size.x,word_rect.size.y]})
		state["advice"] = {"misses":miss_streak,"cues":cues,"reducedMotion":reduced_motion}
		JavaScriptBridge.eval("window.moonPendulumState = " + JSON.stringify(state) + ";")
