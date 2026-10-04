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
		for angle in solutions[chapter_index]:
			var before: int = game.progress
			game.dragging = true
			game.theta = angle
			game._release()
			for tick in range(300):
				game._process(1.0/60.0)
				game._physics_process(1.0/60.0)
			check(game.progress==before+1,"Every optional journey light is reachable")
			for tick in range(240):
				game._process(1.0/60.0)
				game._physics_process(1.0/60.0)
			check(game.progress==before+1,"One cast cannot consume a following light")
		check(game.chapter_done,"Every optional night can complete")
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
	check(not game.free_play and game.tempo_index == 1, "Return to chapters restores standard physics")
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
	var missing_glyphs: Array[String] = []
	var source_text := FileAccess.get_file_as_string("res://scripts/main.gd")
	for ch in source_text:
		if ch.unicode_at(0) > 127 and not game.FONT.has_char(ch.unicode_at(0)) and ch not in missing_glyphs:
			missing_glyphs.append(ch)
	check(missing_glyphs.is_empty(), "All game UI glyphs are bundled: " + str(missing_glyphs))
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
	root.size = original_size
	print("PASS: %d gameplay checks, all 11 optional exercises / 15 lights across 5 nights" % checks)
	game.queue_free()
	quit(0)
