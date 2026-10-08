extends SceneTree
## Deterministic regression tests for the player learning / retry loop.
var game: Node
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		push_error("FAIL: " + message)
		quit(1)
		assert(condition, message)

func _initialize() -> void:
	call_deferred("run")

func playback_id(player: AudioStreamPlayer) -> int:
	return player.get_stream_playback().get_instance_id()

func advance_for(seconds: float) -> void:
	var remaining := seconds
	while remaining>0.000001:
		var delta := minf(remaining,1.0/120.0)
		game._process(delta)
		remaining -= delta

func completed_transition() -> int:
	game._stop_audio(true)
	for index in range(game.night_music.players.size()):
		game.night_music.players[index].stream_paused = false
		game.night_music.players[index].stop()
		game.night_music.voices[index]["held_tail"] = {}
		game.night_music.voices[index]["duration"] = 0.0
	game.paused = false
	game.show_help = false
	game.muted = false
	game.transition_phase = 0
	game._new_chapter(0)
	game.chapter_done = true
	game.night_music.restore(3,true)
	advance_for(0.7)
	var bass := -1
	for index in range(game.night_music.players.size()):
		if game.night_music.players[index].playing and game.night_music.voices[index]["role"]=="bass":
			bass = index
	game._request_transition("chapter",1)
	return bass

func cast_until_judged(angle: float) -> void:
	game._retry()
	game.dragging = true
	game.theta = angle
	game._release()
	for tick in range(300):
		game._process(1.0/60.0)
		game._physics_process(1.0/60.0)
		if game.cast_judged:
			break

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	check(not game.started, "Audio starts behind a user gesture")
	game.testing = true
	game.best_chapters = [0,0,0,0,0]
	game.best_casts = [0,0,0,0,0]
	game.journey_resume = {}
	game.listening_resume = {}
	game.garden_scene = {}
	game.muted = true
	var title_click := InputEventMouseButton.new()
	title_click.button_index = MOUSE_BUTTON_LEFT
	title_click.pressed = true
	title_click.position = Vector2(game.size.x*0.5,game.size.y-120.0)
	game._input(title_click)
	check(not game.started,"The title has no separate button or night link below its moon")
	game.elapsed = game.INTRO_PERIOD*0.25
	var entrance_angle: float = game._intro_angle()
	var entrance_mass: Vector2 = game._point(entrance_angle)
	var entrance_center: Vector2 = game._intro_moon_center()
	title_click.position = entrance_center+Vector2(game.INTRO_HIT_RADIUS-1.0,0)
	game._input(title_click)
	check(game.started and game.free_play,"Touching the visible title moon enters the garden")
	check(game._point(game.theta).distance_to(entrance_mass)<0.001 and game._moon_radius()==42.0,"The entrance keeps the displayed moon position and settles its size gently")
	game._process(game.INTRO_SETTLE)
	check(game._moon_radius()==25.0 and game.casts==0 and not game.swinging,"The introduction does not change garden physics or spend a stroke")
	game.started = false
	game.reduced_motion = true
	game.elapsed += 1.0
	check(game._intro_angle()==0.0,"Reduced motion keeps the title moon still")
	var title_key := InputEventKey.new()
	title_key.keycode = KEY_ENTER
	title_key.pressed = true
	game._input(title_key)
	check(game.started and game.free_play and game.intro_settle==0.0,"Enter uses the same garden entrance without reduced-motion animation")
	game.reduced_motion = false
	game._start()
	check(game.started, "Start gesture enters play")
	game._begin_pull(game.pivot + Vector2(-500.0, 10.0))
	check(absf(game.theta) <= game.MAX_PULL, "Drag cannot exceed physical angle limit")
	game._retry()
	check(game.theta == 0.0 and not game.swinging, "Retry restores stationary moon")
	var solutions := [[-0.58,0.85,1.0],[0.90,0.98],[1.0,-1.05],[-1.05,-1.20],[1.11,1.14]]
	for chapter_index in range(game.CHAPTERS.size()):
		game._new_chapter(chapter_index)
		var expected_pieces := 0
		for angle in solutions[chapter_index]:
			var before: int = game.progress
			var paired: bool = game._goal_kind()=="duet"
			game.dragging = true
			game.theta = angle
			game._release()
			for tick in range(300):
				game._process(1.0/60.0)
				game._physics_process(1.0/60.0)
			check(game.progress==before+1,"Every optional journey light is reachable")
			expected_pieces += 2 if paired else 1
			check(game.night_music.pieces==expected_pieces,"Each earned sky piece unlocks a continuing high phrase, including paired stars")
			for tick in range(240):
				game._process(1.0/60.0)
				game._physics_process(1.0/60.0)
			check(game.progress==before+1,"Finished strokes cannot award the same light twice")
		check(game.chapter_done,"Every optional night can complete")
		check(game.night_music.completed and game.night_music.completion_starts==1,"Every night reaches its full score once")
	for combo in [{"chapter":0,"angle":0.98,"lit":[false,true,true]},{"chapter":1,"angle":0.98,"lit":[true,true]},{"chapter":2,"angle":-1.09,"lit":[true,true]},{"chapter":3,"angle":1.13,"lit":[true,true]},{"chapter":4,"angle":1.14,"lit":[true,true]}]:
		game._new_chapter(combo["chapter"])
		cast_until_judged(combo["angle"])
		check(game.casts==1 and game.lit_goals==combo["lit"],"One real release can light multiple independent constellation goals")
		check(game.night_music.active_layers==game._music_layer_mask(),"A light earned out of order keeps its own musical layer")
		var settled_lights: Array = game.lit_goals.duplicate()
		for tick in range(600):
			game._process(1.0/60.0)
			game._physics_process(1.0/60.0)
		check(game.lit_goals==settled_lights and game.casts==1,"Later oscillations cannot silently fill further lights or add strokes")
		if combo["chapter"]==0:
			cast_until_judged(-0.58)
			check(game.chapter_done and game.casts==2 and game.best_casts[0]==2,"A deliberate combined stroke improves the first night's best")
		else:
			check(game.chapter_done and game.best_casts[combo["chapter"]]==1 and game.night_music.completion_starts==1,"A one-stroke constellation records one best result and one musical completion")
	game._new_chapter(0)
	cast_until_judged(0.85)
	var unordered_save: Dictionary = game._snapshot_journey()
	check(unordered_save["lit"]==[false,true,false] and unordered_save["casts"]==1,"A checkpoint remembers the actual light rather than assuming a prefix")
	game._retry()
	check(game.casts==1 and game.lit_goals==[false,true,false] and game.night_music.active_layers==[false,true,false],"Pull retry retains spent strokes, earned lights and their music")
	game.journey_resume = unordered_save
	game.listening_resume = {}
	game._return_to_journey()
	check(game.casts==1 and game.lit_goals==[false,true,false] and game.night_music.active_layers==[false,true,false],"An unordered unfinished constellation restores the same music")
	var record_before_repeat: Array = game.best_casts.duplicate()
	game._request_transition("repeat",0)
	check(game.transition_resume["casts"]==0 and game.transition_resume["progress"]==0,"Whole-night retry commits its fresh intent before the curtain")
	advance_for(game.TRANSITION_OUT+game.TRANSITION_QUIET+game.TRANSITION_IN+game.NIGHT_VIEW+game.NIGHT_PAN+0.02)
	check(game.casts==0 and game.progress==0 and game.night_music.pieces==0 and game.best_casts==record_before_repeat,"Whole-night retry clears the constellation while retaining its record")
	game.dragging = true
	game.theta = 0.07
	game._release()
	check(game.casts==0,"An abandoned tiny aiming gesture does not spend a stroke")
	game.dragging = true
	game.theta = 0.18
	game._release()
	game._release()
	check(game.casts==1,"Repeated release events cannot count one gesture twice")
	for chapter_index in range(5):
		for direction in [-1.0,1.0]:
			game._new_chapter(chapter_index)
			cast_until_judged(direction*0.18)
			check(game.progress==0 and game.casts==1 and game.cast_judged,"Weak real releases spend one stroke without inventing a light")
			game._new_chapter(chapter_index)
			cast_until_judged(direction*game.MAX_PULL)
			check(not game.chapter_done and game.casts==1,"The strongest possible pull cannot automatically complete a night")
	game._new_chapter(0)
	game.best_casts[0] = 0
	for miss in range(4):cast_until_judged(0.18)
	for angle in solutions[0]:cast_until_judged(angle)
	check(game.chapter_done and game.casts==7 and game.best_casts[0]==7,"Exceeding the suggested strokes still permits completion and records the real count")
	game._new_chapter(0)
	cast_until_judged(0.98)
	cast_until_judged(-0.58)
	check(game.best_casts[0]==2,"A replay can improve a stored stroke record")
	game._new_chapter(0)
	for angle in solutions[0]:cast_until_judged(angle)
	check(game.casts==3 and game.best_casts[0]==2,"A slower replay cannot replace the player's better record")
	# Each duet must accept the same gesture from either side. Keep the
	# smaller gestures unsuccessful so the pair still requires both echoes.
	for duet_case in [{"chapter":1,"angles":[0.98,0.90]},{"chapter":4,"angles":[1.14,1.11]}]:
		for target_index in range(2):
			for direction in [-1.0,1.0]:
				game._new_chapter(duet_case["chapter"])
				game._set_goal_mask([target_index!=0,target_index!=1])
				game.dragging = true
				game.theta = direction * duet_case["angles"][target_index]
				game._release()
				check(not game.cast_judged,"Either duet release direction remains eligible")
				for tick in range(300):
					game._process(1.0/60.0)
					game._physics_process(1.0/60.0)
				check(game.progress==2 and game.lit_goals[target_index],"Each outer and inner duet target is reachable from either side")
				check(game.cast_goal_checks[target_index][0] and game.cast_goal_checks[target_index][1] and game.cast_goal_errors[target_index].max()<=game._goal_tolerance(target_index),"Both moon turns meet the new night's tolerance")
		for direction in [-1.0,1.0]:
			game._new_chapter(duet_case["chapter"])
			game.dragging = true
			game.theta = direction * 0.5
			game._release()
			for tick in range(300):
				game._process(1.0/60.0)
				game._physics_process(1.0/60.0)
			check(game.progress==0 and game.cast_judged,"Weak duet releases cannot award a pair from either side")
			check(game.echoes[0]["cast_id"]!=game.casts and game.echoes[1]["cast_id"]!=game.casts,"Weak releases never reach the secondary moons")
	game._new_chapter(3)
	game.dragging = true
	game.theta = 1.0
	game._release()
	check(not game.cast_judged,"Either relay release stays eligible while the moon moves")
	game._retry()
	check(game.feedback.contains("小さな月"), "Relay retry keeps its own relevant instruction")
	game._new_chapter(4)
	game.dragging = true
	game.theta = -0.74
	game._release()
	for tick in range(300):
		game._process(1.0/60.0)
		game._physics_process(1.0/60.0)
	check(game.progress == 0 and game.cast_judged, "Duet requires both target turn points, not just ringing")
	game.best_chapters = [1,1,1,0,0]
	check(game._resume_chapter() == 3, "Existing three-chapter saves resume at the new relay")
	game.best_chapters = [1,1,1,1,1]
	check(game._resume_chapter() == game.CHAPTERS.size(), "Completed campaign resumes in the performance garden")
	game._new_chapter(1)
	game.omega = 2.0
	game._ring(1,0.8)
	check(game.echoes[0]["charged"], "Outer bell winds a side escapement")
	game._ring(3, 0.8)
	check(not game.echoes[0]["charged"] and absf(game.echoes[0]["omega"]) > 1.0, "Returning middle bell releases the side pendulum")
	for tick in range(200):
		game._echo_physics(1.0 / 60.0)
	check(game.chain_rings > 0, "Secondary physical motion rings the echo bell")
	game._retry()
	check(game.chain_rings == 0 and game.echoes[0]["omega"] == 0.0, "Retry stops and resets the physical chain")
	game._new_chapter(0)
	game.dragging = true
	game.theta = 0.6
	game._release()
	for tick in range(200):
		game._process(1.0 / 60.0)
		game._physics_process(1.0 / 60.0)
	check(game.progress==1 and game.lit_goals[0],"A returning main moon can light a star from the same-side release")
	check(game.casts==1,"The outbound and returning turn still count as one stroke")
	game._retry()
	game.dragging = true
	game.theta = -0.18
	game._release()
	for tick in range(200):
		game._process(1.0 / 60.0)
		game._physics_process(1.0 / 60.0)
	check(not game.turn_advice.is_empty(),"A short pull leaves a comparison with an unlit target")
	game._retry()
	game.dragging = true
	game.theta = -0.6
	game._release()
	game.paused = true
	var old_theta: float = game.theta
	game._physics_process(1.0)
	check(game.theta == old_theta, "Pause freezes physics")
	game.paused = false
	game.show_help = true
	game._physics_process(1.0)
	check(game.theta == old_theta, "Help freezes physics")
	game.show_help = false
	game._physics_process(1.0 / 60.0)
	check(game.theta != old_theta, "Play resumes after pause/help")
	game._toggle_mute()
	game._toggle_mute()
	check(game.muted, "Mute toggling returns to the expected state")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.paused and not game.dragging, "Tab / app interruption pauses safely")
	game.paused = false
	game._new_chapter(0)
	check(game.progress == 0 and game.casts == 0 and not game.chapter_done, "Chapter restart clears its results")
	game._new_chapter(game.CHAPTERS.size())
	check(game.free_play and not game.chapter_done, "Final reward opens free performance")
	game.dragging = true
	game.theta = -0.8
	game._release()
	for tick in range(240):
		game._process(1.0 / 60.0)
		game._physics_process(1.0 / 60.0)
	check(game.progress == 0 and not game.chapter_done and game.swinging, "Free performance has no scoring / forced completion")
	game._new_chapter(0)
	check(not game.free_play and game.gravity_index == 1, "Return to chapters restores standard physics")
	game._new_chapter(0)
	var held := InputEventKey.new()
	held.keycode = KEY_LEFT
	held.pressed = true
	game._input(held)
	var first_step: float = game.theta
	game._advance_keyboard_aim(0.50, -1.0)
	check(game.theta < first_step - 0.30, "Held direction adjusts continuously without OS repeat")
	var released_angle: float = game.theta
	game._advance_keyboard_aim(0.25, 0.0)
	check(game.theta == released_angle, "Released direction stops angle adjustment")
	game._retry()
	game.show_help = false
	game.paused = false
	var help_key := InputEventKey.new()
	help_key.keycode = KEY_H
	help_key.pressed = true
	game._input(help_key)
	check(game.show_help, "Keyboard H opens help")
	var close_key := InputEventKey.new()
	close_key.keycode = KEY_ESCAPE
	close_key.pressed = true
	game._input(close_key)
	check(not game.show_help and not game.paused, "Escape closes help without stacking pause")
	game._begin_pull(game.pivot + Vector2(-150,200))
	var casts_before_help: int = game.casts
	game._input(help_key)
	check(game.show_help and not game.dragging and game.theta == 0.0, "Opening help cancels an active pull")
	game._release()
	check(game.casts == casts_before_help and not game.swinging, "Help cannot launch or consume an attempt behind overlay")
	var hidden_click := InputEventMouseButton.new()
	hidden_click.button_index = MOUSE_BUTTON_LEFT
	hidden_click.pressed = true
	hidden_click.position = game.pause_rect.get_center()
	game._input(hidden_click)
	check(not game.show_help and not game.paused, "Click-anywhere help dismissal cannot trigger hidden pause control")
	game._begin_pull(game.pivot + Vector2(-150,200))
	var pause_key := InputEventKey.new()
	pause_key.keycode = KEY_P
	pause_key.pressed = true
	game._input(pause_key)
	check(game.paused and not game.dragging, "Pause cancels an active pull")
	game._release()
	check(game.casts == casts_before_help, "Paused release cannot consume a hidden attempt")
	hidden_click.position = game.reset_rect.get_center()
	var preserved_progress: int = game.progress
	game._input(hidden_click)
	check(game.progress == preserved_progress and game.paused, "Hidden controls do not activate through pause")
	game._input(pause_key)
	check(not game.paused, "Pause can resume with its documented key")
	game._start()
	check(game.free_play and not game.chapter_done,"Main entrance opens expressive garden without mandatory tasks")
	game.dragging = true
	game.theta = -1.0
	game._release()
	for tick in range(240):
		game._process(1.0/60.0)
		game._physics_process(1.0/60.0)
	check(game.garden_energy>0.05 and game.garden_lights.max()>0.2,"A gesture grows light in sky and water")
	var palette_before: int = game.palette_index
	game._cycle_palette()
	check(game.palette_index==(palette_before+1)%3,"Night changes both palette and timbre bank")
	game._new_chapter(2)
	game.progress = game.CHAPTERS[2]["targets"].size()
	game._set_goal_mask()
	game.chapter_done = true
	game._enter_garden()
	game._return_to_journey()
	check(game.chapter==3 and game.progress==0,"Garden detour returns after completed third night, not to first")
	game._new_chapter(0)
	game.progress = 1
	game._set_goal_mask()
	game.casts = 2
	game._enter_garden()
	game._return_to_journey()
	check(game.chapter==0 and game.progress==1 and game.casts==2,"An unfinished night survives an artistic detour")
	game._return_to_journey(true)
	check(game.chapter==0 and game.progress==0,"Starting over is an explicit separate choice")
	game._new_chapter(3)
	game.dragging = true
	game.theta = -0.5
	game._release()
	for tick in range(240):
		game._process(1.0/60.0)
		game._physics_process(1.0/60.0)
	check(game.cast_judged and not game.turn_advice.is_empty(),"A weak relay closes its stroke and compares a real turn")
	game._new_chapter(1)
	game.dragging = true
	game.theta = -0.68
	game._release()
	for tick in range(240):
		game._process(1.0/60.0)
		game._physics_process(1.0/60.0)
	check(game.cast_judged and game.progress==0,"A weak duet closes after the available physical turns")
	game._new_chapter(1)
	game.dragging = true
	game.theta = -1.05
	game._release()
	for tick in range(300):
		game._process(1.0/60.0)
		game._physics_process(1.0/60.0)
	check(game.progress==1 and game.perfects==0,"Duet perfect requires both echoes within the tighter tolerance")
	game._new_chapter(0)
	game.reduced_motion = true
	game._award_goal(0.01,game._point(0.55))
	check(game.particles.is_empty() and game.light_flights.is_empty(),"Reduced motion removes decorative success movement")
	game.reduced_motion = false
	game._new_chapter(0)
	game._input(held)
	game._advance_keyboard_aim(0.5,-1.0)
	var keyboard_angle: float = game.theta
	var pointer := InputEventMouseMotion.new()
	pointer.position = game._point(0.8)
	game._input(pointer)
	check(game.theta==keyboard_angle,"Mouse motion cannot hijack keyboard aiming")
	game._retry()
	# Advice follows a measured failed turn. The first miss stays visual;
	# only consecutive attempts add a short word near that same stationary mark.
	game._new_chapter(0)
	cast_until_judged(-0.18)
	check(game.progress==0 and game.miss_streak==1 and game.turn_advice.size()==1,"A measured miss adds one local comparison without earning a star")
	check(game.turn_advice[0]["word"]=="" and game.feedback_timer<=game._feedback_fade_seconds(),"A first miss uses the turn mark and lets its previous instruction fade")
	check(is_equal_approx(game.turn_advice[0]["angle"],game.last_turn) and is_equal_approx(game.turn_advice[0]["target"],game._target()),"The gap compares the actual fold-back with the current target")
	game._process(1.81)
	check(game.turn_advice.is_empty(),"The bright comparison expires instead of remaining on screen")
	cast_until_judged(-0.18)
	check(game.miss_streak==2 and game.turn_advice[0]["word"]=="もう少し大きく","Consecutive short pulls receive one concise local word")
	game._begin_pull(game._point(-0.18))
	check(game.turn_advice.is_empty() and game.miss_streak==2,"Beginning another pull clears the old comparison while preserving the attempt sequence")
	cast_until_judged(-0.58)
	check(game.progress==1 and game.turn_advice.is_empty() and game.miss_streak==0,"A real successful cast removes the advice and resets consecutive misses")
	game._new_chapter(0)
	game._set_goal_mask([false,true,true])
	cast_until_judged(-0.8)
	cast_until_judged(-0.8)
	check(game.turn_advice[0]["word"]=="少しやさしく","An overshoot asks for a gentler pull")
	game._new_chapter(0)
	cast_until_judged(0.6)
	check(game.progress==1 and game.turn_advice.is_empty(),"A successful return does not retain an obsolete wrong-side instruction")
	game._new_chapter(1)
	cast_until_judged(-0.8)
	check(game.miss_streak==1 and game.turn_advice.size()==2 and game.night_music.pieces==0,"Two missed duet moons count as one unsuccessful attempt without a music layer")
	cast_until_judged(-0.8)
	check(game.miss_streak==2 and game.turn_advice.all(func(c): return c["word"]=="もう少し大きく"),"Both duet marks explain the same repeated weak transfer")
	game._retry()
	check(game.turn_advice.is_empty() and game.miss_streak==2,"Retry removes displayed advice without making consecutive misses look like a first try")
	game._new_chapter(1)
	cast_until_judged(0.5)
	check(game.turn_advice.size()==1 and game.turn_advice[0]["side"]==-1 and is_equal_approx(game.turn_advice[0]["angle"],game.last_turn),"An uncharged duet compares the real primary turn, never an invented secondary turn")
	game._new_chapter(3)
	cast_until_judged(-0.8)
	cast_until_judged(-0.8)
	check(game.turn_advice.any(func(c):return c["side"]>=0 and c["word"]=="もう少し大きく"),"Relay advice follows its measured secondary moon among the unlit targets")
	var advice_help := InputEventKey.new()
	advice_help.keycode = KEY_H
	advice_help.pressed = true
	game._input(advice_help)
	check(game.turn_advice.is_empty() and game.miss_streak==0,"Help clears the old advice before play resumes")
	game._input(advice_help)
	cast_until_judged(-0.8)
	var advice_pause := InputEventKey.new()
	advice_pause.keycode = KEY_P
	advice_pause.pressed = true
	game._input(advice_pause)
	check(game.turn_advice.is_empty() and game.miss_streak==0,"Pause also clears a stale comparison")
	game._input(advice_pause)
	cast_until_judged(-0.8)
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.turn_advice.is_empty() and game.miss_streak==0,"Focus loss cannot revive a previous attempt's advice")
	game.paused = false
	cast_until_judged(-0.8)
	game._enter_garden()
	check(game.turn_advice.is_empty() and game.miss_streak==0,"Entering the garden removes journey advice")
	game._return_to_journey()
	check(game.turn_advice.is_empty() and game.miss_streak==0,"A saved journey resumes without old advice")
	game._new_chapter(1)
	game.reduced_motion = true
	cast_until_judged(-0.8)
	cast_until_judged(-0.8)
	check(game.turn_advice.size()==2 and game.turn_advice.all(func(c):return not c["word"].is_empty()),"Reduced motion retains the readable turn comparison and repeated-miss words")
	game.reduced_motion = false
	game._new_chapter(0)
	var checkpoint := {"version":1,"revision":12,"muted":true,"palette":2,"journey":{"chapter":3,"progress":1,"casts":3,"perfects":1},"garden":{"lights":[0.1,0.2,0.3,0.4,0.5,0.6,0.7],"energy":0.73},"best":[1,1,1,0,0]}
	var restored: ConfigFile = game._config_from_checkpoint(JSON.parse_string(JSON.stringify(checkpoint)))
	check(restored!=null and restored.get_value("meta","revision")==12,"Versioned JSON checkpoint restores its revision")
	check(restored.get_value("journey","resume")["progress"]==1 and restored.get_value("garden","scene")["lights"].size()==7,"Checkpoint keeps journey and garden state")
	check(game._config_from_checkpoint("Object(Resource,script=Resource(\"res://main.tscn\"))")==null,"Checkpoint cannot parse Object or Resource text")
	var broken: Dictionary = checkpoint.duplicate(true)
	broken["garden"]["lights"] = [0.1]
	check(game._config_from_checkpoint(broken)==null,"Malformed light arrays cannot replace a good save")
	broken = checkpoint.duplicate(true)
	broken["revision"] = INF
	check(game._config_from_checkpoint(broken)==null,"Non-finite checkpoint values are rejected")
	broken = checkpoint.duplicate(true)
	broken["journey"]["progress"] = 99
	check(game._config_from_checkpoint(broken)==null,"Out-of-range journey data is rejected")
	broken = checkpoint.duplicate(true)
	broken["version"] = true
	check(game._config_from_checkpoint(broken)==null,"Boolean schema versions fail quietly")
	broken["version"] = "1"
	check(game._config_from_checkpoint(broken)==null,"Text schema versions fail quietly")
	check(restored.get_value("settings","gravity")==1,"Old checkpoints default to standard gravity")
	check(restored.get_value("music","listening",{})=={},"Old checkpoints remain valid without an optional listening record")
	check(restored.get_value("casts_best","0",-1)==0,"Old ratings never become invented stroke records")
	var unordered_checkpoint: Dictionary = checkpoint.duplicate(true)
	unordered_checkpoint["journey"] = {"chapter":0,"progress":1,"casts":3,"perfects":1,"lit":[false,true,false]}
	unordered_checkpoint["bestCasts"] = [2,0,0,0,0]
	var unordered_config: ConfigFile = game._config_from_checkpoint(unordered_checkpoint)
	for seen in [true,false]:
		var seen_checkpoint: Dictionary = unordered_checkpoint.duplicate(true)
		seen_checkpoint["journey"]["introSeen"] = seen
		var seen_config: ConfigFile = game._config_from_checkpoint(seen_checkpoint)
		check(seen_config!=null and seen_config.get_value("journey","resume")["introSeen"]==seen,"An optional seen-sky flag round trips without changing old save version")
	for invalid_seen in [1,"true",[],{}]:
		var malformed_seen: Dictionary = unordered_checkpoint.duplicate(true)
		malformed_seen["journey"]["introSeen"] = invalid_seen
		check(game._config_from_checkpoint(malformed_seen)==null,"Malformed introduction flags cannot replace a good save")
	check(unordered_config!=null and unordered_config.get_value("journey","resume")["lit"]==[false,true,false] and unordered_config.get_value("casts_best","0")==2,"Version one extends safely with unordered lights and stroke records")
	for invalid_lit in [[true,false], [false,1,false], [true,true,false]]:
		var malformed: Dictionary = unordered_checkpoint.duplicate(true)
		malformed["journey"]["lit"] = invalid_lit
		check(game._config_from_checkpoint(malformed)==null,"Malformed light masks cannot corrupt a saved constellation")
	for invalid_records in [[true,0,0,0,0],[-1,0,0,0,0],[2,0],"2"]:
		var malformed: Dictionary = unordered_checkpoint.duplicate(true)
		malformed["bestCasts"] = invalid_records
		check(game._config_from_checkpoint(malformed)==null,"Malformed stroke records cannot replace a valid save")
	var listening_checkpoint: Dictionary = checkpoint.duplicate(true)
	listening_checkpoint["listening"] = {"chapter":1,"casts":2,"perfects":2}
	var listening_config: ConfigFile = game._config_from_checkpoint(listening_checkpoint)
	check(listening_config!=null and listening_config.get_value("music","listening")["chapter"]==1,"Completed listening state extends version one without replacing legacy progress")
	listening_checkpoint["listening"]["chapter"] = 4
	check(game._config_from_checkpoint(listening_checkpoint)==null,"A listening record cannot invent a completed night")
	listening_checkpoint["listening"] = {"chapter":1,"casts":NAN,"perfects":2}
	check(game._config_from_checkpoint(listening_checkpoint)==null,"Non-finite listening records cannot replace a valid save")
	broken = checkpoint.duplicate(true)
	broken["gravity"] = 9
	check(game._config_from_checkpoint(broken)==null,"Out-of-range gravity is rejected")
	var outline: PackedVector2Array = game._crescent_shape()
	check(outline.size()==128 and Geometry2D.triangulate_polygon(outline).size()==378,"True crescent triangulates cleanly")
	check(not Geometry2D.is_point_in_polygon(Vector2.ZERO,outline),"The missing moon region remains empty sky")
	check(Geometry2D.is_point_in_polygon(game.MOON_SHOULDER,outline),"The pendant connects to its thick shoulder")
	for angle in [-1.22,0.0,1.22]:
		var mass: Vector2 = game._point(angle)
		var rotation: float = game._moon_rotation(angle)
		var origin: Vector2 = game._moon_origin(mass,angle,25.0)
		var ring: Vector2 = origin+game.MOON_BAIL.rotated(rotation)*25.0
		check((origin+game.MOON_COM.rotated(rotation)*25.0).distance_to(mass)<0.001,"Rotating the pendant does not move its physical center")
		check((mass-ring).normalized().dot((mass-game.pivot).normalized())>0.9999,"Bail and center of mass follow the string direction")
	game.muted = false
	game.paused = false
	game.show_help = false
	game._new_chapter(0)
	game._sound(2,0.8)
	var held_voice: int = (game.voice-1)%game.BELL_VOICES
	check(game.players[held_voice].playing,"A real audio voice starts before navigation")
	game._new_chapter(1)
	check(game.players[held_voice].playing,"A core scene reset does not stop a ringing tail")
	game._request_transition("chapter",2)
	game._request_transition("garden")
	check(game.transition_action=="chapter" and game.chapter==1,"Navigation locks one destination before fade-out")
	game._process(0.16)
	check(game.audio_gain[held_voice]>0.0 and game.audio_gain[held_voice]<1.0,"Navigation fades existing audio instead of cutting immediately")
	game._process(game.TRANSITION_OUT+0.01-0.16)
	check(game.chapter==1 and game.transition_phase==1 and game._transition_audio_gain()==0.0,"The old night reaches darkness before the quiet interval")
	check(game.players[held_voice].playing and game.audio_gain[held_voice]<0.001,"Faded tails keep their natural sample lifetime")
	game._process(game.TRANSITION_QUIET)
	check(game.chapter==2 and game.transition_phase==2,"Scene changes once after the dark quiet interval")
	advance_for(game.NIGHT_VIEW+game.NIGHT_PAN)
	check(game.transition_phase==0,"Fade-in releases navigation after the new night appears")
	game._new_chapter(0)
	game._request_transition("chapter",1)
	var transition_pause_key := InputEventKey.new()
	transition_pause_key.keycode = KEY_P
	transition_pause_key.pressed = true
	game._input(transition_pause_key)
	game._process(0.5)
	check(game.paused and game.chapter==0 and game.transition_phase==1,"Pause remains available during a transition")
	game._input(transition_pause_key)
	advance_for(game.TRANSITION_OUT+game.TRANSITION_QUIET+game.TRANSITION_IN+game.NIGHT_VIEW+game.NIGHT_PAN+0.02)
	check(game.chapter==1 and game.transition_phase==0,"Resume completes exactly one pending destination")
	game._request_transition("chapter",2)
	var transition_help_key := InputEventKey.new()
	transition_help_key.keycode = KEY_H
	transition_help_key.pressed = true
	game._input(transition_help_key)
	var transition_help_click := InputEventMouseButton.new()
	transition_help_click.button_index = MOUSE_BUTTON_LEFT
	transition_help_click.pressed = true
	transition_help_click.position = game.size*0.5
	game._input(transition_help_click)
	check(not game.show_help and game.transition_phase==1,"Help body tap still works during a fade")
	game._input(transition_help_key)
	transition_help_click.position = game.help_restart_rect.get_center()
	game._input(transition_help_click)
	check(not game.show_help and game.transition_action=="restart" and game.transition_resume["chapter"]==0,"Explicit restart can replace a pending transition")
	advance_for(game.TRANSITION_OUT+game.TRANSITION_QUIET+game.TRANSITION_IN+game.NIGHT_VIEW+game.NIGHT_PAN+0.02)
	check(game.chapter==0 and game.transition_phase==0,"The replacement destination completes exactly once")
	game._request_transition("chapter",2)
	advance_for(game.TRANSITION_OUT+game.TRANSITION_QUIET+0.08)
	game._input(transition_help_key)
	transition_help_click.position = game.help_restart_rect.get_center()
	game._input(transition_help_click)
	check(game.transition_phase==1 and game.transition_time>0.0,"Restart during fade-in reverses at the existing opacity")
	advance_for(game.TRANSITION_OUT+game.TRANSITION_QUIET+game.TRANSITION_IN+game.NIGHT_VIEW+game.NIGHT_PAN+0.02)
	check(game.chapter==0 and game.transition_phase==0,"Late restart returns cleanly to the first night")
	var tail_bass := completed_transition()
	check(tail_bass>=0,"A completed transition begins with a real sustained bass")
	var old_generation: int = game.night_music.generation
	var old_phrase_notes: int = game.night_music.phrase_notes
	advance_for(0.66)
	check(game.chapter==0 and game.night_music.players[tail_bass].playing and game.night_music.voices[tail_bass]["gain"]>0.6,"The old bass still rings beyond the former complete transition")
	advance_for(game.TRANSITION_OUT-0.66-0.05)
	check(game.night_music.voices[tail_bass]["gain"]<0.003 and game.night_music.phrase_notes==old_phrase_notes,"The completed score decays close to silence without adding old notes")
	advance_for(0.06)
	check(not game.night_music.players[tail_bass].playing and game.night_music.snapshot()["audibleVoices"]==0,"The score stops only after its envelope reaches zero")
	advance_for(game.TRANSITION_QUIET-0.03)
	check(game.chapter==0 and game.transition_phase==1 and game.night_music.generation==old_generation and game.night_music.snapshot()["audibleVoices"]==0,"A real silent interval precedes the next night")
	advance_for(0.04)
	check(game.chapter==1 and game.transition_phase==2 and game.night_music.generation==old_generation+1,"The next sparse score begins once after silence")
	advance_for(game.NIGHT_VIEW+game.NIGHT_PAN+0.02)
	check(game.transition_phase==0 and game.night_music.pieces==0,"The new night opens without completed score layers")
	for interruption in [transition_pause_key,transition_help_key]:
		tail_bass = completed_transition()
		old_generation = game.night_music.generation
		advance_for(0.45)
		var held_time: float = game.transition_time
		game._input(interruption)
		advance_for(0.09)
		check(game.night_music.snapshot()["audibleVoices"]==0,"Pause and help rapidly silence a long transition tail")
		advance_for(0.5)
		check(is_equal_approx(game.transition_time,held_time) and game.chapter==0,"Pause and help freeze the curtain and its pending night")
		game._input(interruption)
		advance_for(0.2)
		check(game.night_music.players[tail_bass].playing and game.night_music.voices[tail_bass]["gain"]>0.5 and game.night_music.voices[tail_bass].get("held_tail",{}).is_empty(),"Resume returns to the remaining afterglow during fade-out")
		advance_for(game.TRANSITION_OUT+game.TRANSITION_QUIET+game.TRANSITION_IN+game.NIGHT_VIEW+game.NIGHT_PAN)
		check(game.chapter==1 and game.transition_phase==0 and game.night_music.generation==old_generation+1,"An interrupted transition completes its destination only once")
	tail_bass = completed_transition()
	advance_for(0.45)
	game._toggle_mute()
	advance_for(0.09)
	check(game.night_music.snapshot()["audibleVoices"]==0,"Mute retains its short ramp during a slow night transition")
	advance_for(0.2)
	game._toggle_mute()
	advance_for(0.2)
	check(game.transition_time>0.9 and game.night_music.players[tail_bass].playing and game.night_music.voices[tail_bass]["gain"]>0.4,"Unmuting resumes only the remaining tail while navigation keeps moving")
	game._toggle_mute()
	advance_for(game.TRANSITION_OUT+game.TRANSITION_QUIET+game.TRANSITION_IN+game.NIGHT_VIEW+game.NIGHT_PAN)
	check(game.chapter==1 and game.transition_phase==0 and game.night_music.snapshot()["audibleVoices"]==0,"A muted transition finishes silently")
	game._toggle_mute()
	advance_for(0.2)
	var old_tail_returned := false
	for index in range(game.night_music.players.size()):
		old_tail_returned = old_tail_returned or (game.night_music.players[index].playing and game.night_music.voices[index]["tail"])
	check(not old_tail_returned and game.night_music.enabled,"Unmuting after navigation cannot revive the former completed score")
	tail_bass = completed_transition()
	advance_for(0.45)
	game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.paused and game.night_music.snapshot()["audibleVoices"]==0,"Focus loss immediately silences a long afterglow")
	advance_for(0.5)
	check(game.chapter==0 and game.transition_time<0.46,"Hidden application does not consume the remaining afterglow")
	game._input(transition_pause_key)
	advance_for(0.2)
	check(game.night_music.players[tail_bass].playing and game.night_music.voices[tail_bass]["gain"]>0.5,"Returning from focus loss restores the remaining tail safely")
	advance_for(game.TRANSITION_OUT+game.TRANSITION_QUIET+game.TRANSITION_IN+game.NIGHT_VIEW+game.NIGHT_PAN)
	game._new_chapter(4)
	game.chapter_done = true
	game._layout()
	check(game.retry_rect.size==Vector2.ZERO and game.reset_rect.size==Vector2.ZERO and game.next_rect.size.x>0,"Final night exposes only one garden action")
	var final_hidden_click := InputEventMouseButton.new()
	final_hidden_click.button_index = MOUSE_BUTTON_LEFT
	final_hidden_click.pressed = true
	final_hidden_click.position = Vector2(78,105)
	game._input(final_hidden_click)
	check(game.transition_phase==0 and not game.free_play,"Hidden garden shortcut has no surviving hit area")
	game._new_chapter(0)
	check(game.next_rect.size==Vector2.ZERO and game.retry_rect.size.x>0,"An unfinished night does not show a premature next action")
	game.progress = 2
	game._set_goal_mask()
	game._process(1.0/60.0)
	game._award_goal(0.01,game._goal_position())
	check(game.coda_started and game.night_music.completed and game.night_music.pieces==3 and game.night_music.bass_entries==1,"Completion immediately starts the continuing full score and bass once")
	var bass_voice := -1
	for i in range(game.night_music.players.size()):
		if game.night_music.voices[i]["role"]=="bass" and game.night_music.voices[i]["generation"]==game.night_music.generation:
			bass_voice = i
	check(bass_voice>=0 and game.night_music.players[bass_voice].stream==game.night_music.bass_stream,"Completed score has its own sustained bass voice")
	var completed_voice_count: int = game.voice
	game._award_goal(0.01,game._goal_position())
	check(game.voice==completed_voice_count and game.progress==3,"One completed night cannot celebrate or advance twice")
	for i in range(30):
		game._sound(i%7,0.7)
	check(game.night_music.players[bass_voice].stream==game.night_music.bass_stream and game.players.size()==12 and game.night_music.players.size()==16,"Rapid bell playing cannot steal musical voices or grow either pool")
	game._request_transition("garden")
	game._process(0.16)
	check(game.night_music.players[bass_voice].playing and game.night_music.voices[bass_voice]["gain"]>0.5,"Early next action retains a gently fading completed bass")
	advance_for(game.TRANSITION_OUT+game.TRANSITION_QUIET+game.TRANSITION_IN+game.NIGHT_VIEW+game.NIGHT_PAN)
	game._toggle_mute()
	game._process(0.05)
	var sounding := false
	for player in game.players:
		sounding = sounding or player.playing
	check(not sounding,"Explicit mute stops every voice after a short anti-click ramp")
	check(game.night_music.snapshot()["audibleVoices"]==0,"Explicit mute also silences the independent musical voices")
	game.muted = false
	game.paused = false
	game.show_help = false
	game.transition_phase = 0
	game._new_chapter(1)
	game._process(1.0/60.0)
	game.night_music.reply(8,0)
	game.night_music.reply(8,0)
	check(game.night_music.replies==1 and game.night_music.pieces==0,"One duet moon replies once without awarding a permanent layer")
	game.night_music.clear_replies()
	game._process(0.13)
	check(game.night_music.pieces==0,"An unsuccessful pair leaves no unearned continuing phrase")
	game.night_music.reply(9,0)
	game.night_music.reply(9,1)
	game.night_music.unlock(2,false,true)
	game.night_music.unlock(2,false,true)
	check(game.night_music.replies==3 and game.night_music.pieces==2,"A new duet pair adds exactly two stable phrases without duplicate layers")
	game.night_music.unlock(4,true,true)
	game.night_music.unlock(4,true,true)
	check(game.night_music.completion_starts==1 and game.night_music.bass_entries==1,"Repeated completion cannot restart the bass entrance")
	var before_loop: int = game.night_music.phrase_notes
	for tick in range(900):
		game._process(1.0/60.0)
	check(game.night_music.phrase_notes>before_loop+8 and game.night_music.completed,"Full star phrases continue beyond a short celebration")
	var music_entries: int = game.night_music.bass_entries
	var held_bass := -1
	for slot in range(game.night_music.players.size()):
		if game.night_music.voices[slot]["role"]=="bass" and game.night_music.voices[slot]["generation"]==game.night_music.generation:
			held_bass = slot
	var held_playback: int = playback_id(game.night_music.players[held_bass])
	var bass_player: AudioStreamPlayer = game.night_music.players[held_bass]
	var level_before := bass_player.volume_db+AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bass_player.bus))
	game.night_music.duck()
	game._process(1.0/60.0)
	var level_ducked := bass_player.volume_db+AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bass_player.bus))
	check(level_ducked<level_before-1.5,"A physical bell gently lowers the continuing score's effective audio level")
	game._process(0.80)
	var level_recovered := bass_player.volume_db+AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bass_player.bus))
	check(absf(level_recovered-level_before)<0.01 and playback_id(bass_player)==held_playback,"The score regains its level without restarting its sustained bass")
	var music_clock: float = game.night_music.time
	game.paused = true
	game._stop_audio()
	game._process(0.08)
	check(game.night_music.time==music_clock and game.night_music.snapshot()["audibleVoices"]==0,"Pause freezes the musical score and silences it")
	check(game.night_music.players[held_bass].stream_paused,"Paused bass retains its voice while inaudible")
	check(game.night_music.players[held_bass].volume_db<-80.0,"Paused bass reaches silence at its actual audio player")
	game.paused = false
	game._process(0.20)
	check(game.night_music.bass_entries==music_entries and game.night_music.enabled,"Resume does not replay the completion entrance")
	check(playback_id(game.night_music.players[held_bass])==held_playback and not game.night_music.players[held_bass].stream_paused,"Resume keeps the original bass playback instead of stacking a second one")
	game._process(0.20)
	check(game.night_music.players[held_bass].volume_db>-30.0,"Resumed bass restores an audible gain on the retained player")
	game.show_help = true
	game._stop_audio()
	game._process(0.08)
	check(game.night_music.snapshot()["audibleVoices"]==0,"Help silences the sustained score")
	game.show_help = false
	game._process(0.20)
	check(playback_id(game.night_music.players[held_bass])==held_playback,"Closing help preserves the original musical playback")
	game._toggle_mute()
	game._process(0.08)
	check(game.night_music.snapshot()["audibleVoices"]==0,"Mute includes high phrases and sustained bass")
	game._toggle_mute()
	game._process(0.20)
	check(game.night_music.bass_entries==music_entries,"Unmuting resumes music without a new reward entrance")
	check(playback_id(game.night_music.players[held_bass])==held_playback,"Unmuting retains a single bass playback")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	game._process(0.08)
	check(game.night_music.snapshot()["audibleVoices"]==0,"A hidden application cannot keep its music audible")
	game.paused = false
	game._process(0.10)
	check(playback_id(game.night_music.players[held_bass])==held_playback,"Returning from a hidden application preserves the same bass")
	game.journey_resume = {"chapter":2,"progress":0,"casts":0,"perfects":0}
	game.listening_resume = {"chapter":1,"casts":2,"perfects":2}
	game._return_to_journey()
	game._process(0.10)
	check(game.chapter==1 and game.chapter_done and game.progress==2 and game.night_music.pieces==4,"Listening restoration lights the completed pair constellation and full score")
	check(game.night_music.bass_entries==0 and game.night_music.completion_starts==0,"Completed restoration fades in the sustained bass without repeating a reward")
	game._request_transition("chapter",2)
	check(game.listening_resume.is_empty(),"Choosing a new night clears the old listening position")
	advance_for(game.TRANSITION_OUT+game.TRANSITION_QUIET+game.TRANSITION_IN+game.NIGHT_VIEW+game.NIGHT_PAN+0.02)
	game._process(0.02)
	check(game.chapter==2 and game.night_music.night==2 and game.night_music.pieces==0 and not game.night_music.completed,"Each next night returns to its own lonely foundation")
	var cycle_best: Array = game.best_chapters.duplicate()
	var cycle_palette: int = game.palette_index
	var cycle_gravity: int = game.saved_gravity_index
	game.journey_resume = {"chapter":0,"progress":0,"casts":0,"perfects":0}
	game.listening_resume = {"chapter":4,"casts":2,"perfects":2}
	game._return_to_journey()
	check(game.chapter==4 and game.chapter_done and game.progress==2 and game.night_music.pieces==4,"Direct restoration retains the completed final night for listening")
	check(game._journey_entry_label()=="完成した夜の伴奏と遊ぶ","The completed-night entrance describes playing with the finished accompaniment")
	game._request_transition("garden")
	check(game.listening_resume.is_empty() and game.transition_resume["chapter"]==0,"Explicit final exit clears listening before a refresh can interrupt the curtain")
	advance_for(game.TRANSITION_OUT+game.TRANSITION_QUIET+game.TRANSITION_IN+game.NIGHT_VIEW+game.NIGHT_PAN+0.02)
	game._process(0.02)
	check(game.free_play and game.journey_resume["chapter"]==0 and game.journey_resume["progress"]==0,"Finishing the cycle leaves a fresh first-night journey in the garden")
	check(game._journey_entry_label()=="もう一度","The completed cycle offers a replay rather than a misleading continuation")
	game._return_to_journey()
	check(game.chapter==0 and not game.chapter_done and game.progress==0 and game.casts==0 and game.night_music.pieces==0,"Garden replay starts an unfinished first night without old score layers")
	cast_until_judged(-0.58)
	check(game.progress==1,"The moon is operable and can earn a real first-night star after replay")
	check(game.best_chapters==cycle_best and game.palette_index==cycle_palette and game.saved_gravity_index==cycle_gravity,"Replay preserves all best results and saved settings")
	var legacy_final: Dictionary = checkpoint.duplicate(true)
	legacy_final["best"] = [1,1,1,1,1]
	legacy_final["journey"] = {"chapter":0,"progress":0,"casts":0,"perfects":0}
	legacy_final["listening"] = {"chapter":4,"casts":2,"perfects":2}
	var legacy_final_config: ConfigFile = game._config_from_checkpoint(legacy_final)
	check(legacy_final_config!=null,"The former version-one final-listening save remains valid")
	game.journey_resume = legacy_final_config.get_value("journey","resume")
	game.listening_resume = legacy_final_config.get_value("music","listening")
	game._new_chapter(0)
	game.started = false
	game._start()
	check(game.free_play and game.listening_resume["chapter"]==4 and game._journey_entry_label()=="完成した夜の伴奏と遊ぶ","Title entry preserves a legacy final-listening save inside the garden")
	game._return_to_journey()
	check(game.chapter==4 and game.chapter_done and game.night_music.pieces==4 and game.night_music.completion_starts==0,"The garden restores the legacy final score without a repeated reward")
	game._enter_garden()
	check(game.listening_resume.is_empty() and game._journey_entry_label()=="もう一度","Explicitly leaving the final score still retires its listening position")
	game._return_to_journey()
	check(game.chapter==0 and not game.chapter_done,"An explicit final exit permits a fresh first-night replay")
	legacy_final.erase("listening")
	legacy_final_config = game._config_from_checkpoint(legacy_final)
	game.journey_resume = legacy_final_config.get_value("journey","resume")
	game.listening_resume = legacy_final_config.get_value("music","listening")
	check(game._journey_entry_label()=="もう一度","Completed saves from before music still offer a first-night replay")
	game.listening_resume = {"chapter":1,"casts":2,"perfects":2}
	game._return_to_journey()
	game._enter_garden()
	game._return_to_journey()
	check(game.chapter==1 and game.chapter_done and game.night_music.pieces==4,"The final-cycle fix preserves listening detours for earlier completed nights")
	game.listening_resume = {}
	var title_partial := {"chapter":0,"progress":1,"casts":3,"perfects":1,"lit":[false,true,false]}
	game.journey_resume = title_partial.duplicate(true)
	game.started = false
	title_key.keycode = KEY_M
	var before_title_mute: bool = game.muted
	game._input(title_key)
	check(not game.started and game.muted!=before_title_mute and game.journey_resume==title_partial,"Title sound settings do not enter a mode or replace a partial journey")
	title_click.position = game.mute_rect.get_center()
	game._input(title_click)
	check(not game.started and game.muted==before_title_mute and game.journey_resume==title_partial,"The speaker control is separate from the moon entrance")
	title_key.keycode = KEY_SPACE
	game._input(title_key)
	check(game.started and game.free_play and game.journey_resume==title_partial,"Space enters the garden while keeping unordered lights and spent strokes")
	game._return_to_journey()
	check(game.chapter==0 and game.lit_goals==[false,true,false] and game.casts==3 and game.night_music.active_layers==[false,true,false],"The garden restores the same partial constellation and music after title entry")
	game._new_chapter(0)
	game._stop_audio(true)
	game._new_chapter(game.CHAPTERS.size())
	check(not game._moon_hint().is_empty() and not game._pitch_labels_visible(),"The initial gesture hint has no note labels underneath")
	game.dragging = true
	game.theta = 1.0
	check(game._moon_hint()=="離す" and not game._pitch_labels_visible(),"A held outer moon cannot overlap the D5 label")
	game.theta = -1.0
	check(game._moon_hint()=="離す" and not game._pitch_labels_visible(),"The same gesture priority applies on the left")
	game._release()
	check(game._moon_hint().is_empty() and game._pitch_labels_visible(),"Note names return after release")
	game.swinging = false
	check(game._moon_hint().is_empty() and game._pitch_labels_visible(),"A familiar free garden stays quiet after settling")
	game._new_chapter(0)
	check(not game._moon_hint().is_empty() and not game._pitch_labels_visible(),"Journey gesture instructions also take priority over pitch names")
	var english_glyphs := true
	for ch in "Moon Pendulum":
		english_glyphs = english_glyphs and game.FONT.has_char(ch.unicode_at(0))
	check(english_glyphs,"The small English entrance title uses bundled glyphs")
	var missing_glyphs: Array[String] = []
	var source_text := FileAccess.get_file_as_string("res://scripts/main.gd")
	for ch in source_text:
		if ch.unicode_at(0) > 127 and not game.FONT.has_char(ch.unicode_at(0)) and ch not in missing_glyphs:
			missing_glyphs.append(ch)
	check(missing_glyphs.is_empty(), "All game UI glyphs are bundled: " + str(missing_glyphs))
	# Validate both the authored voicing and what the real players receive.
	game.muted = false
	game.paused = false
	game.show_help = false
	game.transition_phase = 0
	var pitch_sets: Array = []
	for night in range(5):
		game._new_chapter(night)
		var harmony: Dictionary = game.HARMONY.NIGHTS[night]
		var pitches: Array = harmony["pitch_classes"]
		var all_notes: Array = harmony["bells"]+harmony["echoes"]+harmony["replies"]+[harmony["bass"]]
		for event in harmony["base"]:
			all_notes.append(event[1])
		for layer in harmony["layers"]:
			for event in layer:
				all_notes.append(event[1])
		check(all_notes.all(func(m):return int(m)%12 in pitches),"Every bell, moon, reply, phrase and bass belongs to night %d's intended harmony" % night)
		check(int(harmony["bass"])%12==int(harmony["base"][0][1])%12,"Completion bass anchors the same home as the first foundation note")
		var signature: Array = []
		for i in range(7):
			var slot: int = game.voice%12
			game._ring(i,0.5)
			var heard_midi: float = game.HARMONY.BELL_REFERENCE[i]+12.0*log(game.players[slot].pitch_scale)/log(2.0)
			check(absf(heard_midi-int(harmony["bells"][i]))<0.001 and game.note_label==harmony["bell_names"][i],"A real physical bell and its label use the selected night, not a global D table")
			signature.append(int(harmony["bells"][i])-int(harmony["bells"][0]))
		check(signature not in pitch_sets,"The night changes interval structure rather than only transposing the same seven bells")
		pitch_sets.append(signature)
		for side in range(2):
			var slot: int = game.voice%12
			game._play_echo(side,0.5)
			var echo_index: int = game._echo_index(side)
			var heard_midi: float = game.HARMONY.ECHO_REFERENCE[echo_index]+12.0*log(game.players[slot].pitch_scale)/log(2.0)
			check(absf(heard_midi-int(harmony["echoes"][echo_index]))<0.001,"A physical small moon stays inside the current night harmony")
		game.last_pull_note = -1
		game.pull_note_cooldown = 0.0
		game.theta = -0.32
		var preview_slot: int = game.voice%12
		game._preview_pull()
		check(absf(game.players[preview_slot].pitch_scale-float(game.bell_rates[night][2]))<0.00001,"Pull preview uses the same night pitch as the eventual physical bell")
		var glyphs_ok := true
		for label in harmony["bell_names"]+harmony["echo_names"]:
			for ch in str(label):
				glyphs_ok = glyphs_ok and game.FONT.has_char(ch.unicode_at(0))
		check(glyphs_ok,"Every night-specific pitch label is available in the bundled font")
		game.night_music.advance(1.0/60.0,true,1.0)
		game.night_music.unlock(harmony["layers"].size(),true,true)
		var tonic_bass_ok := false
		for slot in range(16):
			if game.night_music.voices[slot]["role"]=="bass" and game.night_music.voices[slot]["generation"]==game.night_music.generation:
				tonic_bass_ok = game.night_music.players[slot].stream==game.night_music.bass_streams[night] and game.night_music.players[slot].pitch_scale==1.0
		check(tonic_bass_ok,"The completion tonic is baked into the selected sample so Web loops never revert to another key")
	check(game.night_music.bass_streams[0]==game.night_music.bass_streams[4],"The returning D night reuses its sustained tonic without a fifth bass allocation")
	game._new_chapter(1)
	game.night_music.advance(1.0/60.0,true,1.0)
	game.night_music.reply(70,0)
	var minor_reply_ok := false
	for slot in range(16):
		if game.night_music.voices[slot]["role"]=="reply" and game.night_music.voices[slot]["generation"]==game.night_music.generation:
			minor_reply_ok = absf(game.night_music.players[slot].pitch_scale-pow(2.0,-2.0/12.0))<0.00001
	check(minor_reply_ok,"The first Dorian moon reply is C5 rather than the old global F-sharp5")
	game._new_chapter(5)
	for i in range(7):
		var slot: int = game.voice%12
		game._sound(i,0.5)
		check(game.players[slot].pitch_scale==1.0 and game._bell_name(i)==game.NOTE_NAMES[i],"Garden returns every reused bell voice to its original D pentatonic pitch")
	game.muted = true
	game.transition_phase = 0
	game.paused = false
	game.show_help = false
	game._new_chapter(5)
	game.journey_resume = {"chapter":0,"progress":0,"casts":0,"perfects":0}
	game.listening_resume = {}
	game._request_transition("journey")
	advance_for(game.TRANSITION_OUT+game.TRANSITION_QUIET+0.03)
	check(game.night_opening and game.chapter==0 and game._night_pan()==0.0,"A first night reveals only its incomplete sky after the quiet interval")
	check(game._night_name_alpha()==0.0 and game._moon_hint().is_empty(),"The constellation precedes its name and gesture copy")
	check(game._snapshot_journey()["introSeen"],"Seeing the sky is persisted before an interruption or first cast")
	var locked_casts: int = game.casts
	for keycode in [KEY_RIGHT,KEY_SPACE,KEY_ENTER,KEY_R]:
		var locked_key := InputEventKey.new()
		locked_key.pressed = true
		locked_key.keycode = keycode
		game._input(locked_key)
	check(game.casts==locked_casts and not game.dragging and game.transition_action=="journey","Repeated game input cannot aim, spend strokes or navigate during the sky introduction")
	advance_for(1.0)
	check(game._night_name_alpha()>0.0 and game._night_pan()==0.0,"The name emerges quietly while the sky stays still")
	var opening_time: float = game.night_opening_time
	game._input(transition_pause_key)
	advance_for(0.5)
	check(is_equal_approx(game.night_opening_time,opening_time),"Pause freezes the viewing interval and camera")
	game._input(transition_pause_key)
	game._input(transition_help_key)
	advance_for(0.5)
	check(is_equal_approx(game.night_opening_time,opening_time),"Help also freezes the introduction")
	game._input(transition_help_key)
	advance_for(game.NIGHT_VIEW-opening_time+game.NIGHT_PAN*0.5)
	check(absf(game._night_pan()-0.5)<0.001 and game._ground_camera_offset().y>0.0,"The slow descent reveals the instrument through drawing transforms")
	check(game.theta==0.0 and game.omega==0.0 and game.casts==0,"Camera motion cannot change pendulum physics")
	advance_for(game.NIGHT_PAN)
	check(not game.night_opening and game.transition_phase==0 and game._ground_camera_offset()==Vector2.ZERO,"Controls unlock only after the camera reaches ordinary play coordinates")
	var seen_journey: Dictionary = game._snapshot_journey()
	game._enter_garden()
	game.journey_resume = seen_journey
	game._request_transition("journey")
	advance_for(game.TRANSITION_OUT+game.TRANSITION_QUIET+game.TRANSITION_IN+0.02)
	check(game.transition_phase==0 and not game.night_opening,"A zero-cast return to the same seen sky does not repeat the introduction")
	game._request_transition("repeat",0)
	advance_for(game.TRANSITION_OUT+game.TRANSITION_QUIET+game.TRANSITION_IN+0.02)
	check(game.transition_phase==0 and not game.night_opening and game.night_intro_seen,"Same-night retry keeps the introduction seen")
	game._new_chapter(5)
	game.journey_resume = {"chapter":2,"progress":0,"casts":1,"perfects":0}
	game._request_transition("journey")
	advance_for(game.TRANSITION_OUT+game.TRANSITION_QUIET+game.TRANSITION_IN+0.02)
	check(game.chapter==2 and not game.night_opening and game.transition_phase==0,"Legacy partial saves skip the introduction even before a first success")
	game.reduced_motion = true
	game._request_transition("chapter",3)
	advance_for(game.TRANSITION_OUT+game.TRANSITION_QUIET+game.NIGHT_VIEW-0.01)
	check(game.night_opening and game._night_pan()==0.0,"Reduced motion holds a stationary sky for the full viewing interval")
	advance_for(game.NIGHT_DISSOLVE+0.02)
	check(not game.night_opening and game.transition_phase==0 and game._night_pan()==1.0,"Reduced motion dissolves to the instrument without a moving camera")
	game.reduced_motion = false
	var total_major_stars := 0
	var total_missing_stars := 0
	for night in range(5):
		game._new_chapter(night)
		var figure: Dictionary = game.SKY.FIGURES[night]
		var observed: Dictionary = game.SKY_SCENE.scene(night)
		check(observed["targets"].map(func(star):return int(star[0]))==figure["hr"],"Catalog targets preserve all original gameplay identities and order")
		check(observed["targets"].all(func(star):return float(star[5])>5.0),"Every target is above the physical horizon at its fixed observation time")
		check(float(observed["sun_alt"]) < -18.0,"Every frozen scene is after astronomical twilight")
		check(observed["neighbors"].all(func(star):return float(star[5])>0.0 and float(star[3])<=5.0),"Background stars have catalog brightness and are above the same horizon")
		total_major_stars += figure["hr"].size()
		var assigned: Array = []
		for goal in range(figure["goals"].size()):
			var group: Array = figure["goals"][goal]
			check(group.size()==(2 if game._goal_kind_at(goal)=="duet" else 1),"A real constellation preserves the existing goal-to-score-layer count")
			for index in group:
				check(index>=0 and index<figure["hr"].size() and index not in assigned,"Each missing star belongs to exactly one reachable goal")
				assigned.append(index)
				total_missing_stars += 1
		check(figure["hr"].size()>assigned.size(),"Every incomplete constellation already contains quiet major stars")
		var name_font_ok := true
		for character in game.CHAPTERS[night]["name"]:
			name_font_ok = name_font_ok and game.FONT.has_char(character.unicode_at(0))
		check(name_font_ok,"All five real constellation names use available bundled font glyphs")
	check(total_major_stars==39 and total_missing_stars==15,"Five richer skies retain 11 tasks and exactly 15 musical lights")
	check(game.SKY_SCENE.DATA.OBSERVER["latitude"]==35.0 and game.SKY_SCENE.DATA.OBSERVER["longitude"]==135.0,"The artwork has one fixed Japanese reference site, independent of user location")
	var original_size := root.size
	for resolution in [Vector2i(390,844), Vector2i(320,568), Vector2i(1200,863)]:
		root.size = resolution
		await process_frame
		game._layout()
		var visible := Rect2(Vector2.ZERO, game.size)
		check(visible.encloses(game.retry_rect) and visible.encloses(game.next_rect), "Bottom controls fit resized viewport")
		check(visible.encloses(game.mute_rect) and visible.encloses(game.pause_rect), "Header controls fit resized viewport")
		var scale: float = float(resolution.x) / game.size.x
		check(game.retry_rect.size.y * scale >= 44.0, "Portrait retry touch target is at least 44 physical pixels")
		var title_area := Rect2(game._intro_moon_center()-Vector2.ONE*game.INTRO_HIT_RADIUS,Vector2.ONE*game.INTRO_HIT_RADIUS*2.0)
		check(visible.encloses(title_area),"The moving title moon and its full hit area fit the viewport")
		check(not title_area.intersects(game.mute_rect),"Sound settings cannot overlap the moon entrance")
		check(game.INTRO_HIT_RADIUS*2.0*scale>=44.0,"The title moon remains a full touch target on narrow screens")
		for night in range(5):
			game._new_chapter(night)
			check(visible.encloses(game.sky_box),"Every major-star figure fits the final sky on wide and narrow screens")
			check(game.sky_box.end.y<=game.pivot.y-34.0,"The larger sky leaves clear space above the instrument crossbar")
			check(not game.sky_box.intersects(game.reset_rect),"The expanded star figure never covers the garden control")
			game.night_opening = true
			game.night_opening_time = 2.0
			var camera: Dictionary = game._sky_camera()
			var hero := Rect2(game.sky_box.position*float(camera["scale"])+camera["offset"],game.sky_box.size*float(camera["scale"]))
			check(visible.encloses(hero) and hero.size.y>=game.sky_box.size.y,"The introduction fits a larger uniformly scaled constellation with whitespace")
			var initial: Dictionary = game._sky_scene_state(camera)
			game.night_opening_time = 5.5
			var during: Dictionary = game._sky_scene_state(game._sky_camera())
			var first_a: Array = initial["targets"][0]["pos"]
			var first_b: Array = initial["targets"][-1]["pos"]
			var later_a: Array = during["targets"][0]["pos"]
			var later_b: Array = during["targets"][-1]["pos"]
			var first_distance := Vector2(first_a[0]-first_b[0],first_a[1]-first_b[1]).length()/float(initial["projectionScale"])
			var later_distance := Vector2(later_a[0]-later_b[0],later_a[1]-later_b[1]).length()/float(during["projectionScale"])
			check(absf(first_distance-later_distance)<0.00001,"The celestial projection remains rigid throughout the downward pan")
			game.night_opening = false
			var ground: Dictionary = game._sky_scene_state(game._sky_camera())
			check(ground["reflection"].is_empty() if night!=4 else not ground["reflection"].is_empty(),"Moonlight appears only on the summer water with an above-horizon Moon")
			check(ground["skyMoon"]["inFrame"] if night==4 else not ground["skyMoon"]["inFrame"],"The actual sky Moon occupies only its computed visible field")
		check([-game.MAX_PULL,0.0,game.MAX_PULL].all(func(angle):return game.stage_rect.has_point(game._point(angle))),"The compact footer preserves touch access at rest and both full pull angles")
		for direction in [-1.0,1.0]:
			game._new_chapter(1)
			cast_until_judged(direction*0.5)
			cast_until_judged(direction*0.5)
			var weak_word: Rect2 = game._turn_advice_word_rect(game.turn_advice[0])
			check(weak_word.has_area() and visible.encloses(weak_word),"Repeated weak-transfer advice remains visible inside either side of each viewport")
			var clear_of_notes := true
			for i in range(7):
				var note_at: Vector2 = game._point(game.BELL_ANGLES[i],game.length+15.0)+Vector2(0,35)
				var note_width: float = game.FONT.get_string_size(game._bell_name(i),HORIZONTAL_ALIGNMENT_LEFT,-1,11).x
				clear_of_notes = clear_of_notes and not weak_word.intersects(Rect2(note_at-Vector2(note_width*0.5,13),Vector2(note_width,17)))
			for side in range(2):
				var note_at: Vector2 = game._echo_pivot(side)+Vector2(0,game._echo_length()+45.0)
				clear_of_notes = clear_of_notes and not weak_word.intersects(Rect2(note_at-Vector2(16,13),Vector2(32,17)))
			check(clear_of_notes,"Local weak-transfer advice cannot cover primary or secondary note names")
		game._new_chapter(1)
		cast_until_judged(-0.8)
		cast_until_judged(-0.8)
		check(game.turn_advice.all(func(c):return game._turn_advice_word_rect(c).has_area() and visible.encloses(game._turn_advice_word_rect(c))),"Both missed duet words fit even the narrowest viewport")
	root.size = original_size
	# Message opacity is independent of gameplay and has bounded replacement state.
	game.transition_phase = 0
	game.night_opening = false
	game.paused = false
	game.show_help = false
	game.muted = true
	for reduced in [false,true]:
		game.reduced_motion = reduced
		for timing in [[3.0,1.0],[2.5,0.9],[2.0,0.8],[3.5,1.5]]:
			game._clear_feedback()
			game._set_feedback("月を引いて、離す",timing[0],timing[1])
			game._advance_feedback(game.FEEDBACK_CROSSFADE)
			check(game._feedback_alpha()==1.0,"Every message reaches full opacity before its reading time")
			game._advance_feedback(timing[0])
			check(is_equal_approx(game._feedback_alpha(),1.0),"The full reading time is preserved")
			game._advance_feedback(game._feedback_fade_seconds()*0.5)
			check(is_equal_approx(game._feedback_alpha(),0.5),"Every message fades smoothly, including reduced motion")
			game._advance_feedback(game._feedback_fade_seconds()*0.5+0.001)
			check(game._feedback_alpha()==0.0,"Expired messages leave no residual opacity")
	game._clear_feedback()
	game._set_feedback("月を引いて、離す")
	game._advance_feedback(0.3)
	game._set_feedback("指を離すと、月が揺れる。")
	check(game._previous_feedback_alpha()==1.0 and game._feedback_alpha()==0.0,"Replacement retains the outgoing line without a blank frame")
	game._advance_feedback(0.15)
	check(is_equal_approx(game._previous_feedback_alpha()+game._feedback_alpha(),1.0),"The replacement crossfade keeps the combined opacity")
	for index in range(50):
		game._set_feedback("月を引いて、離す" if index%2==0 else "指を離すと、月が揺れる。")
		game._advance_feedback(0.01)
	game._advance_feedback(5.0)
	check(game.feedback_previous=="" and game._feedback_alpha()==0.0,"Rapid input cannot leave a message queue or old alpha")
	game._set_feedback("月を引いて、離す")
	var frozen_feedback: float = game.feedback_timer
	game.paused = true
	game._process(1.0)
	check(game.feedback_timer==frozen_feedback,"Pause preserves message reading time")
	game.paused = false
	game.show_help = true
	game._process(1.0)
	check(game.feedback_timer==frozen_feedback,"Help preserves message reading time")
	game.show_help = false
	game._new_chapter(4)
	check(game.feedback_previous=="","A new night discards inappropriate outgoing copy behind the curtain")
	cast_until_judged(1.20)
	check(game.progress==0 and game.cast_goal_hits==[[true,false],[true,false]],"Scorpio's two left marks are partial matches, not completed pairs")
	check(game.feedback.contains("左の月が届いた"),"A judged partial cast acknowledges its reached side")
	game._retry()
	check(game.cast_goal_hits==[[false,false],[false,false]] and game.casts==1,"Returning moons clears attempt marks while retaining spent strokes")
	var resume_tap := InputEventMouseButton.new()
	resume_tap.button_index = MOUSE_BUTTON_LEFT
	resume_tap.pressed = true
	resume_tap.position = game.resume_rect.get_center()
	game.paused = true
	game._input(resume_tap)
	check(not game.paused,"The labeled pause button resumes by tapping")
	game._request_transition("chapter",1)
	game.paused = true
	game._input(resume_tap)
	check(not game.paused and game.transition_phase==1,"The labeled resume button also works during a paused curtain")
	game.transition_phase = 0
	game.dragging = true
	game._set_feedback("指を離すと、月が揺れる。")
	game._cancel_aim()
	check(not game.dragging and game.feedback=="月を引いて、離す。","Cancelling a held gesture replaces its stale release instruction")
	# Garden collections are optional v1 data; they never grant an uncleared night.
	var collection_save: Dictionary = checkpoint.duplicate(true)
	collection_save["best"] = [3,0,3,0,3]
	collection_save["bestCasts"] = [3,0,2,0,2]
	collection_save["journey"] = {"chapter":2,"progress":1,"casts":3,"perfects":1,"lit":[true,false]}
	collection_save["listening"] = {"chapter":4,"casts":2,"perfects":2}
	var old_collection_config = game._config_from_checkpoint(collection_save)
	check(old_collection_config!=null and old_collection_config.get_value("settings","garden_night")==-1,"Old saves retain the standard garden without a collection field")
	for value in [-2,5,1,3,"2",true,1.5,NAN,INF]:
		collection_save["gardenNight"] = value
		var cleaned = game._config_from_checkpoint(collection_save)
		check(cleaned!=null and cleaned.get_value("settings","garden_night")==-1 and cleaned.get_value("journey","resume")==collection_save["journey"],"An invalid or locked collection selection preserves valid journey data")
	for index in [-1,0,2,4]:
		collection_save["gardenNight"] = index
		var cleaned = game._config_from_checkpoint(collection_save)
		check(cleaned.get_value("settings","garden_night")==index and cleaned.get_value("music","listening")==collection_save["listening"],"A valid collection selection keeps completed-score listening intact")
	game.best_chapters.assign([3,0,3,0,3])
	game.garden_night = -1
	game.transition_phase = 0
	game.paused = false
	game.show_help = false
	game.reduced_motion = false
	game._enter_garden(false)
	check(game.collection_choices==[-1,0,2,4],"The collection lists the standard garden and only completed nights")
	var collection_journey: Dictionary = game.journey_resume.duplicate(true)
	var collection_records: Array = game.best_casts.duplicate()
	game._request_transition("collection",1)
	check(game.transition_phase==0 and game.garden_night==-1,"A locked night cannot be selected through a transition request")
	game._set_garden_night(2)
	check(game.free_play and not game.chapter_done and game._harmony_index()==2 and game._scene_index()==2 and game._instrument_index()==2,"A collected night changes the playable garden's harmony, scene and instrument finish together")
	check(game.night_music.night==2 and game.night_music.completed and game.night_music.pieces==2,"The collected night restores all of its authored phrases without a new achievement")
	var collection_casts: int = game.casts
	game._begin_pull(game._point(0.0))
	game._set_pull_angle(0.7)
	game._release()
	check(game.swinging and game.casts==collection_casts+1,"The completed collection remains freely playable")
	check(game.journey_resume==collection_journey and game.best_casts==collection_records,"Collection performance cannot rewrite journey progress or stroke records")
	game.muted = false
	game._process(0.02)
	var collection_clock: float = game.night_music.time
	var collection_theta: float = game.theta
	game._sound(2,0.8)
	var collection_bell: int = (game.voice-1)%game.BELL_VOICES
	var collection_gain: float = game.audio_gain[collection_bell]
	game._open_collection()
	check(game.collection_opacity==0.0 and game._collection_blocking(),"Opening the collection blocks gestures immediately without an instant visual curtain")
	resume_tap.position = game.collection_rows[1].get_center()
	game._input(resume_tap)
	check(game.show_collection and game.garden_night==2 and game.transition_phase==0,"A collection row cannot be chosen while the surface is still invisible")
	resume_tap.position = game.collection_close_rect.get_center()
	game._input(resume_tap)
	check(game.show_collection,"A rapid second tap cannot cut away the invisible opening surface")
	game._process(0.10)
	game._physics_process(0.10)
	check(game.night_music.time>collection_clock and game.theta==collection_theta and game.night_music.snapshot()["audibleVoices"]>0,"The choice surface holds motion while its accompaniment continues softly")
	check(game.players[collection_bell].playing and game.audio_gain[collection_bell]==collection_gain,"Opening the collection preserves the ringing bell's natural tail")
	check(game._collection_alpha()>0.0 and game._collection_alpha()<1.0 and game._collection_audio_gain()>game.COLLECTION_MUSIC_GAIN,"The choice surface and music gain fade through intermediate levels")
	advance_for(0.55)
	check(game._collection_alpha()==1.0 and is_equal_approx(game._collection_audio_gain(),game.COLLECTION_MUSIC_GAIN),"The open collection retains a quiet accompaniment instead of silence")
	game._input(resume_tap)
	check(game._collection_blocking() and game._collection_alpha()==1.0,"Closing retains the modal until its fade completes")
	advance_for(0.20)
	check(game._collection_alpha()>0.0 and game._collection_alpha()<1.0 and game._collection_audio_gain()>game.COLLECTION_MUSIC_GAIN,"Closing restores the scene and score gradually")
	advance_for(0.40)
	check(not game._collection_blocking() and game._collection_audio_gain()==1.0,"The scene becomes playable after the collection closes gently")
	game.muted = true
	game.best_chapters.assign([3,3,3,3,3])
	game._layout()
	for index in range(5):
		game._request_transition("collection",index)
		game._request_transition("collection",(index+1)%5)
		check(game.transition_chapter==index,"Repeated selection cannot queue or replace an in-flight collection transition")
		advance_for(1.43)
		check(game.transition_phase==0 and game.garden_night==index and game.night_music.night==index and game.night_music.pieces==game.HARMONY.NIGHTS[index]["layers"].size(),"Every collected night restores its own full score")
		check(game.journey_resume==collection_journey and game.best_casts==collection_records,"Night switching preserves all journey and best records")
	game.reduced_motion = true
	game._request_transition("collection",-1)
	advance_for(0.50)
	check(game.transition_phase==0 and game.garden_night==-1 and game._harmony_index()==0 and game._instrument_index()==5,"Reduced motion returns to the standard garden with a short opacity transition")
	check(game.night_music.leaving,"Returning to the standard garden retires the collected score")
	game._set_garden_night(4)
	game.listening_resume = {}
	game.journey_resume = {"chapter":1,"progress":0,"casts":0,"perfects":0,"introSeen":true}
	game._return_to_journey()
	check(not game.free_play and game.chapter==1 and game._harmony_index()==1 and game.night_music.pieces==0,"An active journey uses its own harmony instead of the garden's selected collection")
	game._enter_garden()
	check(game.free_play and game.garden_night==4 and game.night_music.night==4,"A detour back to the garden remembers its chosen collection")
	game.listening_resume = {"chapter":2,"casts":2,"perfects":2}
	game._return_to_journey()
	var listening_casts: int = game.casts
	game._begin_pull(game._point(0.0))
	check(game.dragging and game.casts==listening_casts,"A restored completed moon accepts a new expressive pull")
	game._set_pull_angle(0.9)
	game._release()
	check(game.swinging and game.cast_judged and game.casts==listening_casts and game.chapter_done,"A completed-night release plays motion without adding a scored stroke")
	game._enter_garden(false)
	game.show_collection = true
	var held_collection_night: int = game.garden_night
	game._pause_for_focus_loss()
	check(game.paused and not game.show_collection and game.garden_night==held_collection_night,"Focus loss closes the collection before presenting the ordinary resume control")
	for offset in [-24.0,-12.0,0.0,12.0,24.0,48.0]:
		var ridges_valid := true
		for row in range(3):
			var ridge: PackedVector2Array = game._horizon_polygon(game.size.y+offset,row,218.0)
			ridges_valid = ridges_valid and not Geometry2D.triangulate_polygon(ridge).is_empty()
		check(ridges_valid,"Ground ridges remain drawable when a collected sky's horizon crosses the viewport bottom")
	# Only a newly completed constellation starts the bounded sky celebration.
	game.paused = false
	game.show_help = false
	game.muted = true
	for night in range(5):
		game.reduced_motion = false
		game._new_chapter(night)
		game._award_goal(0.0,game._point(0.0),0)
		check(not game._completion_visual_state()["active"],"An ordinary successful star does not celebrate the whole constellation")
		for goal in range(1,game.lit_goals.size()):game._award_goal(0.0,game._point(0.0),goal)
		check(game._completion_visual_state()["phase"]=="trace" and game.finish_time==0.0,"The final actual award starts the sky trace once")
		var phases: Array = []
		var bounded := true
		var previous_trace := 0.0
		for at in [0.0,1.0,2.4,3.0,4.2,5.3]:
			game.finish_time = at
			var visual: Dictionary = game._completion_visual_state()
			phases.append(visual["phase"])
			bounded = bounded and float(visual["trace"])>=previous_trace and float(visual["shimmer"])>=0.0 and float(visual["shimmer"])<=1.0 and float(visual["afterglow"])>=0.0 and float(visual["afterglow"])<=1.0
			previous_trace = float(visual["trace"])
		check(bounded and phases==["trace","trace","shimmer","shimmer","afterglow","settled"],"Every night traces, shimmers once and settles without a looping flash")
		game.reduced_motion = true
		game.finish_time = 0.9
		var gentle: Dictionary = game._completion_visual_state()
		game.finish_time = 3.5
		check(gentle["phase"]=="shimmer" and gentle["currentEdge"]==-1 and gentle["trace"]==1.0 and game._completion_visual_state()["phase"]=="settled","Reduced motion signals completion with a static whole-figure shimmer, then settles")
		game._enter_garden(false)
		game.listening_resume = {"chapter":night,"casts":2,"perfects":1}
		game._return_to_journey()
		check(game._completion_visual_state()["phase"]=="settled" and not game._completion_visual_state()["active"],"Completed-score restore cannot replay the celebration")
		game._begin_pull(game._point(0.0))
		check(game._completion_visual_state()["phase"]=="settled","Playing a restored completed night cannot restart a completion effect")
	game.reduced_motion = false
	game.finish_time = 0.6
	var held_celebration: Dictionary = game._completion_visual_state()
	game.paused = true
	game._process(0.5)
	check(game._completion_visual_state()==held_celebration,"Pause retains the current completion trace")
	game.paused = false
	game.show_help = true
	game._process(0.5)
	check(game._completion_visual_state()==held_celebration,"Help retains the current completion trace")
	game.show_help = false
	# Finished nights keep their score and records while the same moon remains playable.
	for night in range(5):
		game._new_chapter(night)
		game.casts = 2
		for goal in range(game.lit_goals.size()):game._award_goal(0.0,game._point(0.0),goal)
		var finished_progress: int = game.progress
		var finished_perfects: int = game.perfects
		var finished_best: Array = game.best_casts.duplicate()
		game.finish_time = 7.0
		for angle in [-1.1,0.9,1.2,-0.5]:
			game._begin_pull(game._point(0.0))
			game._set_pull_angle(angle)
			game._release()
			var release_time: float = game.finish_time
			for tick in range(210):
				game._process(1.0/60.0)
				game._physics_process(1.0/60.0)
			check(game.casts==2 and game.progress==finished_progress and game.perfects==finished_perfects and game.best_casts==finished_best,"Completed-night improvisation retains the achievement, tally and best result")
			check(game.cast_judged and game.night_music.completed and game.night_music.completion_starts==1 and game.finish_time>release_time and not game._completion_visual_state()["active"],"Completed-night improvisation cannot refire the award or celebration")
			check(game.players.size()==12 and game.night_music.players.size()==16 and game.trail.size()<=115 and game.particles.size()<180 and game.echo_transfers.size()<=4,"Repeated finished-night pulls retain bounded audio and visual resources")
		var reset_finished := InputEventKey.new()
		reset_finished.pressed = true
		reset_finished.keycode = KEY_R
		game._input(reset_finished)
		check(game.chapter_done and game.progress==finished_progress and game.casts==2 and game.transition_phase==0 and game.theta==0.0,"R returns the completed moon without restarting its night")
		reset_finished.keycode = KEY_RIGHT
		game._input(reset_finished)
		game._advance_keyboard_aim(0.8,1.0)
		check(game.dragging and game.keyboard_aim and game.theta>0.6,"The completed moon also accepts keyboard expression")
		reset_finished.keycode = KEY_SPACE
		game._input(reset_finished)
		check(game.swinging and game.casts==2 and game.cast_judged,"Keyboard release remains unscored in a completed night")
	game._enter_garden(false)
	game.reduced_motion = true
	game._open_collection()
	game._process(0.11)
	check(is_equal_approx(game._collection_alpha(),0.5),"Reduced motion keeps a short gentle collection dissolve")
	game._close_collection()
	game._process(0.22)
	check(not game._collection_blocking(),"Reduced-motion closing releases gestures after its short dissolve")
	# Hidden introduction controls cannot react, and their gradual return survives interruptions.
	var hud_tap := InputEventMouseButton.new()
	hud_tap.button_index = MOUSE_BUTTON_LEFT
	hud_tap.pressed = true
	var hud_key := InputEventKey.new()
	hud_key.pressed = true
	for gentle in [false,true]:
		game.reduced_motion = gentle
		for night in range(5):
			game.transition_phase = 0
			game.paused = false
			game.show_help = false
			game._new_chapter(5)
			game._request_transition("chapter",night)
			advance_for(game.TRANSITION_OUT+game.TRANSITION_QUIET+0.02)
			check(game.night_opening and game._hud_alpha()==0.0,"Every new night keeps its title and controls absent while the sky is introduced")
			var before_muted: bool = game.muted
			var before_time: float = game.night_opening_time
			for area in [game.mute_rect,game.help_rect,game.pause_rect,game.reset_rect,game.retry_rect]:
				hud_tap.position = area.get_center()
				game._input(hud_tap)
				game._input(hud_tap)
			check(game.muted==before_muted and not game.paused and not game.show_help and game.transition_action=="chapter" and game.night_opening_time==before_time,"Repeated taps on absent controls cannot toggle sound, interrupt or navigate")
			hud_key.keycode = KEY_P
			game._input(hud_key)
			advance_for(0.4)
			check(game.paused and game._hud_alpha()==0.0 and game.night_opening_time==before_time,"Keyboard pause preserves the hidden sky and its reveal time")
			hud_tap.position = game.resume_rect.get_center()
			game._input(hud_tap)
			check(not game.paused,"The visible resume overlay remains usable while ordinary controls are hidden")
			hud_key.keycode = KEY_H
			game._input(hud_key)
			advance_for(0.4)
			check(game.show_help and game.night_opening_time==before_time,"Help preserves the introduction without consuming its fade")
			hud_tap.position = game.help_rect.get_center()
			game._input(hud_tap)
			var reveal_seconds: float = game.NIGHT_DISSOLVE if gentle else game.NIGHT_PAN
			advance_for(game.NIGHT_VIEW-game.night_opening_time+reveal_seconds*0.5)
			var middle_alpha: float = game._hud_alpha()
			check(not game.show_help and middle_alpha>0.0 and middle_alpha<1.0,"Title and controls return gradually with the instrument in both motion settings")
			hud_tap.position = game.mute_rect.get_center()
			game._input(hud_tap)
			check(game.muted==before_muted and not game.dragging and game.casts==0,"Partly revealed controls stay locked until the instrument is ready")
			hud_key.keycode = KEY_P
			game._input(hud_key)
			advance_for(0.3)
			check(game._hud_alpha()==middle_alpha,"Pause also retains a partly revealed header without an opacity jump")
			hud_tap.position = game.pause_rect.get_center()
			game._input(hud_tap)
			if not gentle and night==2:
				game._pause_for_focus_loss()
				advance_for(0.3)
				check(game.paused and game._hud_alpha()==middle_alpha,"Leaving the app retains the partly revealed title until explicit resume")
				hud_tap.position = game.resume_rect.get_center()
				game._input(hud_tap)
				check(not game.paused,"Returning from focus loss can resume while ordinary introduction controls are locked")
			if gentle:
				check(game._footer_alpha()==middle_alpha,"Reduced motion keeps the footer in the same short dissolve as the header")
				advance_for(reveal_seconds*0.5+0.02)
			else:
				check(game._footer_alpha()==0.0,"Lower controls stay absent while the instrument is still crossing their area")
				advance_for(reveal_seconds*0.3)
				check(game._footer_alpha()>0.0 and game._footer_alpha()<1.0,"Lower controls fade in after the instrument clears their area")
				advance_for(reveal_seconds*0.2+0.02)
			check(not game.night_opening and game.transition_phase==0 and game._hud_alpha()==1.0,"Every reveal finishes with fully visible, available controls")
			hud_tap.position = game.mute_rect.get_center()
			game._input(hud_tap)
			check(game.muted!=before_muted,"Visible controls accept input again after the introduction")
			game._input(hud_tap)
	game.reduced_motion = false
	game._new_chapter(5)
	game._request_transition("chapter",1)
	advance_for(game.TRANSITION_OUT+game.TRANSITION_QUIET+0.3)
	hud_key.keycode = KEY_H
	game._input(hud_key)
	hud_tap.position = game.help_repeat_rect.get_center()
	game._input(hud_tap)
	advance_for(game.TRANSITION_OUT+game.TRANSITION_QUIET+game.TRANSITION_IN+0.02)
	check(not game.show_help and not game.paused and not game.night_opening and game._hud_alpha()==1.0 and game.chapter==1,"Explicit retry during an interrupted introduction restores an ordinary visible header")
	game._request_transition("garden")
	advance_for(game.TRANSITION_OUT-0.001)
	var covered_muted: bool = game.muted
	hud_tap.position = game.mute_rect.get_center()
	game._input(hud_tap)
	check(game.muted==covered_muted,"A control concealed by the night-switch curtain cannot respond to a stray tap")
	advance_for(game.TRANSITION_QUIET+game.TRANSITION_IN+0.03)
	check(game.free_play and game.transition_phase==0 and game._hud_alpha()==1.0,"The garden returns with visible controls after a covered transition")
	for night in range(5):
		game._new_chapter(night)
		for goal in range(game.lit_goals.size()):game._award_goal(0.0,game._point(0.0),goal)
		check(game._completion_actions_alpha()==0.0,"Completion does not instantly replace the footer with navigation")
		hud_tap.position = (game.retry_rect if game.retry_rect.size.x>0.0 else game.next_rect).get_center()
		game._input(hud_tap)
		check(game.transition_phase==0 and game.chapter_done,"An invisible completion action cannot navigate before its fade")
		advance_for(0.36)
		check(game._completion_actions_alpha()>0.0 and game._completion_actions_alpha()<1.0,"Completion actions become visible through a gradual fade")
		game._input(hud_tap)
		check(game.transition_phase==0,"A partly revealed completion action still rejects accidental taps")
		advance_for(0.25)
		check(game._completion_actions_alpha()==1.0,"Completion navigation becomes fully visible before accepting a tap")
		game._input(hud_tap)
		check(game.transition_phase==1 and game.transition_action=="garden","Fully visible completion navigation remains usable in all five nights")
		advance_for(game.TRANSITION_OUT+game.TRANSITION_QUIET+game.TRANSITION_IN+0.02)
	print("PASS: %d gameplay checks, all 11 constellation goals / 15 lights across 5 nights" % checks)
	game.paused = true
	game._stop_audio(true)
	await create_timer(0.12).timeout
	await process_frame
	game.queue_free()
	await process_frame
	# Let AudioServer release the last stopped playback before engine shutdown.
	await create_timer(0.12).timeout
	quit(0)
