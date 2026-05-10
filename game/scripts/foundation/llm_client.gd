extends Node
## LLMClient — Autoload. Wrapper HTTP del backend Python (FastAPI).
## Endpoints consumidos: POST /stt, POST /npc/{npc_id}, GET /health.

signal stt_completed(transcript: String)
signal stt_failed(error: String)
signal npc_response_ready(npc_id: String, text: String)
signal npc_request_failed(npc_id: String, error: String)
signal health_check_done(ok: bool)

const BASE_URL := "http://localhost:8000"
const REQUEST_TIMEOUT_SEC := 60.0

var _stt_req: HTTPRequest = null
var _npc_req: HTTPRequest = null
var _health_req: HTTPRequest = null
var _pending_npc_id: String = ""


func _ready() -> void:
	_stt_req = HTTPRequest.new()
	_npc_req = HTTPRequest.new()
	_health_req = HTTPRequest.new()
	add_child(_stt_req)
	add_child(_npc_req)
	add_child(_health_req)
	_stt_req.timeout = REQUEST_TIMEOUT_SEC
	_npc_req.timeout = REQUEST_TIMEOUT_SEC
	_health_req.timeout = 3.0
	_stt_req.request_completed.connect(_on_stt_completed)
	_npc_req.request_completed.connect(_on_npc_completed)
	_health_req.request_completed.connect(_on_health_completed)


# ── Public API ────────────────────────────────────────────────────────────

## POST /stt — sube WAV crudo. Backend devuelve {transcript, duration_ms}.
func request_stt(wav_bytes: PackedByteArray) -> void:
	if wav_bytes.is_empty():
		stt_failed.emit("WAV vacio")
		return
	var boundary := "----GodotFormBoundary7MA4YWxkTrZu0gW"
	var body := _build_multipart_wav(wav_bytes, boundary)
	var headers := [
		"Content-Type: multipart/form-data; boundary=%s" % boundary,
		"Content-Length: %d" % body.size(),
	]
	var url := "%s/stt" % BASE_URL
	var err := _stt_req.request_raw(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		stt_failed.emit("HTTPRequest error: %d" % err)


## POST /npc/{npc_id} — body JSON {npc_id, history, message}.
func request_npc(npc_id: String, message: String, history: Array) -> void:
	_pending_npc_id = npc_id
	var payload := {
		"npc_id": npc_id,
		"history": history,
		"message": message,
	}
	var body := JSON.stringify(payload)
	var headers := ["Content-Type: application/json"]
	var url := "%s/npc/%s" % [BASE_URL, npc_id]
	var err := _npc_req.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		npc_request_failed.emit(npc_id, "HTTPRequest error: %d" % err)


## GET /health — verifica que backend este vivo.
func check_health() -> void:
	var err := _health_req.request("%s/health" % BASE_URL)
	if err != OK:
		health_check_done.emit(false)


# ── Callbacks ─────────────────────────────────────────────────────────────

func _on_stt_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		stt_failed.emit("STT HTTP %d (result %d)" % [code, result])
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if parsed == null or not parsed.has("transcript"):
		stt_failed.emit("Respuesta STT invalida")
		return
	stt_completed.emit(parsed["transcript"])


func _on_npc_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var npc_id := _pending_npc_id
	_pending_npc_id = ""
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		npc_request_failed.emit(npc_id, "NPC HTTP %d (result %d)" % [code, result])
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if parsed == null or not parsed.has("response"):
		npc_request_failed.emit(npc_id, "Respuesta NPC invalida")
		return
	npc_response_ready.emit(npc_id, parsed["response"])


func _on_health_completed(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	health_check_done.emit(result == HTTPRequest.RESULT_SUCCESS and code == 200)


# ── Multipart builder ─────────────────────────────────────────────────────

func _build_multipart_wav(wav_bytes: PackedByteArray, boundary: String) -> PackedByteArray:
	var crlf := "\r\n"
	var head := "--%s%s" % [boundary, crlf]
	head += "Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"%s" % crlf
	head += "Content-Type: audio/wav%s%s" % [crlf, crlf]
	var tail := "%s--%s--%s" % [crlf, boundary, crlf]
	var body := PackedByteArray()
	body.append_array(head.to_utf8_buffer())
	body.append_array(wav_bytes)
	body.append_array(tail.to_utf8_buffer())
	return body
