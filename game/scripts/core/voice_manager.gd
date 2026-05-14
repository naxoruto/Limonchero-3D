extends Node

signal recording_started()
signal recording_stopped()
signal audio_captured(wav_bytes: PackedByteArray)
signal playback_started()
signal playback_finished()

const BUS_NAME := "Mic"
const TARGET_SAMPLE_RATE := 16000

var _capture_effect: AudioEffectCapture = null
var _stream_player: AudioStreamPlayer = null
var _playback_player: AudioStreamPlayer = null
var _is_recording := false
var _sample_rate := TARGET_SAMPLE_RATE
var _available := false
var _last_wav_bytes: PackedByteArray = PackedByteArray()


func _ready() -> void:
	_sample_rate = AudioServer.get_mix_rate()
	if _sample_rate != TARGET_SAMPLE_RATE:
		push_warning(
			"VoiceManager: mix rate %d Hz (ideal %d Hz)" % [_sample_rate, TARGET_SAMPLE_RATE]
		)
	if AudioServer.get_input_device_list().is_empty():
		push_warning("VoiceManager: no input devices detected")
	var bus_idx := AudioServer.get_bus_index(BUS_NAME)
	if bus_idx == -1:
		push_error("VoiceManager: audio bus '%s' not found" % BUS_NAME)
		return
	_capture_effect = AudioServer.get_bus_effect(bus_idx, 0) as AudioEffectCapture
	if _capture_effect == null:
		push_error("VoiceManager: AudioEffectCapture not found on bus '%s' slot 0" % BUS_NAME)
		return
	_stream_player = AudioStreamPlayer.new()
	_stream_player.stream = AudioStreamMicrophone.new()
	_stream_player.bus = BUS_NAME
	add_child(_stream_player)
	_playback_player = AudioStreamPlayer.new()
	_playback_player.bus = "Master"
	_playback_player.finished.connect(_on_playback_finished)
	add_child(_playback_player)
	_available = true


func start_recording() -> void:
	if not _available or _is_recording:
		return
	_capture_effect.clear_buffer()
	_stream_player.play()
	_is_recording = true
	recording_started.emit()


func stop_recording() -> void:
	if not _available or not _is_recording:
		return
	var frames := _capture_effect.get_frames_available()
	var buffer := _capture_effect.get_buffer(frames)
	_stream_player.stop()
	_is_recording = false
	recording_stopped.emit()
	if buffer.is_empty():
		return
	var wav_bytes := _build_wav(buffer, _sample_rate)
	_last_wav_bytes = wav_bytes
	audio_captured.emit(wav_bytes)


func has_last_audio() -> bool:
	return not _last_wav_bytes.is_empty()


func get_last_audio() -> PackedByteArray:
	return _last_wav_bytes


func clear_last_audio() -> void:
	_last_wav_bytes = PackedByteArray()


func is_playing() -> bool:
	return _playback_player != null and _playback_player.playing


func play_last_audio() -> void:
	if _last_wav_bytes.is_empty() or _playback_player == null:
		return
	var stream := _build_stream_from_wav(_last_wav_bytes)
	if stream == null:
		push_warning("VoiceManager: no se pudo construir AudioStreamWAV.")
		return
	_playback_player.stop()
	_playback_player.stream = stream
	_playback_player.play()
	playback_started.emit()


func stop_playback() -> void:
	if _playback_player != null and _playback_player.playing:
		_playback_player.stop()
		playback_finished.emit()


func _on_playback_finished() -> void:
	playback_finished.emit()


func _build_stream_from_wav(wav: PackedByteArray) -> AudioStreamWAV:
	if wav.size() < 44:
		return null
	# Cabecera WAV PCM mono 16-bit que genera _build_wav (44 bytes fijos).
	# Lee sample_rate del offset 24 y data del offset 44.
	var sample_rate: int = wav.decode_u32(24)
	var pcm := wav.slice(44)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = pcm
	return stream


func _build_wav(buffer: PackedVector2Array, sample_rate: int) -> PackedByteArray:
	var mono := PackedByteArray()
	for sample in buffer:
		var val := int(clamp((sample.x + sample.y) * 0.5, -1.0, 1.0) * 32767.0)
		mono.append(val & 0xFF)
		mono.append((val >> 8) & 0xFF)
	var data_size := mono.size()
	var wav := PackedByteArray()
	wav.append_array("RIFF".to_ascii_buffer())
	wav.resize(wav.size() + 4)
	wav.encode_u32(wav.size() - 4, data_size + 36)
	wav.append_array("WAVE".to_ascii_buffer())
	wav.append_array("fmt ".to_ascii_buffer())
	wav.resize(wav.size() + 4)
	wav.encode_u32(wav.size() - 4, 16)
	wav.resize(wav.size() + 2)
	wav.encode_u16(wav.size() - 2, 1)
	wav.resize(wav.size() + 2)
	wav.encode_u16(wav.size() - 2, 1)
	wav.resize(wav.size() + 4)
	wav.encode_u32(wav.size() - 4, sample_rate)
	wav.resize(wav.size() + 4)
	wav.encode_u32(wav.size() - 4, sample_rate * 2)
	wav.resize(wav.size() + 2)
	wav.encode_u16(wav.size() - 2, 2)
	wav.resize(wav.size() + 2)
	wav.encode_u16(wav.size() - 2, 16)
	wav.append_array("data".to_ascii_buffer())
	wav.resize(wav.size() + 4)
	wav.encode_u32(wav.size() - 4, data_size)
	wav.append_array(mono)
	return wav
