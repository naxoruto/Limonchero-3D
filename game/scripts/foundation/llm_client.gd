extends Node
## LLMClient — Autoload. Wrapper HTTP del backend Python (FastAPI).
## Endpoints consumidos: POST /stt, POST /npc/{npc_id}, POST /gajito/evaluate, GET /health.

signal stt_completed(transcript: String)
signal stt_failed(error: String)
signal npc_response_ready(npc_id: String, text: String)
signal npc_request_failed(npc_id: String, error: String)
signal npc_evidence_response_ready(npc_id: String, clue_id: String, raw_text: String, cleaned_text: String)
signal gajito_evaluation_ready(passed: bool, score: float, correction: String, tip: String, translation_es: String)
signal gajito_evaluation_failed(error: String)
signal health_check_done(ok: bool)

const DEFAULT_BASE_URL := "http://127.0.0.1:8000"
const BACKEND_URL_ENV := "LIMONCHERO_BACKEND_URL"
const REQUEST_TIMEOUT_SEC := 60.0

## Mientras el backend no exponga /gajito/evaluate, simulamos la respuesta
## localmente. Cambiar a false cuando el endpoint esté listo.
const MOCK_GAJITO_EVAL := true
const MOCK_GAJITO_DELAY := 0.8
const MOCK_GAJITO_FAIL_RATIO := 0.35

var _base_url: String = DEFAULT_BASE_URL

var _stt_req: HTTPRequest = null
var _npc_req: HTTPRequest = null
var _gajito_req: HTTPRequest = null
var _health_req: HTTPRequest = null
var _pending_npc_id: String = ""
var _pending_evidence_clue_id: String = ""
var _pending_gajito_transcript: String = ""

# Guardamos el resultado del ultimo STT para usarlo en Gajito
var _last_clarity_score: int = 0
var _last_words: Array = []
var _last_language: String = "en"


func _ready() -> void:
	_base_url = _resolve_base_url()
	_stt_req = HTTPRequest.new()
	_npc_req = HTTPRequest.new()
	_gajito_req = HTTPRequest.new()
	_health_req = HTTPRequest.new()
	add_child(_stt_req)
	add_child(_npc_req)
	add_child(_gajito_req)
	add_child(_health_req)
	_stt_req.timeout = REQUEST_TIMEOUT_SEC
	_npc_req.timeout = REQUEST_TIMEOUT_SEC
	_gajito_req.timeout = REQUEST_TIMEOUT_SEC
	_health_req.timeout = 3.0
	_stt_req.request_completed.connect(_on_stt_completed)
	_npc_req.request_completed.connect(_on_npc_completed)
	_gajito_req.request_completed.connect(_on_gajito_completed)
	_health_req.request_completed.connect(_on_health_completed)


func _resolve_base_url() -> String:
	var url := OS.get_environment(BACKEND_URL_ENV).strip_edges()
	if url.is_empty():
		url = DEFAULT_BASE_URL
	if url.ends_with("/"):
		url = url.trim_suffix("/")
	return url


func get_last_language() -> String:
	return _last_language

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
	var url := "%s/stt" % _base_url
	var err := _stt_req.request_raw(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		stt_failed.emit("HTTPRequest error: %d" % err)


## POST /npc/{npc_id} — body JSON {npc_id, history, message, presented_evidence}.
func request_npc(npc_id: String, message: String, history: Array) -> void:
	_pending_npc_id = npc_id
	var payload := {
		"npc_id": npc_id,
		"history": history,
		"message": message,
	}
	var body := JSON.stringify(payload)
	var headers := ["Content-Type: application/json"]
	var url := "%s/npc/%s" % [_base_url, npc_id]
	var err := _npc_req.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		npc_request_failed.emit(npc_id, "HTTPRequest error: %d" % err)


## POST /npc/{npc_id} — con pista presentada por el jugador.
## clue_data debe incluir: id, name, type, description.
func request_npc_with_evidence(npc_id: String, clue_data: Dictionary, history: Array) -> void:
	_pending_npc_id = npc_id
	_pending_evidence_clue_id = String(clue_data.get("id", ""))
	var evidence := {
		"clue_id": String(clue_data.get("id", "")),
		"clue_name": String(clue_data.get("name", clue_data.get("id", ""))),
		"clue_type": String(clue_data.get("type", "physical")),
		"clue_description": String(clue_data.get("description", "")),
	}
	var payload := {
		"npc_id": npc_id,
		"history": history,
		"message": "[EVIDENCE_PRESENTED:%s]" % evidence["clue_id"],
		"presented_evidence": evidence,
	}
	var body := JSON.stringify(payload)
	var headers := ["Content-Type: application/json"]
	var url := "%s/npc/%s" % [_base_url, npc_id]
	var err := _npc_req.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		npc_request_failed.emit(npc_id, "HTTPRequest error: %d" % err)


## POST /gajito/evaluate — body JSON {transcript, target_language}.
## Respuesta JSON: {pass, score, correction, tip, translation_es}.
func request_gajito_evaluation(transcript: String) -> void:
	if transcript.strip_edges().is_empty():
		gajito_evaluation_failed.emit("Transcript vacio")
		return
	_pending_gajito_transcript = transcript
	if MOCK_GAJITO_EVAL:
		_run_mock_gajito_evaluation(transcript)
		return
	var payload := {
		"transcript": transcript,
		"target_language": "en",
	}
	var body := JSON.stringify(payload)
	var headers := ["Content-Type: application/json"]
	var url := "%s/gajito/evaluate" % _base_url
	var err := _gajito_req.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		gajito_evaluation_failed.emit("HTTPRequest error: %d" % err)


## GET /health — verifica que backend este vivo.
func check_health() -> void:
	var err := _health_req.request("%s/health" % _base_url)
	if err != OK:
		health_check_done.emit(false)


# ── Mock Gajito (integrado con STT clarity score) ─────────────────────

func _run_mock_gajito_evaluation(transcript: String) -> void:
	await get_tree().create_timer(0.3).timeout # Simular leve delay de red
	var passed := true
	var score := float(_last_clarity_score) / 100.0
	var correction := ""
	var tip := ""
	var translation_es := "Traducción ES de: %s" % transcript
	
	if _last_language == "es":
		passed = false
		correction = "¡Hablaste en español! No se admiten trampas."
		tip = "Recuerda que Gajito sólo revisa y te ayuda si intentas pensar en inglés."
	elif _last_clarity_score > 0 and _last_clarity_score < 50:
		passed = false
		correction = "No se te entendió casi nada (Claridad total: %d%%)." % _last_clarity_score
		tip = "Intenta hablar más claro y con mejor volumen."
	else:
		var bad_words := PackedStringArray()
		for w in _last_words:
			if typeof(w) == TYPE_DICTIONARY and w.has("probability") and w.has("word"):
				if int(w["probability"]) < 60:
					bad_words.append(w["word"])
					
		if bad_words.size() > 0:
			passed = false
			correction = "Pronunciaste mal algunas palabras: " + ", ".join(bad_words)
			tip = "La oración se entiende (Claridad: %d%%), pero falla tu acento en esas sílabas." % _last_clarity_score

	gajito_evaluation_ready.emit(passed, score, correction, tip, translation_es)


# ── Callbacks ─────────────────────────────────────────────────────────────

func _on_stt_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		stt_failed.emit("STT HTTP %d (result %d)" % [code, result])
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if parsed == null or not parsed.has("transcript"):
		stt_failed.emit("Respuesta STT invalida")
		return
	
	_last_clarity_score = int(parsed.get("clarity_score", 0))
	_last_language = parsed.get("language", "en")
	var words_data = parsed.get("words", [])
	_last_words = words_data if typeof(words_data) == TYPE_ARRAY else []
		
	stt_completed.emit(parsed["transcript"])


func _on_npc_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var npc_id := _pending_npc_id
	var evidence_clue_id := _pending_evidence_clue_id
	_pending_npc_id = ""
	_pending_evidence_clue_id = ""
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		npc_request_failed.emit(npc_id, "NPC HTTP %d (result %d)" % [code, result])
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if parsed == null or not parsed.has("response"):
		npc_request_failed.emit(npc_id, "Respuesta NPC invalida")
		return
	var raw_text: String = parsed["response"]
	if evidence_clue_id.is_empty():
		npc_response_ready.emit(npc_id, raw_text)
	else:
		var cleaned := _strip_reaction_tags(raw_text)
		npc_evidence_response_ready.emit(npc_id, evidence_clue_id, raw_text, cleaned)


func _on_gajito_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_pending_gajito_transcript = ""
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		gajito_evaluation_failed.emit("Gajito HTTP %d (result %d)" % [code, result])
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if parsed == null or not parsed.has("pass"):
		gajito_evaluation_failed.emit("Respuesta Gajito invalida")
		return
	gajito_evaluation_ready.emit(
		bool(parsed.get("pass", false)),
		float(parsed.get("score", 0.0)),
		String(parsed.get("correction", "")),
		String(parsed.get("tip", "")),
		String(parsed.get("translation_es", ""))
	)


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


## Elimina tags de reacción (formato nuevo [RECOGNIZE] y legado <recognize/>).
func _strip_reaction_tags(text: String) -> String:
	var out := text
	# Nuevo formato: brackets, case-insensitive.
	var regex := RegEx.new()
	regex.compile("(?i)\\[(RECOGNIZE|DENY|EVADE|CONFESS)\\]")
	out = regex.sub(out, "", true)
	# Legado: tags XML por si algún prompt viejo los emite.
	out = out.replace("<recognize/>", "")
	out = out.replace("<deny/>", "")
	out = out.replace("<evade/>", "")
	out = out.replace("<confess/>", "")
	return out.strip_edges()


## Analiza la respuesta del NPC buscando el tag de reacción.
## Retorna "recognize", "deny", "evade", "confess", o "ambiguous".
func parse_npc_reaction(raw_text: String) -> String:
	var upper := raw_text.to_upper()
	# Formato nuevo (preferido).
	if "[RECOGNIZE]" in upper:
		return "recognize"
	if "[CONFESS]" in upper:
		return "confess"
	if "[DENY]" in upper:
		return "deny"
	if "[EVADE]" in upper:
		return "evade"
	# Legado XML.
	if "<recognize/>" in raw_text:
		return "recognize"
	if "<confess/>" in raw_text:
		return "confess"
	if "<deny/>" in raw_text:
		return "deny"
	if "<evade/>" in raw_text:
		return "evade"
	return "ambiguous"
