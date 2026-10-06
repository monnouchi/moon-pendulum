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
	game.journey_resume = {}
	game.garden_scene = {}
	game.muted = true
	game._start()
	check(game.started, "Start gesture enters play")
	game._begin_pull(game.pivot + Vector2(-500.0, 10.0))
	check(absf(game.theta) <= game.MAX_PULL, "Drag cannot exceed physical angle limit")
	game._retry()
	check(game.theta == 0.0 and not game.swinging, "Retry restores stationary moon")
	var solutions := [[-0.58,0.85,1.0],[-0.98,-1.12],[0.98,-1.05],[-1.13,1.20],[-1.12,-1.20]]
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
			check(game.progress==before+1,"One cast cannot consume a following light")
		check(game.chapter_done,"Every optional night can complete")
		check(game.night_music.completed and game.night_music.completion_starts==1,"Every night reaches its full score once")
	# Each duet must accept the same gesture from either side. Keep the
	# smaller gestures unsuccessful so the pair still requires both echoes.
	for duet_case in [{"chapter":1,"angles":[0.98,1.12]},{"chapter":4,"angles":[1.12,1.20]}]:
		for target_index in range(2):
			for direction in [-1.0,1.0]:
				game._new_chapter(duet_case["chapter"])
				game.progress = target_index
				game.dragging = true
				game.theta = direction * duet_case["angles"][target_index]
				game._release()
				check(not game.cast_judged,"Either duet release direction remains eligible")
				for tick in range(300):
					game._process(1.0/60.0)
					game._physics_process(1.0/60.0)
				check(game.progress==target_index+1,"Every duet target is reachable from either side")
				check(game.duet_checked[0] and game.duet_checked[1] and game.duet_errors.max()<=0.095,"Both duet turns meet the unchanged hit tolerance")
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
	check(game.cast_judged and game.feedback.contains("側から"), "Relay teaches its different release direction")
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
	check(game.progress == 0, "Wrong-side launch does not earn a target")
	check(game.feedback.contains("反対側"), "Wrong-side launch gives helpful feedback")
	game._retry()
	game.dragging = true
	game.theta = -0.18
	game._release()
	for tick in range(200):
		game._process(1.0 / 60.0)
		game._physics_process(1.0 / 60.0)
	check(game.feedback.contains("大きく"), "Short pull gives an actionable hint")
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
	game._start_art()
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
	game.chapter_done = true
	game._enter_garden()
	game._return_to_journey()
	check(game.chapter==3 and game.progress==0,"Garden detour returns after completed third night, not to first")
	game._new_chapter(0)
	game.progress = 1
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
	check(game.cast_judged and game.feedback.contains("外側"),"Weak relay has an actionable outer-bell hint")
	game._new_chapter(1)
	game.dragging = true
	game.theta = -0.68
	game._release()
	for tick in range(240):
		game._process(1.0/60.0)
		game._physics_process(1.0/60.0)
	check(game.cast_judged and game.feedback.contains("外側"),"Partial duet cannot wait forever for an unreachable second bell")
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
	check(game.turn_advice[0]["word"]=="" and game.feedback_timer==0.0,"A first miss uses the turn mark without another text instruction")
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
	cast_until_judged(-0.8)
	cast_until_judged(-0.8)
	check(game.turn_advice[0]["word"]=="少しやさしく","An overshoot asks for a gentler pull")
	game._new_chapter(0)
	cast_until_judged(0.6)
	cast_until_judged(0.6)
	check(game.turn_advice[0]["word"]=="反対側から","Wrong-side fold-backs receive the relevant short word")
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
	check(game.turn_advice.size()==1 and game.turn_advice[0]["side"]==0 and game.turn_advice[0]["word"]=="もう少し大きく","Relay advice follows its measured secondary moon")
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
	game._process(game.TRANSITION_IN)
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
	advance_for(game.TRANSITION_OUT+game.TRANSITION_QUIET+game.TRANSITION_IN+0.02)
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
	advance_for(game.TRANSITION_OUT+game.TRANSITION_QUIET+game.TRANSITION_IN+0.02)
	check(game.chapter==0 and game.transition_phase==0,"The replacement destination completes exactly once")
	game._request_transition("chapter",2)
	advance_for(game.TRANSITION_OUT+game.TRANSITION_QUIET+0.08)
	game._input(transition_help_key)
	transition_help_click.position = game.help_restart_rect.get_center()
	game._input(transition_help_click)
	check(game.transition_phase==1 and game.transition_time>0.0,"Restart during fade-in reverses at the existing opacity")
	advance_for(game.TRANSITION_OUT+game.TRANSITION_QUIET+game.TRANSITION_IN+0.02)
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
	advance_for(game.TRANSITION_IN)
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
		advance_for(game.TRANSITION_OUT+game.TRANSITION_QUIET+game.TRANSITION_IN)
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
	advance_for(game.TRANSITION_OUT+game.TRANSITION_QUIET+game.TRANSITION_IN)
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
	advance_for(game.TRANSITION_OUT+game.TRANSITION_QUIET+game.TRANSITION_IN)
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
	advance_for(game.TRANSITION_OUT+game.TRANSITION_QUIET+game.TRANSITION_IN)
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
	advance_for(game.TRANSITION_OUT+game.TRANSITION_QUIET+game.TRANSITION_IN+0.02)
	game._process(0.02)
	check(game.chapter==2 and game.night_music.night==2 and game.night_music.pieces==0 and not game.night_music.completed,"Each next night returns to its own lonely foundation")
	var cycle_best: Array = game.best_chapters.duplicate()
	var cycle_palette: int = game.palette_index
	var cycle_gravity: int = game.saved_gravity_index
	game.journey_resume = {"chapter":0,"progress":0,"casts":0,"perfects":0}
	game.listening_resume = {"chapter":4,"casts":2,"perfects":2}
	game._return_to_journey()
	check(game.chapter==4 and game.chapter_done and game.progress==2 and game.night_music.pieces==4,"Direct restoration retains the completed final night for listening")
	check(game._journey_entry_label(true)=="音のつづき","The direct completed-score entrance describes listening instead of a playable stage")
	game._request_transition("garden")
	check(game.listening_resume.is_empty() and game.transition_resume["chapter"]==0,"Explicit final exit clears listening before a refresh can interrupt the curtain")
	advance_for(game.TRANSITION_OUT+game.TRANSITION_QUIET+game.TRANSITION_IN+0.02)
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
	game._start_art()
	check(game.free_play and game.listening_resume.is_empty() and game._journey_entry_label()=="もう一度","Choosing the garden also retires an ambiguous legacy final-listening save")
	game._return_to_journey()
	check(game.chapter==0 and not game.chapter_done,"A legacy garden save cannot trap replay on the completed final screen")
	legacy_final.erase("listening")
	legacy_final_config = game._config_from_checkpoint(legacy_final)
	game.journey_resume = legacy_final_config.get_value("journey","resume")
	game.listening_resume = legacy_final_config.get_value("music","listening")
	check(game._journey_entry_label(true)=="もう一度","Completed saves from before music still offer a first-night replay")
	game.listening_resume = {"chapter":1,"casts":2,"perfects":2}
	game._return_to_journey()
	game._enter_garden()
	game._return_to_journey()
	check(game.chapter==1 and game.chapter_done and game.night_music.pieces==4,"The final-cycle fix preserves listening detours for earlier completed nights")
	game.listening_resume = {}
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
		check(visible.encloses(game.start_rect) and visible.encloses(game.tour_rect),"Minimal introduction controls fit the viewport")
		check(game.start_rect.position.y>=game.pivot.y+game.length+57.0,"Hero moon has clear space above the start action")
		check(game.start_rect.size.y*scale>=44.0,"Portrait start action remains a full touch target")
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
	print("PASS: %d gameplay checks, all 11 optional exercises / 15 lights across 5 nights" % checks)
	game.paused = true
	game._stop_audio(true)
	await create_timer(0.12).timeout
	await process_frame
	game.queue_free()
	await process_frame
	# Let AudioServer release the last stopped playback before engine shutdown.
	await create_timer(0.12).timeout
	quit(0)
