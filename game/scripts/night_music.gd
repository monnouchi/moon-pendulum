extends Node
## Five original scores. Star phrases persist; physical bell voices stay separate.
const VOICES = 16
const BASS_LOOP_BEGIN = 30000
const BASS_LOOP_END = 90000
const COMPLETION_BREATH_SECONDS = 1.8
const SCORES = preload("res://scripts/night_harmony.gd").NIGHTS
var players: Array[AudioStreamPlayer] = []
var applied_db: Array[float] = []
var voices: Array[Dictionary] = []
var instruments: Array[Array] = []
var bass_stream: AudioStreamWAV
var bass_streams: Array[AudioStreamWAV] = []
var night := -1
var pieces := 0
var active_layers: Array[bool] = []
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
var landing_notes := 0
var completion_breath := 0.0
var replies := 0
var phrase_notes := 0
var reply_cast := -1
var reply_sides: Array[bool] = [false,false]

func _ready() -> void:
	set_process(false)
	var bass_by_midi: Dictionary = {}
	for index in range(SCORES.size()):
		var bank: Array = []
		for kind in ["base","left","right"]:
			bank.append(load("res://assets/audio/music_%d_%s.wav" % [index,kind]))
		instruments.append(bank)
		var midi: int = int(SCORES[index]["bass"])
		if not bass_by_midi.has(midi):
			var path := "res://assets/audio/music_bass.wav" if midi==38 else "res://assets/audio/music_bass_%d.wav" % midi
			var stream: AudioStreamWAV = load(path).duplicate()
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = BASS_LOOP_BEGIN
			stream.loop_end = BASS_LOOP_END
			bass_by_midi[midi] = stream
		bass_streams.append(bass_by_midi[midi])
	bass_stream = bass_streams[0]
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
	bass_stream = bass_streams[night]
	_set_layers(restored_pieces)
	completed = restored_complete
	time = 0.0
	last_step = -1
	leaving = false
	enabled = false
	completion_starts = 0
	bass_entries = 0
	landing_notes = 0
	completion_breath = 0.0
	replies = 0
	phrase_notes = 0
	reply_cast = -1
	reply_sides = [false,false]

func leave(duration: float) -> void:
	leaving = true
	completion_breath = 0.0
	for index in range(players.size()):
		var voice: Dictionary = voices[index]
		if not _active(players[index]):
			continue
		if not voice["tail"] and int(voice["generation"])==generation:
			voice["gain"] = float(voice["gain"])*master_gain
		voice["tail"] = true
		var held: Dictionary = voice.get("held_tail",{})
		if not held.is_empty():
			# A restart may replace navigation while the curtain is paused.
			voice["held_tail"] = {"from":_envelope_gain(held),"to":0.0,"age":0.0,"duration":maxf(0.001,duration),"after":"stop"}
		else:
			_tween(index,0.0,duration,"stop")

func _set_layers(count: int, mask: Variant = null) -> void:
	active_layers.clear()
	for index in range(SCORES[night]["layers"].size()):
		active_layers.append(bool(mask[index]) if mask is Array else index<count)
	pieces = active_layers.count(true)

func restore(count: int, finished: bool, mask: Variant = null) -> void:
	_set_layers(count,mask)
	completed = finished
	completion_breath = 0.0

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
		var voice: Dictionary = voices[index]
		if voice["tail"] and voice["after"]=="stop" and float(voice["duration"])>0.0 and voice.get("held_tail",{}).is_empty():
			voice["held_tail"] = {"from":voice["from"],"to":voice["to"],"age":voice["age"],"duration":voice["duration"],"after":"stop"}
		# Mute from the audible level, including a possible return ramp.
		voice["gain"] = float(voice["gain"])*float(voice.get("return_gain",1.0))
		voice["return_gain"] = 1.0
		voice["return_duration"] = 0.0
		if immediate:
			players[index].stream_paused = true
			voices[index]["gain"] = 0.0
			voices[index]["duration"] = 0.0
			_apply_gain(index)
		else:
			_tween(index,0.0,0.08,"pause")

func unlock(count: int, finished: bool, paired: bool = false, mask: Variant = null) -> void:
	if night<0 or leaving:
		return
	var previous := active_layers.duplicate()
	_set_layers(maxi(pieces,count),mask)
	if enabled and not paired and not finished:
		for layer in range(active_layers.size()):
			if not active_layers[layer] or previous[layer]:continue
			var first: Array = SCORES[night]["layers"][layer][0]
			_note(layer,int(first[1]),float(first[2])*0.72,"reply")
	if finished and not completed:
		completed = true
		duck_hold = 0.0
		completion_starts += 1
		completion_breath = COMPLETION_BREATH_SECONDS
		if enabled:
			_start_bass(true)
			# One quiet tonic replaces the last high reply. Existing notes decay
			# naturally while new score attacks leave room for the arrival.
			_play(instruments[night][0],int(SCORES[night]["bells"][0]),50,0.50,-20.0,"landing")
			landing_notes += 1

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
		_note(side,int(SCORES[night]["replies"][side]),0.65,"reply")

func clear_replies() -> void:
	for index in range(players.size()):
		if _active(players[index]) and voices[index]["role"]=="reply" and int(voices[index]["generation"])==generation:
			_tween(index,0.0,0.12,"stop")

func retire_landing() -> void:
	# A muted one-shot must not return as a late reward on unmute.
	for index in range(players.size()):
		if _active(players[index]) and voices[index]["role"]=="landing" and int(voices[index]["generation"])==generation:
			voices[index]["tail"] = true
			_tween(index,0.0,0.08,"stop")

func duck() -> void:
	if completed:return
	duck_gain = minf(duck_gain,0.92)
	duck_hold = 0.08

func advance(delta: float, allowed: bool, transition_gain: float, interrupted: bool = false, freeze_tails: bool = false) -> void:
	master_gain = transition_gain
	var score_delta := delta
	if completion_breath>0.0 and not freeze_tails:
		score_delta = maxf(0.0,delta-completion_breath)
		completion_breath = maxf(0.0,completion_breath-delta)
	duck_hold = maxf(0.0,duck_hold-delta)
	if duck_hold<=0.0:
		duck_gain = move_toward(duck_gain,1.0,delta*0.65)
	if not interrupted:
		_resume_tails()
	_advance_voices(delta,freeze_tails)
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
				var pitch := players[index].pitch_scale
				players[index].stream_paused = false
				# Web Sample recreates its source on resume; restore the held note's rate.
				players[index].pitch_scale = pitch
				_tween(index,1.0,0.18)
		if completed:
			_start_bass(false)
	if score_delta<=0.0:return
	# Never accumulate a burst of overdue notes after a stalled browser frame.
	time += minf(score_delta,0.10)
	var step := int(floor(time*SCORES[night]["bpm"]/30.0))
	for at in range(last_step+1,step+1):
		var position := at % int(SCORES[night]["steps"])
		for event in SCORES[night]["base"]:
			if int(event[0])==position:
				_play(instruments[night][0],int(event[1]),50,float(event[2]),-20.0,"base")
		for layer in range(active_layers.size()):
			if not active_layers[layer]:continue
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
	# The baked tonic keeps continuous Stream playback at its original pitch.
	var midi: int = int(SCORES[night]["bass"])
	var slot := _play(bass_stream,midi,midi,0.80,-10.0,"bass",offset,1.0 if entry else 0.0)
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
	# Web Sample restarts the whole bass WAV on its ended callback, including
	# the entrance. Stream keeps its steady loop in the audio mixer instead.
	player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM if role=="bass" else AudioServer.PLAYBACK_TYPE_DEFAULT
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

func _envelope_gain(envelope: Dictionary) -> float:
	var t := clampf(float(envelope["age"])/float(envelope["duration"]),0.0,1.0)
	return lerpf(float(envelope["from"]),float(envelope["to"]),t*t*(3.0-2.0*t))

func _resume_tails() -> void:
	for index in range(players.size()):
		var voice: Dictionary = voices[index]
		var held: Dictionary = voice.get("held_tail",{})
		if held.is_empty() or not _active(players[index]):
			continue
		for key in ["from","to","age","duration","after"]:
			voice[key] = held[key]
		voice["gain"] = _envelope_gain(held)
		voice["held_tail"] = {}
		voice["return_gain"] = 0.0
		voice["return_age"] = 0.0
		voice["return_duration"] = minf(0.18,float(held["duration"])-float(held["age"]))
		var pitch := players[index].pitch_scale
		players[index].stream_paused = false
		# Web Sample replaces the paused source; restore its held pitch too.
		players[index].pitch_scale = pitch
		_apply_gain(index)

func _apply_gain(index: int) -> void:
	var voice: Dictionary = voices[index]
	var curtain := master_gain if int(voice["generation"])==generation and not voice["tail"] else 1.0
	var db := float(voice["base"])+linear_to_db(maxf(0.000001,float(voice["gain"])*float(voice.get("return_gain",1.0))*curtain*duck_gain))
	# Preserve each envelope without resending an unchanged audio gain.
	if db!=applied_db[index]:
		players[index].volume_db = db
		applied_db[index] = db

func _advance_voices(delta: float, freeze_tails: bool = false) -> void:
	for index in range(players.size()):
		var voice: Dictionary = voices[index]
		var held: Dictionary = voice.get("held_tail",{})
		if not held.is_empty() and not freeze_tails:
			held["age"] = float(held["age"])+delta
			if float(held["age"])>=float(held["duration"]):
				voice["held_tail"] = {}
				voice["gain"] = 0.0
				voice["duration"] = 0.0
				players[index].stream_paused = false
				players[index].stop()
		if float(voice.get("return_duration",0.0))>0.0:
			voice["return_age"] = float(voice["return_age"])+delta
			var t := clampf(float(voice["return_age"])/float(voice["return_duration"]),0.0,1.0)
			voice["return_gain"] = t*t*(3.0-2.0*t)
			if t>=1.0:voice["return_duration"] = 0.0
		if float(voice["duration"])<=0.0 and not players[index].has_stream_playback():
			continue
		if float(voice["duration"])>0.0:
			voice["age"] += delta
			var t := clampf(float(voice["age"])/float(voice["duration"]),0.0,1.0)
			voice["gain"] = _envelope_gain(voice)
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
		if _active(players[index]) and not players[index].stream_paused and float(voice["gain"])*float(voice.get("return_gain",1.0))*curtain*duck_gain>0.00001:
			audible += 1
	return {"night":night,"pieces":pieces,"layers":active_layers.duplicate(),"complete":completed,"time":time,"enabled":enabled and not leaving,"audibleVoices":audible,"completionStarts":completion_starts,"bassEntries":bass_entries,"landingNotes":landing_notes,"breathRemaining":completion_breath,"replies":replies,"phraseNotes":phrase_notes}
