extends Node2D
## Moon Pendulum: a small, deterministic musical physics toy with a learning loop.
## Pendulum motion uses a fixed physics timestep; all art is original vector drawing.

const BUILD = preload("res://build_info.gd")
const NIGHT_MUSIC = preload("res://scripts/night_music.gd")
const HARMONY = preload("res://scripts/night_harmony.gd")
const INSTRUMENT = preload("res://scripts/instrument_art.gd")
const FONT = preload("res://assets/fonts/MoonSerifUI.tres")
const BELL_ANGLES = [-0.96, -0.66, -0.34, 0.0, 0.34, 0.66, 0.96]
const NOTE_NAMES = ["D3", "A3", "D4", "E4", "F♯4", "B4", "D5"]
const CHAPTERS = preload("res://scripts/constellation.gd").NIGHTS
const SKY = preload("res://scripts/sky_figures.gd")
const SKY_SCENE = preload("res://scripts/sky_scene.gd")
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
const INTRO_SWAY = 0.055
const INTRO_PERIOD = 6.0
const INTRO_HIT_RADIUS = 60.0
const INTRO_SETTLE = 0.35
const COMPLETION_FEEDBACK = "星座が灯った。夜に、響きが満ちた。"
const COMPLETION_FEEDBACK_HOLD = 3.5
const COMPLETION_FEEDBACK_FADE = 1.5
const COMPLETION_FEEDBACK_FADE_REDUCED = 0.5
const FEEDBACK_CROSSFADE = 0.30

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
var intro_settle := 0.0
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
var lit_goals: Array[bool] = []
var cast_goal_hits: Array = []
var cast_goal_checks: Array = []
var cast_goal_errors: Array = []
var main_turns := 0
var cast_awards := 0
var chapter_done := false
var show_help := false
var show_collection := false
var garden_night := -1
var collection_rect := Rect2()
var collection_panel := Rect2()
var collection_close_rect := Rect2()
var collection_rows: Array[Rect2] = []
var collection_choices: Array[int] = []
var target_pulse := 0.0
var finish_time := 0.0
var feedback := "光の輪へ、反対側から月を届かせよう。"
var feedback_timer := 0.0
var feedback_hold := 3.0
var feedback_fade := 1.0
var feedback_previous := ""
var feedback_previous_alpha := 0.0
var feedback_blend := 0.0
var note_label := ""
var bell_glows: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var bell_cooldowns: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var particles: Array[Dictionary] = []
var light_flights: Array[Dictionary] = []
var ripples: Array[Dictionary] = []
var trail: Array[Vector2] = []
var crescent_outline := PackedVector2Array()
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
var bell_rates: Array[Array] = []
var echo_rates: Array[Array] = []
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
var help_restart_rect := Rect2()
var help_repeat_rect := Rect2()
var retry_rect := Rect2()
var next_rect := Rect2()
var reset_rect := Rect2()
var mute_rect := Rect2()
var help_rect := Rect2()
var pause_rect := Rect2()
var resume_rect := Rect2()
var stage_rect := Rect2()
var best_chapters: Array = [0, 0, 0, 0, 0]
var best_casts: Array = [0, 0, 0, 0, 0]
var testing := false
var save_revision := 0
var duet_hits: Array[bool] = [false, false]
var duet_checked: Array[bool] = [false, false]
var duet_errors: Array[float] = [0.0, 0.0]
var duet_offsets: Array[float] = [0.0, 0.0]
var reduced_motion := false
var echoes: Array[Dictionary] = []
var echo_returns: Array[Dictionary] = []
var echo_transfers: Array[Dictionary] = []
const ECHO_SIGNAL_SECONDS = 0.70
var chain_rings := 0
var harmonic_time := 0.0
var title_frame_queued := false
var state_clock := 0.0
var transition_phase := 0
var transition_time := 0.0
var transition_action := ""
var transition_chapter := 0
var transition_resume: Dictionary = {}
var transition_skip_opening := false
var night_opening := false
var night_opening_time := 0.0
var night_intro_seen := false
var sky_points := PackedVector2Array()
var sky_box := Rect2()
var sky_fitted: Dictionary = {}
const NIGHT_VIEW = 3.6
const NIGHT_PAN = 4.0
const NIGHT_DISSOLVE = 0.5
const TRANSITION_OUT = 1.8
const TRANSITION_QUIET = 0.4
const TRANSITION_IN = 0.8
var cadence_notes: Array[Dictionary] = []
var free_play := false
var gravity_index := 1
var saved_gravity_index := 1
const GRAVITY_FACTORS = [0.64, 1.0, 1.4884]
const GRAVITY_NAMES = ["重力 弱", "重力 標準", "重力 強"]

func _ready() -> void:
	Engine.max_fps = 60
	RenderingServer.set_default_clear_color(INK)
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
	for harmony in HARMONY.NIGHTS:
		var bell_row: Array[float] = []
		var echo_row: Array[float] = []
		for i in range(7):
			bell_row.append(pow(2.0,float(harmony["bells"][i]-HARMONY.BELL_REFERENCE[i])/12.0))
		for i in range(4):
			echo_row.append(pow(2.0,float(harmony["echoes"][i]-HARMONY.ECHO_REFERENCE[i])/12.0))
		bell_rates.append(bell_row)
		echo_rates.append(echo_row)
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
		_set_feedback("月を引いて、離す。")

func _pause_for_focus_loss() -> void:
	_cancel_aim()
	show_collection = false
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
	var playing_night := started and not free_play
	length = minf(size.x * 0.43, (size.y - 325.0) * 0.72)
	pivot = Vector2(size.x * 0.5, 139.0)
	if portrait:
		var stage_top := 142.0
		var stage_bottom := size.y - (145.0 if playing_night else 263.0)
		var spare := maxf(0.0, stage_bottom - stage_top - length - 102.0)
		pivot.y = stage_top + spare * 0.60 + 32.0
	elif playing_night:
		pivot.y = maxf(pivot.y,size.y-length-205.0)
	stage_rect = Rect2(24.0, 112.0, size.x - 48.0, size.y - (277.0 if playing_night else 369.0))
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
	var portrait_sky := size.y > size.x*1.20
	var sky_top := 145.0 if portrait_sky else 24.0
	var sky_height := maxf(45.0,minf(300.0 if playing_night else 156.0,pivot.y-sky_top-42.0))
	# The first sky keeps its larger hero scale before drawing back to the stage.
	var sky_width := minf(size.x*(0.68 if playing_night else 0.62),470.0 if playing_night else 350.0)
	sky_fitted = SKY_SCENE.fit(_scene_index(),Rect2(size.x*0.5-sky_width*0.5,sky_top,sky_width,sky_height))
	sky_points = sky_fitted["points"]
	sky_box = SKY.bounds(Array(sky_points))
	mute_rect = Rect2(size.x - 128.0, 20.0, 104.0, 66.0)
	help_rect = Rect2(size.x - 202.0, 20.0, 66.0, 66.0)
	pause_rect = Rect2(size.x - 276.0, 20.0, 66.0, 66.0)
	help_repeat_rect = Rect2(size.x*0.5-126.0,size.y*0.26+420.0,252.0,56.0)
	help_restart_rect = Rect2(size.x*0.5-126.0,size.y*0.26+490.0,252.0,66.0)
	resume_rect = Rect2(size.x*0.5-110.0,size.y*0.46+25.0,220.0,58.0)
	collection_rect = Rect2(size.x*0.5-130.0,size.y-235.0,260.0,72.0)
	collection_choices.assign([-1])
	for index in range(CHAPTERS.size()):
		if int(best_chapters[index])>0:collection_choices.append(index)
	var panel_width := minf(560.0,size.x-40.0)
	var panel_height := 198.0+float(collection_choices.size())*74.0
	collection_panel = Rect2(size.x*0.5-panel_width*0.5,size.y*0.5-panel_height*0.5,panel_width,panel_height)
	collection_rows.clear()
	for row in range(collection_choices.size()):
		collection_rows.append(Rect2(collection_panel.position+Vector2(18.0,74.0+float(row)*74.0),Vector2(panel_width-36.0,68.0)))
	collection_close_rect = Rect2(collection_panel.position+Vector2(panel_width*0.5-90.0,panel_height-82.0),Vector2(180.0,68.0))

func _goal_index() -> int:
	var count: int = CHAPTERS[chapter]["targets"].size()
	if lit_goals.size()!=count:
		return mini(progress,count-1)
	for index in range(count):
		if not lit_goals[index]:return index
	return count-1

func _set_goal_mask(value: Variant = null) -> void:
	lit_goals.clear()
	var valid: bool = value is Array and value.size()==CHAPTERS[chapter]["targets"].size() and value.all(func(item):return item is bool)
	for index in range(CHAPTERS[chapter]["targets"].size()):
		lit_goals.append(bool(value[index]) if valid else index<progress)
	progress = lit_goals.count(true)

func _goal_kind_at(index: int) -> String:
	var score: Dictionary = CHAPTERS[chapter]
	return str(score["kinds"][index] if score.has("kinds") else score.get("kind","main"))

func _uses_echo_goals() -> bool:
	return not free_play

func _goal_tolerance(index: int) -> float:
	return float(CHAPTERS[chapter].get("main_tolerance",HIT_TOLERANCE)) if _goal_kind_at(index)=="main" else float(CHAPTERS[chapter]["echo_tolerance"])

func _echo_target_at(index: int, side: int) -> float:
	var target: float = CHAPTERS[chapter]["targets"][index]
	if _goal_kind_at(index)=="duet":
		var inward: bool = CHAPTERS[chapter].get("inward",[false,false])[index]
		return (-1.0 if side==0 else 1.0)*(-1.0 if inward else 1.0)*absf(target)*0.96
	return target

func _target() -> float:
	if chapter_done or free_play:
		return 0.0
	return float(CHAPTERS[chapter]["targets"][_goal_index()])

func _point(angle: float, radius: float = -1.0) -> Vector2:
	var r := length if radius < 0.0 else radius
	return pivot + Vector2(sin(angle), cos(angle)) * r

func _intro_angle() -> float:
	return 0.0 if reduced_motion else sin(elapsed*TAU/INTRO_PERIOD)*INTRO_SWAY

func _moon_radius() -> float:
	if not started:return 42.0
	var t := clampf(intro_settle/INTRO_SETTLE,0.0,1.0)
	return lerpf(25.0,42.0,t*t*(3.0-2.0*t))

func _intro_moon_center() -> Vector2:
	var angle := _intro_angle()
	return _moon_origin(_point(angle),angle,42.0)

func _intro_moon_hit(pos: Vector2) -> bool:
	return pos.distance_to(_intro_moon_center())<=INTRO_HIT_RADIUS

func _process(delta: float) -> void:
	_advance_audio_envelopes(delta)
	night_music.advance(delta,started and (not free_play or garden_night>=0) and not muted and not paused and not show_help and not show_collection and transition_phase!=1,_transition_audio_gain(),muted or paused or show_help or show_collection,paused or show_help or show_collection)
	state_clock += delta
	if state_clock >= 0.5:
		state_clock = 0.0
		_publish_state()
	if not paused and not show_help and not show_collection:
		_advance_transition(delta)
		elapsed += delta
		intro_settle = maxf(0.0,intro_settle-delta)
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
		if transition_phase==0 and not night_opening:
			_advance_feedback(delta)
		for effect in echo_returns:
			effect["age"] += delta
		echo_returns = echo_returns.filter(func(effect): return float(effect["age"])<ECHO_SIGNAL_SECONDS)
		for effect in echo_transfers:
			effect["age"] += delta
		echo_transfers = echo_transfers.filter(func(effect): return float(effect["age"])<ECHO_SIGNAL_SECONDS)
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
	if not started or paused or show_help or show_collection or transition_phase!=0:
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
		last_turn = theta
		has_last_turn = true
		if not cast_judged and main_turns<2:
			main_turns += 1
			_judge_turn()
			_close_cast_when_done()
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
	note_label = _bell_name(index)
	_sound(index, strength)
	# An outer bell winds a little escapement. The returning central bell
	# releases it, so the echo is an actual second pendulum with its own motion.
	if free_play:
		garden_energy = minf(1.0, garden_energy + strength * 0.028)
		garden_lights[index] = minf(1.0, garden_lights[index] + strength * 0.48)
		if garden_flight_cooldowns[index] <= 0.0 and not reduced_motion:
			light_flights.append({"from":_point(float(BELL_ANGLES[index]),length+15.0),"index":index,"age":0.0})
			garden_flight_cooldowns[index] = 1.4
	if chapter > 0 or _uses_echo_goals():
		if index == 1 or index == 5:
			var side := 0 if index == 1 else 1
			echoes[side]["charged"] = true
			echoes[side]["stored"] = clampf(0.75 + absf(omega) * 1.12, 0.0, 3.6)
			_signal_echo_transfer(side,"charge")
			if _uses_echo_goals():
				omega *= 0.97
		elif index == 3:
			for e in echoes:
				if e["charged"]:
					var impulse: float = e["stored"] if _uses_echo_goals() else (1.8 + strength * 1.4)
					e["omega"] = clampf(float(e["omega"]) + (-1.0 if int(e["side"]) == 0 else 1.0) * impulse, -3.6, 3.6)
					e["cast_id"] = casts
					e["glow"] = 1.0
					e["charged"] = false
					_signal_echo_transfer(int(e["side"]),"release")
	var pos := _point(float(BELL_ANGLES[index]), length + 11.0)
	if not reduced_motion:
		ripples.append({"pos": pos, "age": 0.0, "strength": strength})
	if not reduced_motion:
		for i in range(5):
			var a := float(i) * TAU / 5.0 + elapsed
			particles.append({"pos": pos, "velocity": Vector2(cos(a), sin(a)) * 33.0, "life": 0.9, "color": _tone_color("teal")})


func _reset_echoes(show_return: bool = false) -> void:
	# The physical reset remains immediate. Only its brief light has a lifetime.
	echo_returns.clear()
	echo_transfers.clear()
	if show_return and started and not free_play:
		for e in echoes:
			echo_returns.append({"side":e["side"],"angle":e["theta"],"age":0.0})
	main_turns = 0
	cast_awards = 0
	cast_goal_hits.clear()
	cast_goal_checks.clear()
	cast_goal_errors.clear()
	for index in range(CHAPTERS[chapter]["targets"].size()):
		cast_goal_hits.append([false,false])
		cast_goal_checks.append([false,false])
		cast_goal_errors.append([0.0,0.0])
	echoes = [
		{"side":0, "theta":0.0, "omega":0.0, "charged":false, "glow":0.0, "cooldown":0.0, "stored":0.0, "cast_id":-1, "judged_cast":-1,"turns":0},
		{"side":1, "theta":0.0, "omega":0.0, "charged":false, "glow":0.0, "cooldown":0.0, "stored":0.0, "cast_id":-1, "judged_cast":-1,"turns":0}
	]
	chain_rings = 0
	duet_hits = [false, false]
	duet_checked = [false, false]
	duet_errors = [0.0, 0.0]
	duet_offsets = [0.0, 0.0]

func _echo_pivot(side: int) -> Vector2:
	var spacing := 0.32 if _uses_echo_goals() else 0.73
	return pivot + Vector2((-1.0 if side == 0 else 1.0) * length * spacing, length * 0.11)

func _echo_length() -> float:
	return length * (0.42 if _uses_echo_goals() else 0.26)

func _echo_point(side: int, angle: float) -> Vector2:
	return _echo_pivot(side) + Vector2(sin(angle), cos(angle)) * _echo_length()

func _goal_kind() -> String:
	if free_play:
		return "free"
	return _goal_kind_at(_goal_index())

func _echo_target(side: int) -> float:
	return _echo_target_at(_goal_index(),side)

func _clear_turn_advice() -> void:
	turn_advice.clear()
	miss_streak = 0
	advice_cast = -1

func _record_turn_advice(side: int, angle: float, target: float, word: String = "") -> void:
	var previous := _turn_advice_for(side)
	if advice_cast==casts and not previous.is_empty() and absf(float(previous["angle"])-float(previous["target"]))<=absf(angle-target):
		previous["remaining"] = TURN_ADVICE_SECONDS
		if side<0:last_turn = float(previous["angle"])
		return
	if advice_cast!=casts:
		miss_streak += 1
		advice_cast = casts
	if word.is_empty():
		word = "反対側から" if signf(angle)!=signf(target) else ("もう少し大きく" if absf(angle)<absf(target) else "少しやさしく")
	turn_advice = turn_advice.filter(func(cue): return int(cue["side"])!=side)
	turn_advice.append({"side":side,"angle":angle,"target":target,"remaining":TURN_ADVICE_SECONDS,"word":word if miss_streak>=2 else ""})
	_fade_feedback()

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
			var note_width := FONT.get_string_size(_bell_name(i),HORIZONTAL_ALIGNMENT_LEFT,-1,11).x
			var note_at := bell_at+Vector2(0,35)
			blockers.append(Rect2(note_at-Vector2(note_width*0.5+6,16),Vector2(note_width+12,22)))
	for e in echoes:
		var echo_side := int(e["side"])
		var ep := _echo_pivot(echo_side)
		blockers.append(Rect2(ep-Vector2(13,13),Vector2(26,26)))
		if side<0 and not free_play:
			# An uncharged moon can remain still for the whole comparison.
			blockers.append(Rect2(_echo_point(echo_side,0.0)-Vector2(18,18),Vector2(36,36)))
			for index in range(lit_goals.size()):
				if lit_goals[index] or _goal_kind_at(index)=="main":continue
				if _goal_kind_at(index)=="duet" or echo_side==(0 if float(CHAPTERS[chapter]["targets"][index])<0.0 else 1):
					blockers.append(Rect2(_echo_point(echo_side,_echo_target_at(index,echo_side))-Vector2(21,21),Vector2(42,42)))
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
		var tail := clampf(float(cue["remaining"])/0.60,0.0,1.0)
		var alpha := tail*tail*(3.0-2.0*tail)
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
			if int(e["cast_id"]) == casts and int(e["turns"])<2 and not cast_judged:
				e["turns"] += 1
				e["judged_cast"] = casts
				_judge_echo_turn(int(e["side"]), float(e["theta"]))
				_close_cast_when_done()
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
	if not started:
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
		_draw_echo_signals(side)
		draw_arc(ep, el, PI*0.5-0.9, PI*0.5+0.9, 32, Color(0.39,0.62,0.59,0.12), 1.0, true)
		draw_circle(ep, 4.0, _tone_color("gold") if e["charged"] else MUTED)
		_draw_moon(ep,bob,float(e["theta"]),10.0,Color("6a9690").lerp(_tone_color("teal"),glow),glow*1.3,Color("80a497"),1.0)
		if not chapter_done and not free_play:
			for index in range(lit_goals.size()):
				if lit_goals[index] or _goal_kind_at(index)=="main":continue
				if _goal_kind_at(index)=="relay" and side!=(0 if float(CHAPTERS[chapter]["targets"][index])<0.0 else 1):continue
				var target_angle := _echo_target_at(index,side)
				var beacon := _echo_point(side, target_angle)
				var reached: bool = cast_goal_hits[index][side]
				_glow(beacon, 18.0, _tone_color("gold"), 1.25 if reached else 0.45)
				draw_arc(beacon, 20.0 if reduced_motion else 20.0 + sin(elapsed * 2.5) * 1.2, 0.0, TAU, 32, Color(_tone_color("gold"),1.0 if reached else 0.60), 1.5, true)
				var tolerance := _goal_tolerance(index)
				draw_arc(ep,el,PI*0.5-target_angle-tolerance,PI*0.5-target_angle+tolerance,14,Color(0.91,0.80,0.50,0.32),4.0,true)
				if reached:
					draw_circle(beacon,5.0,_tone_color("gold"))
			if has_last_echo_turn[side] and (not swinging or cast_judged or dragging) and _turn_advice_for(side).is_empty():
				var previous := _echo_point(side,last_echo_turns[side])
				draw_arc(previous,6.0,0.0,TAU,20,Color(WHITE,0.50),1.0,true)
		if _pitch_labels_visible():
			_text(str(HARMONY.NIGHTS[_harmony_index()]["echo_names"][_echo_index(side)]),ep+Vector2(0.0,el+45.0),11,MUTED,true)

func _signal_echo_transfer(side: int, kind: String) -> void:
	# One light per side and stage; rapid ringing never builds a queue.
	echo_transfers = echo_transfers.filter(func(effect): return int(effect["side"])!=side or str(effect["kind"])!=kind)
	echo_transfers.append({"side":side,"kind":kind,"age":0.0})

func _draw_echo_signals(side: int) -> void:
	var ep := _echo_pivot(side)
	var el := _echo_length()
	var rest := ep+Vector2(0.0,el)
	for effect in echo_returns:
		if int(effect["side"])!=side:continue
		var t := clampf(float(effect["age"])/ECHO_SIGNAL_SECONDS,0.0,1.0)
		var fade := 1.0-t*t*(3.0-2.0*t)
		var old_angle: float = effect["angle"]
		var returning := old_angle if reduced_motion else old_angle*fade
		if absf(old_angle)>0.02:
			draw_arc(ep,el,PI*0.5-maxf(old_angle,0.0),PI*0.5-minf(old_angle,0.0),24,Color(WHITE,0.28*fade),1.2,true)
			if not reduced_motion:
				var glint := _echo_point(side,returning)
				_glow(glint,4.0,WHITE,0.65*fade)
				draw_circle(glint,1.7,Color(WHITE,0.72*fade))
		draw_arc(rest,14.0,0.0,TAU,32,Color(WHITE,0.48*fade),1.2,true)
		_glow(rest,13.0,WHITE,0.55*fade)
	for effect in echo_transfers:
		if int(effect["side"])!=side:continue
		var t := clampf(float(effect["age"])/ECHO_SIGNAL_SECONDS,0.0,1.0)
		var fade := 1.0-t*t*(3.0-2.0*t)
		var charging := str(effect["kind"])=="charge"
		var path := PackedVector2Array([
			_point((-0.66 if side==0 else 0.66) if charging else 0.0,length+15.0),
			ep+Vector2(0.0,el+20.0) if charging else ep,
			ep if charging else _echo_point(side,float(echoes[side]["theta"]))
		])
		var color := _tone_color("gold") if charging else _tone_color("teal")
		draw_polyline(path,Color(color,(0.38 if reduced_motion else 0.20)*fade),1.5,true)
		if not reduced_motion:
			var first := path[0].distance_to(path[1])
			var second := path[1].distance_to(path[2])
			var distance := (first+second)*minf(t/0.78,1.0)
			var glint := path[0].lerp(path[1],distance/maxf(first,0.001)) if distance<first else path[1].lerp(path[2],clampf((distance-first)/maxf(second,0.001),0.0,1.0))
			_glow(glint,5.0,color,0.80*fade)
			draw_circle(glint,2.0,Color(color,0.85*fade))

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
	_set_feedback(["澄んだ鐘が、水面へひろがる。","柔らかな響きと、あたたかな灯り。","透きとおる響きで、夜が少し白む。"][palette_index],2.0,0.8)
	_save()
	_publish_state()

func _play_sample(stream: AudioStreamWAV, strength: float, base_db: float = -13.0, pitch: float = 1.0) -> void:
	if muted or not started or paused or show_help or show_collection:
		return
	night_music.duck()
	var slot := voice % BELL_VOICES
	voice += 1
	_play_voice(stream,strength,base_db,slot,pitch)

func _play_voice(stream: AudioStreamWAV, strength: float, base_db: float, slot: int, pitch: float = 1.0) -> void:
	if muted or not started or paused or show_help or show_collection:
		return
	var player := players[slot]
	player.stream = stream
	player.pitch_scale = pitch
	audio_base[slot] = base_db + strength*6.0
	audio_gain[slot] = _transition_audio_gain()
	audio_duration[slot] = 0.0
	audio_stop_after[slot] = false
	_apply_voice_gain(slot)
	player.play()
	if transition_phase==1:
		_fade_voice(slot,0.0,maxf(0.001,_transition_out_seconds()-transition_time))
	elif transition_phase==2:
		_fade_voice(slot,1.0,maxf(0.001,_transition_in_seconds()-transition_time))

func _play_coda() -> void:
	if coda_started or free_play:
		return
	coda_started = true
	night_music.unlock(_music_piece_count(),true,_goal_kind()=="duet",_music_layer_mask())

func _music_piece_count() -> int:
	var count := 0
	var score: Dictionary = CHAPTERS[chapter]
	var kinds: Array = score.get("kinds",[])
	for index in range(score["targets"].size()):
		if index>=lit_goals.size() or not lit_goals[index]:continue
		var kind := str(kinds[index] if index<kinds.size() else score.get("kind","main"))
		count += 2 if kind=="duet" else 1
	return count

func _music_layer_mask() -> Array[bool]:
	var mask: Array[bool] = []
	for index in range(CHAPTERS[chapter]["targets"].size()):
		for piece in range(2 if _goal_kind_at(index)=="duet" else 1):
			mask.append(index<lit_goals.size() and lit_goals[index])
	return mask

func _coda_light() -> float:
	if reduced_motion:
		return 0.65
	var pulse := 0.0
	for at in [0.06,0.44,0.72,1.16,1.74,2.16,2.66]:
		var distance := (finish_time-float(at))/0.24
		pulse += exp(-distance*distance)*0.50
	return 0.42+pulse

func _harmony_index() -> int:
	return maxi(0,garden_night) if free_play else chapter

func _scene_index() -> int:
	return garden_night if free_play and garden_night>=0 else chapter

func _instrument_index() -> int:
	return garden_night if free_play and garden_night>=0 else (chapter if started and not free_play else 5)

func _garden_night_allowed(index: int) -> bool:
	return index==-1 or (index>=0 and index<CHAPTERS.size() and int(best_chapters[index])>0)

func _validated_garden_night(value: Variant, best: Array) -> int:
	if not _checkpoint_number(value,-1,CHAPTERS.size()-1,true):return -1
	var index := int(value)
	return index if index==-1 or int(best[index])>0 else -1

func _set_garden_night(index: int) -> void:
	if not free_play or not _garden_night_allowed(index):return
	garden_night = index
	_retry(false)
	if index>=0:
		night_music.begin(index,HARMONY.NIGHTS[index]["layers"].size(),true)
	else:
		night_music.leave(0.12)
	_layout()
	_clear_feedback()
	_set_feedback("月を引いて、この夜を奏でよう。" if index>=0 else "月を引いて、あなたの夜を奏でよう。")
	_save()
	_publish_state()

func _bell_name(index: int) -> String:
	return str(HARMONY.NIGHTS[_harmony_index()]["bell_names"][index])

func _echo_index(side: int) -> int:
	var night := garden_night if free_play and garden_night>=0 else chapter
	return side + (2 if night >= 2 else 0)

func _sound(index: int, strength: float = 0.8) -> void:
	_play_sample(sound_banks[palette_index][index],strength,-13.0,float(bell_rates[_harmony_index()][index]))

func _play_echo(side: int, strength: float) -> void:
	var index := _echo_index(side)
	_play_sample(echo_banks[palette_index][index],strength,-15.0,float(echo_rates[_harmony_index()][index]))

func _preview_pull() -> void:
	var note := clampi(int(round((theta+0.96)/0.32)),0,6)
	if note != last_pull_note and pull_note_cooldown <= 0.0:
		last_pull_note = note
		pull_note_cooldown = 0.10
		_play_sample(sound_banks[1][note],0.25,-24.0,float(bell_rates[_harmony_index()][note]))


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

func _transition_out_seconds() -> float:
	return (0.22 if reduced_motion else 0.65) if transition_action=="collection" else TRANSITION_OUT

func _transition_in_seconds() -> float:
	return (0.22 if reduced_motion else 0.65) if transition_action=="collection" else TRANSITION_IN

func _transition_quiet_seconds() -> float:
	return (0.05 if reduced_motion else 0.12) if transition_action=="collection" else TRANSITION_QUIET

func _transition_audio_gain() -> float:
	if transition_phase==0:
		return 1.0
	var t := clampf(transition_time/(_transition_out_seconds() if transition_phase==1 else _transition_in_seconds()),0.0,1.0)
	var ease := t*t*(3.0-2.0*t)
	return 1.0-ease if transition_phase==1 else ease

func _request_transition(action: String, index: int = 0) -> void:
	if action not in ["chapter","garden","journey","restart","repeat","collection"] or (transition_phase!=0 and action not in ["restart","repeat"]):
		return
	if action in ["chapter","repeat"] and (index<0 or index>=CHAPTERS.size()):
		return
	if action=="collection" and (not free_play or not _garden_night_allowed(index)):return
	var continue_time := 0.0
	if transition_phase==1:
		continue_time = transition_time
	elif transition_phase==2:
		# Reverse the curtain at its present opacity, without a bright flash.
		continue_time = _transition_out_seconds()*(1.0-clampf(transition_time/_transition_in_seconds(),0.0,1.0))
	_cancel_aim()
	transition_phase = 1
	transition_time = continue_time
	transition_action = action
	transition_chapter = index
	transition_skip_opening = action=="repeat" or (action=="chapter" and index==chapter and not free_play)
	transition_resume = {}
	if action in ["chapter","restart","repeat"]:
		listening_resume = {}
		transition_resume = {"chapter":index if action in ["chapter","repeat"] else 0,"progress":0,"casts":0,"perfects":0,"introSeen":transition_skip_opening}
	elif action=="garden" and not free_play:
		transition_resume = _snapshot_journey()
		_finish_cycle_for_garden()
	# Commit navigation intent now, not after the visual curtain. An immediate
	# refresh must not undo the explicit "start over" the player just chose.
	_save()
	# Let the old score reach silence before the next night begins.
	night_music.leave(maxf(0.001,_transition_out_seconds()-transition_time))
	for i in range(players.size()):
		if players[i].playing:
			var duration := maxf(0.001,_transition_out_seconds()-transition_time)
			_fade_voice(i,0.0,duration)
	_publish_state()

func _advance_transition(delta: float) -> void:
	if transition_phase==0:
		return
	transition_time += delta
	if transition_phase==1 and transition_time>=_transition_out_seconds()+_transition_quiet_seconds():
		transition_phase = 2
		transition_time -= _transition_out_seconds()+_transition_quiet_seconds()
		match transition_action:
			"chapter", "repeat": _new_chapter(transition_chapter)
			"garden": _enter_garden()
			"journey": _return_to_journey()
			"restart": _return_to_journey(true)
			"collection": _set_garden_night(transition_chapter)
		if transition_skip_opening:
			night_intro_seen = true
		if not free_play and not chapter_done and not night_intro_seen:
			night_opening = true
			night_opening_time = transition_time
			night_intro_seen = true
			_save()
		_sound(2,0.30)
		transition_resume = {}
		_publish_state()
	if transition_phase==2 and night_opening:
		night_opening_time = transition_time
	var duration := NIGHT_VIEW+(NIGHT_DISSOLVE if reduced_motion else NIGHT_PAN) if night_opening else _transition_in_seconds()
	if transition_phase==2 and transition_time>=duration:
		transition_phase = 0
		transition_time = 0.0
		night_opening = false
		_publish_state()

func _judge_turn() -> void:
	if chapter_done or free_play:return
	var nearest := -1
	var nearest_error := INF
	for index in range(lit_goals.size()):
		if lit_goals[index] or _goal_kind_at(index)!="main":continue
		var target: float = CHAPTERS[chapter]["targets"][index]
		var error := absf(theta-target)
		if error<=_goal_tolerance(index):
			_award_goal(error,_point(target),index)
			return
		if error<nearest_error:
			nearest = index
			nearest_error = error
	if nearest>=0 and cast_awards==0:
		_record_turn_advice(-1,theta,float(CHAPTERS[chapter]["targets"][nearest]))
	_publish_state()

func _close_cast_when_done() -> void:
	if chapter_done or free_play:
		cast_judged = true
		return
	if main_turns<2:return
	for e in echoes:
		if int(e["cast_id"])==casts and int(e["turns"])<2:return
	cast_judged = true
	var partial_sides: Array[bool] = [false,false]
	for index in range(lit_goals.size()):
		if not lit_goals[index] and _goal_kind_at(index)=="duet":
			for side in range(2):partial_sides[side] = partial_sides[side] or bool(cast_goal_hits[index][side])
	if partial_sides.any(func(hit):return hit):
		var who := "左の月" if partial_sides[0] and not partial_sides[1] else ("右の月" if partial_sides[1] and not partial_sides[0] else "小月")
		_set_feedback(who+"が届いた。次は左右の対をそろえよう。",2.5,0.9)
	if cast_awards==0 and turn_advice.is_empty():
		_record_turn_advice(-1,theta,signf(theta)*0.66,"もう少し大きく")
	_publish_state()

func _award_goal(error: float, where: Vector2, index: int = -1) -> void:
	if chapter_done or free_play:return
	if index<0:index = _goal_index()
	if lit_goals[index]:return
	_clear_turn_advice()
	lit_goals[index] = true
	cast_awards += 1
	progress = lit_goals.count(true)
	if not reduced_motion:
		light_flights.append({"from":where,"index":index,"age":0.0})
		for i in range(22):
			var a := float(i)*TAU/22.0
			particles.append({"pos":where,"velocity":Vector2(cos(a),sin(a))*(65.0+float(i%3)*22.0),"life":1.7,"color":_tone_color("gold")})
	if error<=0.065:perfects += 1
	target_pulse = 1.0
	_sound(4,0.72)
	if progress>=lit_goals.size():
		chapter_done = true
		cast_judged = true
		finish_time = 0.0
		_set_feedback(COMPLETION_FEEDBACK,COMPLETION_FEEDBACK_HOLD,COMPLETION_FEEDBACK_FADE)
		var goal: int = CHAPTERS[chapter]["strokes"]
		var rating := 3 if casts<=goal else (2 if casts<=goal*2 else 1)
		best_chapters[chapter] = maxi(int(best_chapters[chapter]),rating)
		if casts>0 and (int(best_casts[chapter])==0 or casts<int(best_casts[chapter])):best_casts[chapter] = casts
		_play_coda()
	else:
		_set_feedback("星が灯った。残る光へ、もうひと振り。",2.5,0.9)
		night_music.unlock(_music_piece_count(),false,_goal_kind_at(index)=="duet",_music_layer_mask())
	_save()
	_layout()
	_publish_state()

func _judge_echo_turn(side: int, angle: float) -> void:
	if chapter_done or free_play or cast_judged or not swinging:return
	last_echo_turns[side] = angle
	has_last_echo_turn[side] = true
	var turn := maxi(1,int(echoes[side]["turns"]))
	var nearest := -1
	var nearest_error := INF
	for index in range(lit_goals.size()):
		if lit_goals[index]:continue
		var kind := _goal_kind_at(index)
		if kind=="main":continue
		if kind=="relay" and (turn!=1 or side!=(0 if float(CHAPTERS[chapter]["targets"][index])<0.0 else 1)):continue
		if kind=="duet":
			var inward: bool = CHAPTERS[chapter]["inward"][index]
			if turn!=(2 if inward else 1):continue
		if cast_goal_checks[index][side]:continue
		var target := _echo_target_at(index,side)
		var error := absf(angle-target)
		cast_goal_checks[index][side] = true
		cast_goal_errors[index][side] = error
		cast_goal_hits[index][side] = error<=_goal_tolerance(index)
		if error<nearest_error:
			nearest = index
			nearest_error = error
		if kind=="relay":
			if cast_goal_hits[index][side]:_award_goal(error,_echo_point(side,target),index)
		else:
			duet_checked = [cast_goal_checks[index][0],cast_goal_checks[index][1]]
			duet_hits = [cast_goal_hits[index][0],cast_goal_hits[index][1]]
			duet_errors = [cast_goal_errors[index][0],cast_goal_errors[index][1]]
			duet_offsets[side] = absf(angle)-absf(target)
			if cast_goal_hits[index][side]:
				_sound(4,0.5)
				night_music.reply(casts*lit_goals.size()+index,side)
				if not cast_goal_hits[index][1-side]:
					_set_feedback(("左の月" if side==0 else "右の月")+"が届いた。"+("右の月" if side==0 else "左の月")+"も、この一振りで。",2.5,0.9)
			if cast_goal_hits[index][0] and cast_goal_hits[index][1]:
				_award_goal(maxf(float(cast_goal_errors[index][0]),float(cast_goal_errors[index][1])),_echo_point(side,target),index)
	if nearest>=0 and nearest_error>_goal_tolerance(nearest) and cast_awards==0:
		_record_turn_advice(side,angle,_echo_target_at(nearest,side))
	_publish_state()

func _begin_pull(pos: Vector2) -> void:
	if show_help or paused or show_collection:
		return
	if chapter_done:
		_set_feedback("完成した曲を聴いています。庭で月を奏でよう。")
		_publish_state()
		return
	turn_advice.clear()
	dragging = true
	keyboard_aim = false
	swinging = false
	omega = 0.0
	trail.clear()
	_update_pull(pos)
	_set_feedback("指を離すと、月が揺れる。")

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
		_set_feedback("左右へ月を引いて、指を離してみよう。")
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
	_set_feedback("月が光に届く、その一瞬を聴こう。" if not free_play else "鐘から振り子へ、あなたの音がつながる。")
	if not free_play:
		night_music.clear_replies()
		_reset_echoes(true)
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

func _journey_entry_label() -> String:
	if not listening_resume.is_empty():
		return "完成した曲を聴く"
	var fresh_cycle := journey_resume.is_empty() or (int(journey_resume.get("chapter",0))==0 and int(journey_resume.get("progress",0))==0 and int(journey_resume.get("casts",0))==0)
	if listening_resume.is_empty() and _resume_chapter()==CHAPTERS.size() and fresh_cycle:
		return "もう一度"
	if not journey_resume.is_empty() or _resume_chapter()>0:
		return "つづきへ"
	return "星を灯す遊び"

func _snapshot_journey() -> Dictionary:
	if chapter_done:
		return {"chapter":(chapter+1)%CHAPTERS.size(),"progress":0,"casts":0,"perfects":0,"introSeen":false}
	return {"chapter":chapter,"progress":progress,"casts":casts,"perfects":perfects,"lit":lit_goals.duplicate(),"introSeen":night_intro_seen}

func _start() -> void:
	var entrance_angle := _intro_angle()
	started = true
	_enter_garden(false)
	theta = entrance_angle
	intro_settle = 0.0 if reduced_motion else INTRO_SETTLE
	_sound(2,0.5)
	_publish_state()

func _enter_garden(capture: bool = true) -> void:
	if capture and not free_play:
		journey_resume = _snapshot_journey()
		_finish_cycle_for_garden()
	_new_chapter(CHAPTERS.size())
	if garden_scene.has("lights"):
		garden_lights.assign(garden_scene["lights"])
		garden_energy = float(garden_scene.get("energy",0.0))
	_set_feedback("月を引いて、あなたの夜を奏でよう。")
	_save()
	_publish_state()

func _return_to_journey(restart: bool = false) -> void:
	if free_play:
		garden_scene = {"lights":garden_lights.duplicate(),"energy":garden_energy}
	var resume: Dictionary = journey_resume if not restart else {}
	var listening: Dictionary = listening_resume.duplicate() if not restart else {}
	if restart:
		listening_resume = {}
	var index: int = int(listening.get("chapter",resume.get("chapter",0 if restart else _resume_chapter())))
	if index >= CHAPTERS.size():
		index = 0
	_new_chapter(index)
	progress = clampi(int(resume.get("progress",0)),0,CHAPTERS[chapter]["targets"].size()-1)
	_set_goal_mask(resume.get("lit"))
	casts = maxi(0,int(resume.get("casts",0)))
	perfects = maxi(0,int(resume.get("perfects",0)))
	night_intro_seen = bool(resume.get("introSeen",false)) or progress>0 or casts>0
	if not listening.is_empty():
		progress = CHAPTERS[chapter]["targets"].size()
		_set_goal_mask()
		casts = int(listening["casts"])
		perfects = int(listening["perfects"])
		chapter_done = true
		coda_started = true
		finish_time = 7.0
		night_intro_seen = true
	night_music.restore(_music_piece_count(),chapter_done,_music_layer_mask())
	_layout()
	if chapter_done:
		_clear_feedback()
		_set_feedback("完成した曲を聴いています。庭で月を奏でよう。",4.0,1.0)
	else:
		_set_feedback("金の輪で折り返すと、上の星が灯る。" if _goal_kind()=="main" else "鐘の力を、小さな月の光へ届けよう。")
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
	_reset_echoes(clear_cadence)
	if clear_cadence:
		cadence_notes.clear()
	var instruction := "光の反対側へ引いて、もうひと振り。" if not free_play else "光のない夜を、好きな音で奏でよう。"
	if _goal_kind() == "relay":
		instruction = "光のある小さな月の側へ、もうひと振り。"
	elif _goal_kind() == "duet":
		instruction = "左でも右でも、二つの月へ。"
	if clear_cadence:_set_feedback(instruction)
	_publish_state()

func _new_chapter(index: int) -> void:
	show_collection = false
	_clear_feedback()
	_clear_turn_advice()
	night_opening = false
	night_opening_time = 0.0
	night_intro_seen = false
	free_play = index == CHAPTERS.size()
	chapter = 2 if free_play else clampi(index, 0, CHAPTERS.size()-1)
	if free_play:
		garden_night = _validated_garden_night(garden_night,best_chapters)
		if garden_night>=0:
			night_music.begin(garden_night,HARMONY.NIGHTS[garden_night]["layers"].size(),true)
		else:
			night_music.leave(TRANSITION_OUT)
	else:
		night_music.begin(chapter)
	gravity_index = saved_gravity_index if free_play else 1
	has_last_turn = false
	has_last_echo_turn = [false,false]
	last_pull_note = -1
	progress = 0
	_set_goal_mask()
	intro_settle = 0.0
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
		_set_feedback("光のない夜を、好きな音で奏でよう。")
	elif _goal_kind() == "relay":
		_set_feedback("鐘から小さな月へ、力を届けよう。")
	elif _goal_kind() == "duet":
		_set_feedback("左でも右でも、二つの月を光へ。")
	else:
		_set_feedback("月を引いて放し、金の輪へ届けよう。")

func _toggle_mute() -> void:
	muted = not muted
	if muted:
		_stop_audio()
	_save()
	_publish_state()

func _input(event: InputEvent) -> void:
	if show_collection:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode==KEY_M:_toggle_mute()
			elif event.keycode in [KEY_ESCAPE,KEY_H]:
				show_collection = false
				_publish_state()
		elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
			if collection_close_rect.has_point(event.position) or not collection_panel.has_point(event.position):
				show_collection = false
			else:
				for row in range(collection_rows.size()):
					if collection_rows[row].has_point(event.position):
						show_collection = false
						var index := collection_choices[row]
						if index!=garden_night:_request_transition("collection",index)
						break
			_publish_state()
		return
	if transition_phase!=0 and not show_help:
		var interruption := false
		if event is InputEventKey:
			interruption = event.keycode in [KEY_M,KEY_P,KEY_ESCAPE,KEY_H]
		elif event is InputEventMouseButton and event.pressed:
			interruption = mute_rect.has_point(event.position) or pause_rect.has_point(event.position) or help_rect.has_point(event.position) or (paused and resume_rect.has_point(event.position))
		if not interruption:
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var pos: Vector2 = event.position
			if not started:
				if mute_rect.has_point(pos):
					_toggle_mute()
				elif _intro_moon_hit(pos):
					_start()
				return
			if show_help:
				show_help = false
				if not free_play and help_repeat_rect.has_point(pos):
					paused = false
					_request_transition("repeat",chapter)
				elif help_restart_rect.has_point(pos):
					paused = false
					_request_transition("restart")
				_publish_state()
				return
			if paused:
				if pause_rect.has_point(pos) or resume_rect.has_point(pos):
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
			elif free_play and collection_rect.has_point(pos):
				_cancel_aim()
				show_collection = true
				_stop_audio()
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
				_start()
			elif event.keycode == KEY_M:
				_toggle_mute()
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

func _action_button(rect: Rect2, label: String, primary: bool = false) -> void:
	# Keep the original full touch area around a quieter, smaller visible action.
	var visible := Rect2(rect.position+Vector2(8.0,18.0),rect.size-Vector2(16.0,36.0))
	var fill := Color(_tone_color("teal"),0.16 if primary else 0.05)
	_panel(visible,fill,Color(_tone_color("teal"),0.34 if primary else 0.17),8.0)
	var font_size := 17
	while font_size>14 and FONT.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>visible.size.x-16.0:
		font_size -= 1
	_text(label,visible.get_center()+Vector2(0.0,float(font_size)*0.34),font_size,WHITE if primary else MUTED,true)

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
	draw_set_transform(Vector2.ZERO)
	_draw_header()
	if night_opening:
		_draw_night_name()
	elif started:
		_draw_score()
		if retry_rect.size.x>0.0:
			_action_button(retry_rect, _journey_entry_label() if free_play else ("庭で月を奏でる" if chapter_done else "月を中央へ戻す"),free_play or chapter_done)
		if next_rect.size.x>0.0:
			_action_button(next_rect, "色と音色" if free_play else ("庭で月を奏でる" if chapter==CHAPTERS.size()-1 else "次の夜へ"), true)
		if free_play:_action_button(collection_rect,"集めた夜")
	else:
		_draw_intro()
	if transition_phase!=0:
		var t := clampf(transition_time/(_transition_out_seconds() if transition_phase==1 else _transition_in_seconds()),0.0,1.0)
		var ease := t*t*(3.0-2.0*t)
		draw_rect(Rect2(Vector2.ZERO,size),Color(_tone_color("ink"),ease if transition_phase==1 else 1.0-ease))
	if night_opening and reduced_motion and night_opening_time>=NIGHT_VIEW:
		var dissolve := clampf((night_opening_time-NIGHT_VIEW)/NIGHT_DISSOLVE,0.0,1.0)
		draw_rect(Rect2(Vector2.ZERO,size),Color(_tone_color("ink"),sin(dissolve*PI)))
	if show_help and started:
		_draw_help()
	if show_collection and started:_draw_collection()
	if paused and started and not show_help:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.03, 0.04, 0.78))
		_text("ひと休み", Vector2(size.x * 0.5, size.y * 0.46), 38, _tone_color("gold"), true)
		_button(resume_rect,"夜を再開する",true)
		_pause_button()

func _sky_position(index: int) -> Vector2:
	if not free_play:
		var group: Array = SKY.FIGURES[chapter]["goals"][index]
		return sky_points[int(group[0])]
	if garden_night>=0:return sky_points[index%sky_points.size()]
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

func _draw_collected_figure(index: int, points: Array, alpha: float) -> void:
	for edge in SKY.FIGURES[index]["edges"]:
		draw_line(points[int(edge[0])],points[int(edge[1])],Color(_tone_color("gold"),alpha),0.85,true)
	for at in points:
		draw_circle(at,1.8,Color(WHITE,minf(1.0,alpha+0.42)))

func _draw_collection() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color(_tone_color("ink"),0.84))
	_panel(collection_panel,Color(_tone_color("deep").darkened(0.30),0.96),Color(_tone_color("teal"),0.18),12.0)
	_text("集めた夜",Vector2(size.x*0.5,collection_panel.position.y+42.0),28,_tone_color("gold"),true)
	for row in range(collection_choices.size()):
		var index := collection_choices[row]
		var rect := collection_rows[row]
		var chosen := index==garden_night
		if chosen:_panel(rect,Color(_tone_color("teal"),0.075),Color(_tone_color("teal"),0.20),8.0)
		var figure_rect := Rect2(rect.position+Vector2(15.0,9.0),Vector2(82.0,50.0))
		if index>=0:
			var fitted: Dictionary = SKY_SCENE.fit(index,figure_rect)
			_draw_collected_figure(index,Array(fitted["points"]),0.58 if chosen else 0.27)
		else:
			var points := [figure_rect.get_center()+Vector2(-20,6),figure_rect.get_center()+Vector2(0,-7),figure_rect.get_center()+Vector2(20,4)]
			for point in range(3):
				if point>0:draw_line(points[point-1],points[point],Color(_tone_color("teal"),0.30),0.9,true)
				draw_circle(points[point],2.0,_tone_color("gold") if chosen else MUTED)
		var label: String = CHAPTERS[index]["name"] if index>=0 else "いつもの庭"
		_text(label,rect.position+Vector2(116.0,38.0),22,_tone_color("gold") if chosen else WHITE)
		var mark := rect.position+Vector2(rect.size.x-24.0,34.0)
		draw_arc(mark,7.0,0,TAU,24,Color(_tone_color("gold"),0.75 if chosen else 0.18),1.0,true)
		if chosen:draw_circle(mark,2.7,_tone_color("gold"))
	if collection_choices.size()==1:
		_text("星を灯すと、夜がここに残る。",Vector2(size.x*0.5,collection_close_rect.position.y-12.0),16,MUTED,true)
	_action_button(collection_close_rect,"閉じる")

func _draw_sky_constellation() -> void:
	if not started:
		return
	if not free_play:
		var camera := _sky_camera()
		draw_set_transform(camera["offset"],0.0,Vector2.ONE*float(camera["scale"]))
		_draw_night_stars()
		draw_set_transform(_ground_camera_offset())
		return
	if garden_night>=0:
		_draw_collected_figure(garden_night,sky_points,0.25)
		return
	var count: int = 7 if free_play else CHAPTERS[chapter]["targets"].size()
	for i in range(count):
		var pos := _sky_position(i)
		var lit := garden_lights[i]>0.23 if free_play else lit_goals[i]
		if i > 0:
			var connected: bool = lit and (garden_lights[i-1]>0.23 if free_play else lit_goals[i-1])
			var line_color := Color(_tone_color("gold"),0.32) if connected else Color(_tone_color("teal"),0.10)
			draw_line(_sky_position(i-1), pos, line_color, 1.0, true)
		if lit:
			_glow(pos, 7.0, _tone_color("gold"), _coda_light()*1.55 if chapter_done else 1.0)
			draw_line(pos + Vector2(-6,0), pos + Vector2(6,0), Color(0.96,0.87,0.64,0.6), 1.0, true)
			draw_line(pos + Vector2(0,-6), pos + Vector2(0,6), Color(0.96,0.87,0.64,0.6), 1.0, true)
		draw_circle(pos, 2.3 if lit else 1.6, _tone_color("gold") if lit else Color("335661"))
		if not free_play and _goal_kind_at(i)=="duet":
			draw_circle(pos + Vector2(7,7), 1.8, _tone_color("gold") if lit else Color("335661"))

func _sky_star_goal(index: int) -> int:
	var groups: Array = SKY.FIGURES[chapter]["goals"]
	for goal in range(groups.size()):
		if index in groups[goal]:return goal
	return -1

func _sky_star_lit(index: int) -> bool:
	var goal := _sky_star_goal(index)
	return goal<0 or lit_goals[goal]

func _draw_night_stars() -> void:
	var figure: Dictionary = SKY.FIGURES[chapter]
	for edge in figure["edges"]:
		var connected := _sky_star_lit(int(edge[0])) and _sky_star_lit(int(edge[1]))
		var color := Color(_tone_color("gold"),0.36 if chapter_done else 0.19) if connected else Color(_tone_color("teal"),0.065)
		draw_line(sky_points[int(edge[0])],sky_points[int(edge[1])],color,0.85,true)
	for index in range(sky_points.size()):
		var pos := sky_points[index]
		var goal := _sky_star_goal(index)
		var earned := goal>=0 and lit_goals[goal]
		if goal>=0 and not earned:
			draw_arc(pos,3.5,0,TAU,16,Color(_tone_color("teal"),0.31),0.7,true)
		elif earned:
			_glow(pos,5.0,_tone_color("gold"),_coda_light()*1.2 if chapter_done else 1.0)
			draw_circle(pos,2.0,_tone_color("gold"))
			draw_line(pos-Vector2(4,0),pos+Vector2(4,0),Color(_tone_color("gold"),0.55),0.75,true)
			draw_line(pos-Vector2(0,4),pos+Vector2(0,4),Color(_tone_color("gold"),0.55),0.75,true)
		else:
			draw_circle(pos,1.75,Color(WHITE,0.76 if chapter_done else 0.52))

func _night_pan() -> float:
	if not night_opening:return 1.0
	if reduced_motion:return 1.0 if night_opening_time>=NIGHT_VIEW+NIGHT_DISSOLVE*0.5 else 0.0
	var t := clampf((night_opening_time-NIGHT_VIEW)/NIGHT_PAN,0.0,1.0)
	return t*t*t*(t*(t*6.0-15.0)+10.0)

func _sky_camera() -> Dictionary:
	if not night_opening:return {"offset":Vector2.ZERO,"scale":1.0}
	var box := sky_box
	var scale := minf(minf(size.x*0.70,620.0)/box.size.x,minf(size.y*0.38,400.0)/box.size.y)
	var offset := Vector2(size.x*0.5,size.y*0.36)-box.get_center()*scale
	var pan := _night_pan()
	return {"offset":offset*(1.0-pan),"scale":lerpf(scale,1.0,pan)}

func _ground_camera_offset() -> Vector2:
	# A near plane enters from below while the distant sky draws back. Drawing
	# transforms never change physics or touch coordinates; input stays locked.
	return Vector2(0,(1.0-_night_pan())*(size.y+80.0))

func _night_name_alpha() -> float:
	return clampf((night_opening_time-0.8)/1.0,0.0,1.0)*(1.0-smoothstep(0.15,0.65,_night_pan()))

func _draw_night_name() -> void:
	var alpha := _night_name_alpha()
	if alpha<=0.0:return
	var camera := _sky_camera()
	var box := sky_box
	var initial_scale := minf(minf(size.x*0.70,620.0)/box.size.x,minf(size.y*0.38,400.0)/box.size.y)
	var name_y := maxf(size.y*0.69,size.y*0.36+box.size.y*initial_scale*0.5+68.0)
	var name_world := box.get_center()+Vector2(0,(name_y-size.y*0.36)/initial_scale)
	var pos: Vector2 = name_world*float(camera["scale"])+camera["offset"]
	var font_size := int(roundf(minf(38.0,size.x*0.069)*float(camera["scale"])/initial_scale))
	_text(["I","II","III","IV","V"][chapter],pos-Vector2(0,float(font_size)+18.0),15,Color(MUTED,alpha*0.66),true)
	_text(CHAPTERS[chapter]["name"],pos,font_size,Color(_tone_color("gold"),alpha*0.92),true)

func _flight_point(start: Vector2, finish: Vector2, t: float) -> Vector2:
	var ease_t := t*t*(3.0-2.0*t)
	return start.lerp(finish,ease_t) + Vector2(sin(t*TAU)*18.0, -sin(t*PI)*42.0)

func _draw_light_flights() -> void:
	for flight in light_flights:
		var t := clampf(float(flight["age"]) / 1.25, 0.0, 1.0)
		var start: Vector2 = flight["from"]
		var destinations: Array = [_sky_position(int(flight["index"]))]
		if not free_play:
			destinations.clear()
			for star in SKY.FIGURES[chapter]["goals"][int(flight["index"])]:
				destinations.append(sky_points[int(star)])
		for finish in destinations:
			for i in range(6):
				var tail_t := maxf(0.0,t-float(i)*0.045)
				draw_circle(_flight_point(start,finish,tail_t),2.8-float(i)*0.32,Color(0.96,0.85,0.61,0.8-float(i)*0.11))
			_glow(_flight_point(start,finish,t),7.0,_tone_color("gold"),1.2)

func _horizon_polygon(horizon: float, row: int, azimuth: float) -> PackedVector2Array:
	# Close below every ridge, including when the horizon crosses the viewport edge.
	var bottom := maxf(size.y,horizon+float(row)*14.0+20.0)
	var points := PackedVector2Array([Vector2(-20.0,bottom)])
	for i in range(27):
		var x := size.x*float(i)/26.0
		var y := horizon-8.0+float(row)*14.0+sin(float(i)*0.58+float(row)*1.9+deg_to_rad(azimuth))*12.0
		points.append(Vector2(x,y))
	points.append(Vector2(size.x+20.0,bottom))
	return points

func _draw_background() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),_tone_color("ink").lerp(_tone_color("deep"),garden_energy*0.10))
	for i in range(20):
		var y := size.y * float(i) / 20.0
		var c := _tone_color("deep").lerp(_tone_color("ink"),float(i)/20.0)
		c.a = 0.42
		draw_rect(Rect2(0.0, y, size.x, size.y / 20.0 + 1.0), c)
	_draw_catalog_sky()
	var camera := _sky_camera() if started and not free_play else {"offset":Vector2.ZERO,"scale":1.0}
	draw_set_transform(camera["offset"],0.0,Vector2.ONE*float(camera["scale"]))
	var ground_alpha := _night_pan()
	var scene: Dictionary = SKY_SCENE.scene(_scene_index())
	var horizon: float = SKY_SCENE.horizon(_scene_index(),sky_fitted)
	var summer: bool = scene["season"]=="summer"
	# This distant horizon belongs to the same tangent plane as the stars.
	# Close shore plants are a separate foreground, not a replacement horizon.
	for row in range(3):
		if horizon>size.y+60.0:break
		var pts := _horizon_polygon(horizon,row,float(scene["center_az"]))
		draw_colored_polygon(pts,Color(_tone_color("deep").darkened(0.16+float(row)*0.15),ground_alpha))
	if (summer or free_play) and horizon<size.y-160.0:
		draw_rect(Rect2(0.0,horizon+18.0,size.x,size.y-horizon),Color(_tone_color("deep").darkened(0.19),ground_alpha))
		var clock := 0.0 if reduced_motion else elapsed
		for i in range(14):
			var y := horizon+27.0+float(i)*15.0
			var width := 38.0+float(i)*11.0
			var center := size.x*0.5+sin(clock*0.17+float(i)*1.7)*4.0
			draw_line(Vector2(center-width,y),Vector2(center+width,y),Color(0.31,0.56,0.58,0.045*ground_alpha),0.8,true)
		_draw_moon_reflection(ground_alpha)
	draw_set_transform(_ground_camera_offset())
	# Gold, short musical responses belong to the nearby instrument, not the sky Moon.
	var response_y := minf(pivot.y+length+71.0,size.y-177.0)
	if free_play:
		for ring in ripples:
			var age: float = ring["age"]
			var center := Vector2(float(ring["pos"].x),response_y+27.0)
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
				var pos := Vector2(_sky_position(i).x,response_y+24.0+float(i%3)*12.0)
				_glow(pos,8.0+level*11.0,_tone_color("gold"),level*0.65)
				for j in range(4):
					var half := 5.0+float(j)*6.0+level*8.0
					var c := _tone_color("gold")
					c.a = level*(0.15-float(j)*0.026)
					draw_line(pos+Vector2(-half,float(j)*8.0),pos+Vector2(half,float(j)*8.0),c,1.0,true)
	elif chapter_done:
		var bloom := _coda_light()
		var reflection := Vector2(size.x*0.5,response_y+28.0)
		_glow(reflection,28.0,_tone_color("gold"),bloom*0.45)
		for j in range(5):
			var half := 18.0+float(j)*15.0
			draw_line(reflection+Vector2(-half,float(j)*7.0),reflection+Vector2(half,float(j)*7.0),Color(_tone_color("gold"),bloom*(0.14-float(j)*0.02)),1.0,true)
	var grass := Color("35534b") if summer else (Color("595047") if scene["season"]=="autumn" else Color("46504f"))
	for side in [-1.0, 1.0]:
		var bank := PackedVector2Array()
		for p in [Vector2(0,size.y),Vector2(0,size.y-259.0),Vector2(size.x*0.10,size.y-220.0),Vector2(size.x*0.23,size.y-181.0),Vector2(size.x*0.30,size.y)]:
			bank.append(Vector2(p.x if side<0 else size.x-p.x,p.y))
		draw_colored_polygon(bank,Color(grass.darkened(0.62),0.32))
		for i in range(7):
			var x: float = size.x * 0.5 + side * (size.x * 0.40 + float(i) * 7.0)
			var y := size.y-184.0
			var tip := Vector2(x+sin((0.0 if reduced_motion else elapsed*0.25)+float(i))*3.0+side*10.0,y-45.0-float(i%3)*17.0)
			draw_line(Vector2(x,y),tip,Color(grass,0.55),1.1,true)
			draw_line(tip+Vector2(0,13),tip+Vector2(side*12,8),Color(grass,0.65),1.1,true)
			if summer:draw_line(Vector2(x,y-12.0),tip.lerp(Vector2(x,y),0.6)+Vector2(-side*12,0),Color(grass,0.4),1.0,true)
	if scene["season"]=="winter":_draw_snow()

func _draw_catalog_sky() -> void:
	var camera := _sky_camera() if started and not free_play else {"offset":Vector2.ZERO,"scale":1.0}
	draw_set_transform(camera["offset"],0.0,Vector2.ONE*float(camera["scale"]))
	var viewport := Rect2(Vector2(-4,-4),size+Vector2(8,8))
	for star in SKY_SCENE.scene(_scene_index())["neighbors"]:
		var pos := SKY_SCENE.point(star,sky_fitted)
		if not viewport.has_point(pos*float(camera["scale"])+camera["offset"]):continue
		var brightness := pow(10.0,-0.22*(float(star[3])+1.5))
		draw_circle(pos,0.65+brightness*0.9,Color(0.76,0.85,0.88,0.09+brightness*0.25))
	_draw_sky_moon()

func _draw_sky_moon() -> void:
	if not SKY_SCENE.moon_visible(_scene_index()):return
	var moon: Dictionary = SKY_SCENE.scene(_scene_index())["moon"]
	var pos := SKY_SCENE.moon_point(_scene_index(),sky_fitted)
	var radius := float(moon["radius"])*float(sky_fitted["scale"])/float(moon["front"])
	_glow(pos,radius*1.8,Color("cfdeea"),float(moon["illum"])*0.18)
	draw_circle(pos,radius,Color(0.6,0.72,0.8,0.06))
	var lit := PackedVector2Array()
	var direction: Array = moon["light"]
	var rotation := atan2(float(direction[1]),float(direction[0]))
	for i in range(25):
		var a := -PI*0.5+PI*float(i)/24.0
		lit.append(pos+Vector2(cos(a),sin(a)).rotated(rotation)*radius)
	for i in range(25):
		var y := 1.0-2.0*float(i)/24.0
		var x := -(2.0*float(moon["illum"])-1.0)*sqrt(maxf(0.0,1.0-y*y))
		lit.append(pos+Vector2(x,y).rotated(rotation)*radius)
	draw_colored_polygon(lit,Color(0.89,0.94,0.98,0.83))

func _draw_moon_reflection(visibility: float) -> void:
	var clock := 0.0 if reduced_motion else elapsed
	for glint in SKY_SCENE.reflection(_scene_index(),sky_fitted,size.y-160.0):
		var pos: Vector2 = glint["pos"]
		var row: int = glint["row"]
		var phase := clock*0.26+float(row)*1.87
		var strength := float(glint["strength"])*(0.22+0.78*pow(maxf(0.0,sin(phase)),2.0))
		var width := 4.0+float(row)*0.75
		pos.x += sin(phase*0.73)*3.0
		var color := Color(0.82,0.89,0.96,strength*0.19*visibility)
		draw_line(pos-Vector2(width,0),pos+Vector2(width*0.35,0),color,1.0,true)
		draw_line(pos+Vector2(width*0.6,2.0),pos+Vector2(width*1.1,2.0),Color(color,color.a*0.55),0.8,true)

func _draw_snow() -> void:
	var top := size.y*0.68
	var height := maxf(20.0,size.y-177.0-top)
	var clock := 0.0 if reduced_motion else elapsed
	for i in range(12):
		var x := size.x*fposmod(float(i)*0.381966,1.0)+sin(clock*0.12+float(i))*4.0
		var y := top+fposmod(float(i)*19.7+clock*5.0,height)
		draw_circle(Vector2(x,y),0.75+float(i%3)*0.2,Color(0.82,0.9,0.93,0.18))

func _draw_header() -> void:
	if not started:
		var title_y := clampf(pivot.y-70.0,size.y*0.11,size.y*0.19)
		_text("月の振り子",Vector2(size.x*0.5,title_y),42,_tone_color("gold"),true)
		_text("Moon Pendulum",Vector2(size.x*0.5,title_y+30.0),17,Color(MUTED,0.82),true)
		return
	if not night_opening:
		_text("月の振り子",Vector2(30.0,49.0),30,_tone_color("gold"))
	if started:
		_button(mute_rect, "音 OFF" if muted else "音 ON")
		_button(help_rect, "？")
		_pause_button()
		if chapter_done and not free_play:_text("完成した曲を聴く",Vector2(28.0,100.0),17,MUTED)
		if reset_rect.size.x>0.0 and not night_opening:
			_button(reset_rect,GRAVITY_NAMES[gravity_index] if free_play else "庭へ")

func _moon_hint() -> String:
	if not started or night_opening:
		return ""
	if dragging:
		return "離す"
	if not swinging and not chapter_done and (not free_play or casts==0):
		return "月を引いて、離す"
	return ""

func _pitch_labels_visible() -> bool:
	# A note name must not sit behind the nearby gesture instruction.
	return started and _moon_hint().is_empty()

func _draw_stage() -> void:
	var arc_color := Color(0.38, 0.6, 0.59, 0.14)
	draw_arc(pivot, length, PI * 0.5 - MAX_PULL, PI * 0.5 + MAX_PULL, 80, arc_color, 1.3, true)
	draw_arc(pivot, length + 32.0, PI * 0.5 - 1.10, PI * 0.5 + 1.10, 60, Color(0.35, 0.56, 0.57, 0.055), 1.0, true)
	# The silhouette stays fixed; only the metal finish and shallow engraving vary.
	INSTRUMENT.frame(self,pivot,length,size.x,_instrument_index())
	for i in range(7):
		var pos := _point(float(BELL_ANGLES[i]), length + 15.0)
		var glow: float = bell_glows[i]
		var bob := 0.0 if reduced_motion else sin(elapsed * 4.0 + float(i)) * glow * 4.0
		pos.x += bob
		draw_line(Vector2(pos.x, pos.y - 50.0), Vector2(pos.x, pos.y - 13.0), Color(0.31, 0.47, 0.49, 0.50), 1.0)
		_glow(pos, 12.0 + glow * 7.0, _tone_color("teal"), glow * 3.0)
		INSTRUMENT.bell(self,pos,_instrument_index(),i,glow,_tone_color("teal"),WHITE)
		draw_circle(pos + Vector2(0,10), 2.0, _tone_color("gold"))
		if _pitch_labels_visible():
			_text(_bell_name(i), pos + Vector2(0, 35), 11, MUTED, true)
	if started and not chapter_done and not free_play:
		for index in range(lit_goals.size()):
			if lit_goals[index] or _goal_kind_at(index)!="main":continue
			var target: float = CHAPTERS[chapter]["targets"][index]
			var target_pos := _point(target)
			var tolerance := _goal_tolerance(index)
			var pulse := 0.75 if reduced_motion else 0.75+sin(elapsed*2.5)*0.15
			_glow(target_pos,20.0,_tone_color("gold"),pulse*1.6)
			draw_arc(pivot,length,PI*0.5-target-tolerance,PI*0.5-target+tolerance,18,Color(0.91,0.80,0.50,0.28),5.0,true)
			draw_arc(target_pos,26.0 if reduced_motion else 26.0+sin(elapsed*2.5)*2.0,0,TAU,48,Color(0.94,0.84,0.61,0.8),1.5,true)
			draw_colored_polygon(PackedVector2Array([target_pos+Vector2(0,-6),target_pos+Vector2(5,0),target_pos+Vector2(0,6),target_pos+Vector2(-5,0)]),_tone_color("gold"))
		if has_last_turn and (not swinging or cast_judged or dragging) and _turn_advice_for(-1).is_empty():
			var previous := _point(last_turn)
			draw_arc(previous,8.0,0.0,TAU,24,Color(WHITE,0.5),1.0,true)

	for i in range(1, trail.size()):
		var c := _tone_color("gold")
		c.a = float(i)/float(trail.size())*0.26
		draw_line(trail[i-1],trail[i],c,1.0+float(i)/float(trail.size())*2.1)
	for r in ripples:
		var c := _tone_color("teal")
		c.a = maxf(0.0, 1.0 - float(r["age"]) / 2.2) * 0.26
		draw_arc(r["pos"], 8.0 + float(r["age"]) * 45.0, 0, TAU, 32, c, 1.0, true)
	var moon_angle := theta if started else _intro_angle()
	var moon := _point(moon_angle)
	_draw_moon(pivot,moon,moon_angle,_moon_radius(),_tone_color("gold"),1.4,Color("86aaa2"))
	draw_circle(pivot, 6.0, _tone_color("gold"))
	draw_circle(pivot, 2.0, INK)
	if dragging:
		draw_arc(moon, 38.0, 0, TAU, 48, Color(0.64,0.89,0.82,0.4), 1.0, true)
	for p in particles:
		var c: Color = p["color"]
		c.a = clampf(float(p["life"]), 0.0, 1.0) * 0.8
		draw_circle(p["pos"], 1.8, c)
	if chapter_done:
		var glow := _coda_light()*minf(1.0,finish_time*1.8)
		_glow(Vector2(pivot.x, pivot.y + 80), 75, _tone_color("gold"), glow * 2.0)

func _completion_feedback_fade_seconds() -> float:
	return COMPLETION_FEEDBACK_FADE_REDUCED if reduced_motion else COMPLETION_FEEDBACK_FADE

func _feedback_fade_seconds() -> float:
	return minf(feedback_fade,0.5) if reduced_motion else feedback_fade

func _set_feedback(text: String, hold: float = 3.0, fade: float = 1.0) -> void:
	var current_alpha := _feedback_alpha()
	var previous_alpha := _previous_feedback_alpha()
	if text!=feedback:
		# Keep only the most visible outgoing line, never an input-driven queue.
		if current_alpha>=previous_alpha:
			feedback_previous = feedback
			feedback_previous_alpha = current_alpha
		else:
			feedback_previous_alpha = previous_alpha
		feedback = text
		feedback_blend = FEEDBACK_CROSSFADE
	feedback_hold = hold
	feedback_fade = fade
	feedback_timer = hold+_feedback_fade_seconds()

func _clear_feedback() -> void:
	feedback = ""
	feedback_timer = 0.0
	feedback_previous = ""
	feedback_previous_alpha = 0.0
	feedback_blend = 0.0

func _fade_feedback() -> void:
	feedback_timer = minf(feedback_timer,_feedback_fade_seconds())

func _advance_feedback(delta: float) -> void:
	var blending := minf(delta,feedback_blend)
	feedback_blend = maxf(0.0,feedback_blend-delta)
	if feedback_blend<=0.0:
		feedback_previous = ""
		feedback_previous_alpha = 0.0
	feedback_timer = maxf(0.0,feedback_timer-(delta-blending))

func _feedback_blend_alpha() -> float:
	var t := 1.0-clampf(feedback_blend/FEEDBACK_CROSSFADE,0.0,1.0)
	return t*t*(3.0-2.0*t)

func _previous_feedback_alpha() -> float:
	return feedback_previous_alpha*(1.0-_feedback_blend_alpha())

func _feedback_alpha() -> float:
	if feedback_timer<=0.0:return 0.0
	var remaining := clampf(feedback_timer/_feedback_fade_seconds(),0.0,1.0)
	return remaining*remaining*(3.0-2.0*remaining)*_feedback_blend_alpha()

func _draw_feedback() -> void:
	var at := Vector2(size.x*0.5,size.y-108.0)
	var previous_alpha := _previous_feedback_alpha()
	if previous_alpha>0.0:_text(feedback_previous,at,16,Color(WHITE,previous_alpha),true)
	var alpha := _feedback_alpha()
	if alpha>0.0:_text(feedback,at,16,Color(WHITE,alpha),true)

func _draw_score() -> void:
	if free_play:
		var name: String = CHAPTERS[garden_night]["name"] if garden_night>=0 else PALETTES[palette_index]["name"]
		_text(name,Vector2(size.x*0.5,size.y-137.0),18,_tone_color("gold"),true)
		_draw_feedback()
		return
	var line_y := size.y - 140.0
	_text(CHAPTERS[chapter]["name"],Vector2(28.0,line_y),19,_tone_color("gold"))
	var total: int = CHAPTERS[chapter]["targets"].size()
	for i in range(total):
		var pos := Vector2(size.x - 34.0 - float(total - 1 - i) * 18.0, line_y - 6.0)
		draw_circle(pos,4.0,_tone_color("gold") if lit_goals[i] else Color("2d4a50"))
		if not lit_goals[i] and not chapter_done:
			draw_arc(pos,6.0,0,TAU,24,_tone_color("gold"),0.8,true)
			if _goal_kind_at(i)=="duet":
				for side in range(2):
					var half := pos+Vector2(-2.3 if side==0 else 2.3,0.0)
					draw_circle(half,1.9,_tone_color("gold") if cast_goal_hits[i][side] else Color("60736d"))
	var tally := "%d振り" % casts
	var width := FONT.get_string_size(tally,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
	_text(tally,Vector2(size.x-56.0-float(total-1)*18.0-width,line_y),14,MUTED)
	_draw_feedback()

func _notify_title_rendered() -> void:
	JavaScriptBridge.eval("window.moonPendulumTitleReady=true;window.dispatchEvent(new Event('moon-pendulum-title-ready'));")

func _draw_intro() -> void:
	if not title_frame_queued and OS.has_feature("web"):
		title_frame_queued = true
		RenderingServer.frame_post_draw.connect(_notify_title_rendered,CONNECT_ONE_SHOT)
	# A quiet speaker mark conveys sound without another paragraph of copy.
	var at := mute_rect.get_center()
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
	var lines := ["1. 光の輪と反対側へ、月を引く。", "2. 指を離すと、月が反対側へ揺れる。", "3. 光の近くで折り返すと、光がつながる。", "", "小さく引けば近くへ、大きく引けば遠くへ。", "金の輪と、前の折り返しを見比べよう。", "失敗しても音は残る。何度でも奏でよう。", "", "音と休止は、右上のボタンから。", "月に触れて、左右に引いて放そう。"]
	if not free_play:
		lines = ["輪は、どれから灯してもいい。","月を持ち上げ、指を離して見守ろう。","月が戻るまで、響きを見守ろう。","一振りで、いくつかの星へ。","小さな月へは、外側の鐘から中央へ。","左右の月は、外の輪から内の輪へ。","手数を超えても、星座は結べる。","月を戻しても、星と手数は残る。","月に触れて、左右に引いて放そう。","音と休止は、右上のボタンから。"]
		lines[2] = "三振りで、この星座を" if int(CHAPTERS[chapter]["strokes"])==3 else "二振りで、この星座を"
		if _goal_kind()=="duet":lines[5] = "この一振りで、左右の月を輪へ。"
	if free_play:
		lines[0] = "光の輪のない、自由な夜。"
		lines[1] = "月を引いて放すと、鐘が歌う。"
		lines[2] = "左上の重力で、振れ方を奏で分けよう。"
		lines[5] = "右下で夜の色と、響きの手触りが変わる。"
		lines[6] = "集めた夜から、星を灯した夜を選べる。"
	if chapter_done and not free_play:
		lines = ["星座が完成した夜の曲を聴く。","この夜の響きは、好きなだけ続く。","月を引いて奏でるときは、庭へ。","音と休止は、右上のボタンから。"]
	for i in range(lines.size()):
		_text(lines[i],Vector2(cx,y+54.0+float(i)*(34.0 if free_play else 32.0)),20 if free_play else 18,WHITE,true)
	_text("タップして閉じる",Vector2(cx,y+(440.0 if free_play else 390.0)),17,MUTED,true)
	if not free_play:_button(help_repeat_rect,"この夜をやり直す")
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
			var stored_best = config.get_value("casts_best",str(i),0)
			if int(best_chapters[i])>0 and _checkpoint_number(stored_best,0,1e7,true):best_casts[i] = int(stored_best)
		var listening = _validated_listening(config.get_value("music","listening",{}),best_chapters)
		listening_resume = listening if listening is Dictionary else {}
		garden_night = _validated_garden_night(config.get_value("settings","garden_night",-1),best_chapters)

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
	var records = data.get("bestCasts",[0,0,0,0,0])
	if not records is Array or records.size()!=CHAPTERS.size():return null
	for index in range(records.size()):
		if not _checkpoint_number(records[index],0,1e7,true) or (int(records[index])>0 and int(best[index])==0):return null
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
		if journey.has("lit"):
			var lit = journey["lit"]
			if not lit is Array or lit.size()!=CHAPTERS[index]["targets"].size() or not lit.all(func(item):return item is bool) or lit.count(true)!=int(journey["progress"]):return null
			clean_journey["lit"] = lit.duplicate()
		if journey.has("introSeen"):
			if not journey["introSeen"] is bool:return null
			clean_journey["introSeen"] = journey["introSeen"]
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
	config.set_value("settings","garden_night",_validated_garden_night(data.get("gardenNight",-1),best))
	config.set_value("journey","resume",clean_journey)
	config.set_value("garden","scene",clean_garden)
	config.set_value("music","listening",listening)
	for i in range(best.size()):
		config.set_value("best",str(i),int(best[i]))
		config.set_value("casts_best",str(i),int(records[i]))
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
	var saved_night: int = transition_chapter if transition_phase!=0 and transition_action=="collection" else garden_night
	config.set_value("settings","garden_night",saved_night)
	if transition_phase==1 and not transition_resume.is_empty():
		journey_resume = transition_resume.duplicate()
	elif started and not free_play:
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
		config.set_value("casts_best",str(i),best_casts[i])
	config.save("user://moon_pendulum.cfg")
	if OS.has_feature("web"):
		# A versioned JSON checkpoint contains only the small game-state schema.
		# Storage may be blocked by browser policy; keep filesystem saving intact.
		var checkpoint := {"version":1,"revision":save_revision,"muted":muted,"palette":palette_index,"gravity":saved_gravity_index,"gardenNight":saved_night,"journey":journey_resume,"garden":garden_scene,"best":best_chapters,"bestCasts":best_casts,"listening":listening_resume}
		JavaScriptBridge.eval("(function(){try{window.localStorage.setItem("+JSON.stringify(WEB_SAVE_KEY)+","+JSON.stringify(JSON.stringify(checkpoint))+");}catch(e){}})()")

func _sky_scene_state(camera: Dictionary) -> Dictionary:
	var scene: Dictionary = SKY_SCENE.scene(_scene_index())
	var catalog: Array = []
	var visible := Rect2(Vector2.ZERO,size)
	for row in scene["neighbors"]:
		var pos: Vector2 = SKY_SCENE.point(row,sky_fitted)*float(camera["scale"])+camera["offset"]
		if visible.has_point(pos):
			catalog.append({"hr":int(row[0]),"pos":[pos.x,pos.y],"mag":row[3],"az":row[4],"alt":row[5]})
		if catalog.size()>=12:break
	var targets: Array = []
	for i in range(sky_points.size()):
		var pos: Vector2 = sky_points[i]*float(camera["scale"])+camera["offset"]
		var row: Array = scene["targets"][i]
		targets.append({"hr":int(row[0]),"pos":[pos.x,pos.y],"az":row[4],"alt":row[5]})
	var moon: Dictionary = scene["moon"]
	var moon_pos: Vector2 = SKY_SCENE.moon_point(_scene_index(),sky_fitted)*float(camera["scale"])+camera["offset"]
	var reflection: Array = []
	for glint in SKY_SCENE.reflection(_scene_index(),sky_fitted,size.y-160.0):
		var pos: Vector2 = glint["pos"]*float(camera["scale"])+camera["offset"]
		if visible.has_point(pos):reflection.append([pos.x,pos.y,glint["strength"]])
	return {"observer":SKY_SCENE.DATA.OBSERVER,"local":scene["local"],"season":scene["season"],"az":scene["center_az"],"alt":scene["center_alt"],"sunAlt":scene["sun_alt"],"horizon":SKY_SCENE.horizon(_scene_index(),sky_fitted)*float(camera["scale"])+camera["offset"].y,"projectionScale":float(sky_fitted["scale"])*float(camera["scale"]),"targets":targets,"catalog":catalog,"skyMoon":{"az":moon["az"],"alt":moon["alt"],"illum":moon["illum"],"pos":[moon_pos.x,moon_pos.y],"aboveHorizon":float(moon["alt"])>0.0,"inFrame":SKY_SCENE.moon_visible(_scene_index()) and visible.has_point(moon_pos)},"reflection":reflection,"snow":12 if scene["season"]=="winter" else 0,"decorativeClock":0.0 if reduced_motion else elapsed}

func _publish_state() -> void:
	# A read-only public QA snapshot. It cannot alter gameplay or storage.
	if OS.has_feature("web"):
		var state := {"started":started,"chapter":chapter,"kind":_goal_kind(),"palette":palette_index,"gravity":gravity_index,"energy":garden_energy,"progress":progress,"casts":casts,"launch":cast_start_angle,"complete":chapter_done,"freePlay":free_play,"muted":muted,"paused":paused,"help":show_help,"transition":transition_phase,"saveRevision":save_revision,"build":BUILD.COMMIT,"engine":Engine.get_version_info()["string"]}
		state["music"] = night_music.snapshot()
		state["collection"] = {"open":show_collection,"night":garden_night,"choices":collection_choices.duplicate(),"entry":[collection_rect.get_center().x,collection_rect.get_center().y],"rows":collection_rows.map(func(rect):return [rect.get_center().x,rect.get_center().y]),"close":[collection_close_rect.get_center().x,collection_close_rect.get_center().y],"harmony":_harmony_index(),"instrument":_instrument_index()}
		state["feedback"] = {"text":feedback,"remaining":feedback_timer,"alpha":_feedback_alpha(),"previous":{"text":feedback_previous,"alpha":_previous_feedback_alpha()},"crossfade":feedback_blend,"hold":feedback_hold,"fade":_feedback_fade_seconds()}
		state["goalPairs"] = cast_goal_hits.duplicate(true)
		state["lit"] = lit_goals.duplicate()
		state["strokeGoal"] = CHAPTERS[chapter]["strokes"]
		state["bestCasts"] = best_casts.duplicate()
		state["mainTurns"] = main_turns
		state["castJudged"] = cast_judged
		state["echoTurns"] = [echoes[0]["turns"],echoes[1]["turns"]]
		state["echoSignals"] = {"returns":echo_returns.duplicate(true),"transfers":echo_transfers.duplicate(true),"reducedMotion":reduced_motion}
		state["journeyEntry"] = _journey_entry_label()
		var camera := _sky_camera()
		state["skyScene"] = _sky_scene_state(camera)
		state["opening"] = {"active":night_opening,"seen":night_intro_seen,"time":night_opening_time,"pan":_night_pan(),"nameAlpha":_night_name_alpha() if night_opening else 0.0,"scale":camera["scale"],"offset":[camera["offset"].x,camera["offset"].y],"groundOffset":_ground_camera_offset().y,"name":CHAPTERS[chapter]["name"],"stars":sky_points.size(),"missing":SKY.FIGURES[chapter]["goals"],"bounds":[sky_box.position.x,sky_box.position.y,sky_box.size.x,sky_box.size.y]}
		var moon_angle := theta if started else _intro_angle()
		var mass := _point(moon_angle)
		var origin := _moon_origin(mass,moon_angle,_moon_radius())
		state["canvasSize"] = [size.x,size.y]
		state["moon"] = {"angle":moon_angle,"mass":[mass.x,mass.y],"origin":[origin.x,origin.y],"radius":_moon_radius(),"hitRadius":INTRO_HIT_RADIUS if not started else 0.0,"anchor":[pivot.x,pivot.y],"length":length}
		var cues: Array = []
		for cue in turn_advice:
			var word_rect := _turn_advice_word_rect(cue)
			cues.append({"side":cue["side"],"remaining":cue["remaining"],"word":cue["word"],"wordRect":[word_rect.position.x,word_rect.position.y,word_rect.size.x,word_rect.size.y]})
		state["advice"] = {"misses":miss_streak,"cues":cues,"reducedMotion":reduced_motion}
		JavaScriptBridge.eval("window.moonPendulumState = " + JSON.stringify(state) + ";")
