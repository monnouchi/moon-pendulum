extends Node
## Five original scores. Star phrases persist; physical bell voices stay separate.
const VOICES = 16
const BASS_LOOP_BEGIN = 30000
const BASS_LOOP_END = 90000
const SCORES = [
	{"bpm":58.0,"steps":16,"bass":38,"base":[[0,50,0.68],[8,57,0.52],[12,62,0.40]],"layers":[[[4,74,0.72],[12,76,0.60]],[[2,78,0.64],[8,81,0.62],[14,78,0.55]],[[0,86,0.60],[6,83,0.56],[10,81,0.58],[15,83,0.46]]]},
	{"bpm":66.0,"steps":12,"bass":45,"base":[[0,50,0.64],[6,57,0.56]],"layers":[[[0,74,0.65],[6,78,0.58]],[[3,81,0.62],[9,76,0.54]],[[2,83,0.58],[8,81,0.54]],[[5,86,0.56],[11,83,0.50]]]},
	{"bpm":54.0,"steps":18,"bass":47,"base":[[0,50,0.60],[12,59,0.44]],"layers":[[[2,74,0.66],[8,71,0.54]],[[6,76,0.60],[14,78,0.54]]]},
	{"bpm":68.0,"steps":16,"bass":40,"base":[[0,50,0.62],[8,59,0.48]],"layers":[[[0,74,0.64],[6,78,0.60],[11,81,0.54]],[[3,76,0.60],[8,83,0.56],[14,86,0.50]]]},
	{"bpm":62.0,"steps":24,"bass":38,"base":[[0,50,0.66],[12,57,0.54]],"layers":[[[0,74,0.65],[6,78,0.58],[12,81,0.60],[18,74,0.54]],[[3,76,0.60],[9,83,0.56],[15,78,0.56],[21,81,0.50]],[[2,86,0.56],[8,83,0.52],[14,81,0.54],[20,83,0.50]],[[5,78,0.56],[11,81,0.54],[17,86,0.56],[23,86,0.46]]]}
]
var players: Array[AudioStreamPlayer] = []
var applied_db: Array[float] = []
var voices: Array[Dictionary] = []
var instruments: Array[Array] = []
var bass_stream: AudioStreamWAV
var night := -1
var pieces := 0
var completed := false
var time := 0.0
var last_step := -1
var generation := 0
var enabled := false
var leaving := false
var master_gain := 1.0
var duck_gain := 1.0
var duck_hold := 0.0
var completion_starts := 0
var bass_entries := 0
var replies := 0
var phrase_notes := 0
var reply_cast := -1
var reply_sides: Array[bool] = [false,false]

func _ready() -> void:
	set_process(false)
	for index in range(SCORES.size()):
		var bank: Array = []
		for kind in ["base","left","right"]:
			bank.append(load("res://assets/audio/music_%d_%s.wav" % [index,kind]))
		instruments.append(bank)
	bass_stream = load("res://assets/audio/music_bass.wav").duplicate()
	bass_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	bass_stream.loop_begin = BASS_LOOP_BEGIN
	bass_stream.loop_end = BASS_LOOP_END
	for index in range(VOICES):
		var player := AudioStreamPlayer.new()
		player.volume_db = -80.0
		add_child(player)
		players.append(player)
		applied_db.append(-80.0)
		voices.append({"generation":-1,"role":"","base":-30.0,"gain":0.0,"from":0.0,"to":0.0,"age":0.0,"duration":0.0,"after":"","tail":false})

func _active(player: AudioStreamPlayer) -> bool:
	# Godot considers a paused playback inactive, but it still owns its voice.
	return player.playing or player.stream_paused

func begin(index: int, restored_pieces: int = 0, restored_complete: bool = false) -> void:
	if not leaving:
		leave(0.32)
	generation += 1
	night = clampi(index,0,SCORES.size()-1)
	pieces = clampi(restored_pieces,0,SCORES[night]["layers"].size())
	completed = restored_complete
	time = 0.0
	last_step = -1
	leaving = false
	enabled = false
	completion_starts = 0
	bass_entries = 0
	replies = 0
	phrase_notes = 0
	reply_cast = -1
	reply_sides = [false,false]

func leave(duration: float) -> void:
	leaving = true
	for index in range(players.size()):
		var voice: Dictionary = voices[index]
		if not _active(players[index]):
			continue
		if not voice["tail"] and int(voice["generation"])==generation:
			voice["gain"] = float(voice["gain"])*master_gain
		voice["tail"] = true
		_tween(index,0.0,duration,"stop")

func restore(count: int, finished: bool) -> void:
	pieces = clampi(count,0,SCORES[night]["layers"].size())
	completed = finished

func _exit_tree() -> void:
	for player in players:
		player.stream_paused = false
		player.stop()
		player.stream = null

func suspend(immediate: bool = false) -> void:
	enabled = false
	for index in range(players.size()):
		if not _active(players[index]):
			continue
		if immediate:
			players[index].stream_paused = true
			voices[index]["gain"] = 0.0
			voices[index]["duration"] = 0.0
			_apply_gain(index)
		else:
			_tween(index,0.0,0.08,"pause")

func unlock(count: int, finished: bool, paired: bool = false) -> void:
	if night<0 or leaving:
		return
	var previous := pieces
	pieces = clampi(maxi(pieces,count),0,SCORES[night]["layers"].size())
	if enabled and not paired:
		for layer in range(previous,pieces):
			var first: Array = SCORES[night]["layers"][layer][0]
			_note(layer,int(first[1]),float(first[2])*0.72,"reply")
	if finished and not completed:
		completed = true
		completion_starts += 1
		if enabled:
			_start_bass(true)

func reply(cast: int, side: int) -> void:
	if night<0 or leaving or completed:
		return
	if cast!=reply_cast:
		reply_cast = cast
		reply_sides = [false,false]
	if reply_sides[side]:
		return
	reply_sides[side] = true
	replies += 1
	if enabled:
		_note(side,[83,86][side] if night==4 else [78,81][side],0.65,"reply")

func clear_replies() -> void:
	for index in range(players.size()):
		if _active(players[index]) and voices[index]["role"]=="reply" and int(voices[index]["generation"])==generation:
			_tween(index,0.0,0.12,"stop")

func duck() -> void:
	duck_gain = minf(duck_gain,0.72)
	duck_hold = 0.14

func advance(delta: float, allowed: bool, transition_gain: float) -> void:
	master_gain = transition_gain
	duck_hold = maxf(0.0,duck_hold-delta)
	if duck_hold<=0.0:
		duck_gain = move_toward(duck_gain,1.0,delta*0.65)
	_advance_voices(delta)
	if not allowed:
		if enabled and not leaving:
			suspend()
		return
	if night<0 or leaving:
		return
	if not enabled:
		enabled = true
		for index in range(players.size()):
			if _active(players[index]) and int(voices[index]["generation"])==generation and not voices[index]["tail"]:
				players[index].stream_paused = false
				_tween(index,1.0,0.18)
		if completed:
			_start_bass(false)
	# Never accumulate a burst of overdue notes after a stalled browser frame.
	time += minf(delta,0.10)
	var step := int(floor(time*SCORES[night]["bpm"]/30.0))
	for at in range(last_step+1,step+1):
		var position := at % int(SCORES[night]["steps"])
		for event in SCORES[night]["base"]:
			if int(event[0])==position:
				_play(instruments[night][0],int(event[1]),50,float(event[2]),-20.0,"base")
		for layer in range(pieces):
			for event in SCORES[night]["layers"][layer]:
				if int(event[0])==position:
					_note(layer,int(event[1]),float(event[2]),"phrase")
	last_step = step

func _note(layer: int, midi: int, strength: float, role: String) -> void:
	_play(instruments[night][1+layer%2],midi,74,strength,-17.0,role)

func _start_bass(entry: bool) -> void:
	for index in range(players.size()):
		if _active(players[index]) and int(voices[index]["generation"])==generation and voices[index]["role"]=="bass":
			return
	if entry:
		bass_entries += 1
	var offset := 0.0 if entry else float(BASS_LOOP_BEGIN)/float(bass_stream.mix_rate)
	var slot := _play(bass_stream,int(SCORES[night]["bass"]),38,0.80,-10.0,"bass",offset,1.0 if entry else 0.0)
	if not entry:
		_tween(slot,1.0,0.45)

func _play(stream: AudioStreamWAV, midi: int, reference: int, strength: float, db: float, role: String, offset: float = 0.0, initial_gain: float = 1.0) -> int:
	if role=="phrase":
		phrase_notes += 1
	var slot := -1
	for index in range(players.size()):
		if not _active(players[index]) or (players[index].stream_paused and int(voices[index]["generation"])!=generation):
			slot = index
			break
	if slot<0:
		var quietest := INF
		for index in range(players.size()):
			if voices[index]["role"]=="bass":
				continue
			var gain := float(voices[index]["gain"])*db_to_linear(float(voices[index]["base"]))
			if gain<quietest:
				quietest = gain
				slot = index
	var player := players[slot]
	player.stream_paused = false
	player.stop()
	player.stream = stream
	player.pitch_scale = pow(2.0,float(midi-reference)/12.0)
	voices[slot] = {"generation":generation,"role":role,"base":db+linear_to_db(strength),"gain":initial_gain,"from":initial_gain,"to":initial_gain,"age":0.0,"duration":0.0,"after":"","tail":false}
	_apply_gain(slot)
	player.play(offset)
	return slot

func _tween(index: int, target: float, duration: float, after: String = "") -> void:
	var voice: Dictionary = voices[index]
	voice["from"] = voice["gain"]
	voice["to"] = target
	voice["age"] = 0.0
	voice["duration"] = maxf(0.001,duration)
	voice["after"] = after

func _apply_gain(index: int) -> void:
	var voice: Dictionary = voices[index]
	var curtain := master_gain if int(voice["generation"])==generation and not voice["tail"] else 1.0
	var db := float(voice["base"])+linear_to_db(maxf(0.000001,float(voice["gain"])*curtain*duck_gain))
	# Preserve each envelope without resending an unchanged audio gain.
	if db!=applied_db[index]:
		players[index].volume_db = db
		applied_db[index] = db

func _advance_voices(delta: float) -> void:
	for index in range(players.size()):
		var voice: Dictionary = voices[index]
		if float(voice["duration"])<=0.0 and not players[index].has_stream_playback():
			continue
		if float(voice["duration"])>0.0:
			voice["age"] += delta
			var t := clampf(float(voice["age"])/float(voice["duration"]),0.0,1.0)
			voice["gain"] = lerpf(float(voice["from"]),float(voice["to"]),t*t*(3.0-2.0*t))
			if t>=1.0:
				voice["duration"] = 0.0
				if voice["after"]=="pause":players[index].stream_paused = true
				elif voice["after"]=="stop":
					players[index].stream_paused = false
					players[index].stop()
		_apply_gain(index)

func snapshot() -> Dictionary:
	var audible := 0
	for index in range(players.size()):
		var voice: Dictionary = voices[index]
		var curtain := master_gain if int(voice["generation"])==generation and not voice["tail"] else 1.0
		if _active(players[index]) and not players[index].stream_paused and float(voice["gain"])*curtain*duck_gain>0.00001:
			audible += 1
	return {"night":night,"pieces":pieces,"complete":completed,"time":time,"enabled":enabled and not leaving,"audibleVoices":audible,"completionStarts":completion_starts,"bassEntries":bass_entries,"replies":replies,"phraseNotes":phrase_notes}
