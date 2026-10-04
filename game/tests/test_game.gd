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
	game.muted = true
	game._start()
	check(game.started, "Start gesture enters play")
	game._begin_pull(game.pivot + Vector2(-500.0, 10.0))
	check(absf(game.theta) <= game.MAX_PULL, "Drag cannot exceed physical angle limit")
	game._retry()
	check(game.theta == 0.0 and not game.swinging, "Retry restores stationary moon")
	for chapter_index in range(3):
		game._new_chapter(chapter_index)
		var targets: Array = game.CHAPTERS[chapter_index]["targets"]
		for target in targets:
			var before: int = game.progress
			game.dragging = true
			game.theta = -float(target) * 1.055
			game._release()
			for tick in range(200):
				game._physics_process(1.0 / 60.0)
			check(game.progress == before + 1, "Correct opposite-side pull reaches target")
			check(game.cast_judged, "One judgment per cast")
			for tick in range(250):
				game._physics_process(1.0 / 60.0)
			check(game.progress == before + 1, "Repeated turns do not collect extra targets")
		check(game.chapter_done, "Each chapter can be completed")
		check(game.casts == targets.size(), "All goals are achievable without hidden extra casts")
	game._new_chapter(0)
	game.dragging = true
	game.theta = 0.6
	game._release()
	for tick in range(200):
		game._physics_process(1.0 / 60.0)
	check(game.progress == 0, "Wrong-side launch does not earn a target")
	check(game.feedback.contains("反対側"), "Wrong-side launch gives helpful feedback")
	game._retry()
	game.dragging = true
	game.theta = -0.18
	game._release()
	for tick in range(200):
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
	game._new_chapter(0)
	check(game.progress == 0 and game.casts == 0 and not game.chapter_done, "Chapter restart clears its results")
	print("PASS: %d gameplay checks, all 12 targets across 3 chapters" % checks)
	game.queue_free()
	quit(0)
