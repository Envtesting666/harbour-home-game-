class_name CityFeedbackAudio
extends Node
## Recorded CC0 contract foley and compact interface sounds.
## Provenance and edits: assets/audio/LICENSES.md.

const PEN_FOLEY := preload("res://assets/audio/signature_pen.wav")
const FINISH_FOLEY := preload("res://assets/audio/signature_finish.wav")
const SIGNATURE_DEMO := preload("res://assets/audio/signature_demo.wav")
const PAPER_FOLEY := preload("res://assets/audio/contract_paper.wav")

var player: AudioStreamPlayer
var sounds: Dictionary = {}
var enabled := true:
	set(value):
		enabled = value
		if not enabled:
			stop_pen()
			for channel: AudioStreamPlayer in channels: channel.stop()
var effect_level := 0.8
var channels: Array[AudioStreamPlayer] = []
var pen: AudioStreamPlayer

func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.volume_db = -18
	add_child(player)
	channels.append(player)
	for i in range(2):
		var channel := AudioStreamPlayer.new()
		channel.volume_db = -18
		add_child(channel)
		channels.append(channel)
	sounds["collect"] = _tone([523.25, 659.25, 783.99], 0.07)
	sounds["confirm"] = _tone([392.0, 523.25], 0.055)
	var pen_sound := PEN_FOLEY.duplicate() as AudioStreamWAV
	pen_sound.loop_mode = AudioStreamWAV.LOOP_FORWARD
	pen_sound.loop_begin = 0
	pen_sound.loop_end = int(pen_sound.get_length() * pen_sound.mix_rate)
	pen = AudioStreamPlayer.new()
	pen.stream = pen_sound
	add_child(pen)
	sounds["seal"] = FINISH_FOLEY
	sounds["paper"] = PAPER_FOLEY
	# A listenable demonstration; gameplay layers pen and completion independently.
	sounds["signature"] = SIGNATURE_DEMO
	set_level(effect_level)

func play_collect() -> void:
	_play("collect")

func play_confirm() -> void:
	_play("confirm")

func play_signature() -> void:
	stop_pen()
	_play("seal")

func begin_pen() -> void:
	if enabled and is_instance_valid(pen) and not pen.playing: pen.play()

func stop_pen() -> void:
	if is_instance_valid(pen): pen.stop()

func play_paper() -> void:
	_play("paper")

func set_level(value: float) -> void:
	effect_level = clampf(value, 0, 1)
	enabled = effect_level > 0
	for channel: AudioStreamPlayer in channels:
		channel.volume_db = -14 + linear_to_db(maxf(effect_level, 0.001))
	if is_instance_valid(pen): pen.volume_db = -10 + linear_to_db(maxf(effect_level, .001))

func _play(key: String) -> void:
	if not enabled or player == null or not sounds.has(key): return
	var target := channels[0]
	for channel: AudioStreamPlayer in channels:
		if not channel.playing:
			target = channel
			break
	target.stream = sounds[key]
	target.play()

func _tone(notes: Array, seconds: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var note_samples := int(seconds * sample_rate)
	var data := PackedByteArray()
	data.resize(note_samples * notes.size() * 2)
	for n in range(notes.size()):
		for sample in range(note_samples):
			var time := float(sample) / sample_rate
			var envelope := sin(PI * float(sample) / note_samples) * exp(-time * 12)
			var value := int(sin(TAU * float(notes[n]) * time) * envelope * 17000)
			data.encode_s16((n * note_samples + sample) * 2, value)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream
