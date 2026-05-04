# ADR-0004: AudioEffectCapture para PTT — Captura de Voz WAV y Envío HTTP

## Estado
Propuesto

## Fecha
2026-05-01

## Compatibilidad con el Motor

| Campo | Valor |
|-------|-------|
| **Motor** | Godot 4.6 |
| **Dominio** | Audio / Entrada |
| **Riesgo de Conocimiento** | MEDIO — `AudioEffectCapture` requiere setup de AudioBus específico; conversión a WAV es manual |
| **Referencias Consultadas** | Conocimiento directo de Godot 4.6 API de audio |
| **APIs Post-Corte Usadas** | Ninguna — `AudioEffectCapture` estable desde Godot 4.0 |
| **Verificación Requerida** | (1) Confirmar que el micrófono aparece como dispositivo de entrada en `AudioServer.get_input_device_list()` en Windows. (2) Verificar que `get_buffer()` retorna datos válidos y no un array vacío. (3) Confirmar que faster-whisper acepta el formato WAV generado. |

## Dependencias ADR

| Campo | Valor |
|-------|-------|
| **Depende De** | ADR-0003 (backend FastAPI corriendo con endpoint `/stt` disponible) |
| **Habilita** | Epic de sistema de interrogatorio — la voz es el input principal del jugador |
| **Bloquea** | Sistema de Diálogo NPC — no puede implementarse sin audio capturado |
| **Nota de Orden** | Implementar y probar este ADR antes de integrar Diálogo NPC y Gajito |

## Contexto

### Declaración del Problema
El jugador debe poder hablar con los NPCs manteniendo presionada la tecla V (PTT — Push To Talk). El audio capturado debe enviarse al backend para transcripción STT (faster-whisper) dentro de un presupuesto de 4 segundos extremo a extremo. Se necesita decidir cómo capturar el micrófono en Godot 4.6, empaquetar el audio en un formato compatible con faster-whisper, y enviarlo al backend sin bloquear el hilo principal del juego.

### Restricciones
- Godot 4.6 GDScript — sin plugins de terceros
- El audio debe llegar a faster-whisper como WAV (PCM 16-bit, mono, 16000 Hz)
- Latencia total STT ≤ 4s (TR-voz-002): el envío HTTP no debe ocupar el hilo principal
- PTT: la grabación activa solo mientras V está presionada
- Solo Windows (mismo PC que backend)

### Requisitos
- Capturar audio del micrófono del sistema mientras el jugador mantiene V
- Empaquetar el buffer de audio como archivo WAV válido (sin escribir a disco)
- Enviar WAV al backend vía HTTP POST de forma no bloqueante
- Emitir señales para que HUD muestre indicador PTT activo
- Manejar el caso de micrófono no disponible sin crash

## Decisión

**Se usa `AudioEffectCapture` sobre un AudioBus dedicado con `AudioStreamMicrophone` para capturar el micrófono. Al soltar V, el buffer se convierte a WAV en memoria y se envía vía `HTTPRequest` al endpoint `/stt` del backend.**

### Setup requerido en Godot (una vez, en Project Settings)

```
Project Settings → Audio → Enable Input → ON
AudioBus "Mic":
  - Input: micrófono del sistema
  - Effect 0: AudioEffectCapture (buffer_length = 10.0 segundos)
  - Solo: false (no se reproduce por altavoces)
```

El bus "Mic" existe solo para captura — no se rutea a la salida de audio.

### Flujo PTT completo

```
Jugador mantiene V
  → Input.is_action_pressed("ptt") → true
  → VoiceManager.start_recording()
      → AudioStreamPlayer (stream: AudioStreamMicrophone) .play()
      → AudioEffectCapture.clear_buffer()
      → emit recording_started()
      → HUD: muestra indicador PTT rojo

Jugador suelta V
  → Input.is_action_just_released("ptt") → true
  → VoiceManager.stop_recording()
      → frames = AudioEffectCapture.get_frames_available()
      → buffer: PackedVector2Array = AudioEffectCapture.get_buffer(frames)
      → AudioStreamPlayer.stop()
      → wav_bytes: PackedByteArray = _build_wav(buffer, sample_rate=16000)
      → emit recording_stopped()
      → emit audio_captured(wav_bytes)
      → HUD: oculta indicador PTT

audio_captured recibido por LLMClient
  → HTTPRequest.request(
        "http://localhost:8000/stt",
        headers,
        HTTPClient.METHOD_POST,
        wav_bytes
    )
  → HUD: muestra "Gajito está pensando…"
```

### Diagrama de Arquitectura

```
Godot AudioServer
  └── Bus "Mic"
        ├── Input: micrófono del sistema
        └── Effect: AudioEffectCapture (buffer 10s)

VoiceManager (res://scripts/core/voice_manager.gd)
  ├── AudioStreamPlayer (stream: AudioStreamMicrophone)
  └── _process(): detecta Input "ptt"
        ├── Pressed → start_recording()
        └── Released → stop_recording() → _build_wav() → emit audio_captured

LLMClient (res://scripts/ai/llm_client.gd)
  └── audio_captured.connect(_on_audio_captured)
        └── HTTPRequest.request(POST /stt, wav_bytes)
              └── Backend faster-whisper → texto STT
```

### Interfaces Clave

```gdscript
# res://scripts/core/voice_manager.gd
extends Node

const SAMPLE_RATE := 16000
const BUS_NAME := "Mic"

var _capture_effect: AudioEffectCapture
var _stream_player: AudioStreamPlayer
var _is_recording := false

func _ready() -> void:
    _stream_player = AudioStreamPlayer.new()
    _stream_player.stream = AudioStreamMicrophone.new()
    _stream_player.bus = BUS_NAME
    add_child(_stream_player)
    var bus_idx := AudioServer.get_bus_index(BUS_NAME)
    _capture_effect = AudioServer.get_bus_effect(bus_idx, 0) as AudioEffectCapture

func _process(_delta: float) -> void:
    if Input.is_action_just_pressed("ptt"):
        start_recording()
    elif Input.is_action_just_released("ptt") and _is_recording:
        stop_recording()

func start_recording() -> void:
    _capture_effect.clear_buffer()
    _stream_player.play()
    _is_recording = true
    emit_signal("recording_started")

func stop_recording() -> void:
    var frames := _capture_effect.get_frames_available()
    var buffer := _capture_effect.get_buffer(frames)
    _stream_player.stop()
    _is_recording = false
    emit_signal("recording_stopped")
    if buffer.size() > 0:
        emit_signal("audio_captured", _build_wav(buffer))

func _build_wav(buffer: PackedVector2Array) -> PackedByteArray:
    # Convierte PackedVector2Array (stereo float32) a WAV mono PCM 16-bit
    var mono: PackedByteArray = PackedByteArray()
    for sample in buffer:
        var val := int(clamp((sample.x + sample.y) * 0.5, -1.0, 1.0) * 32767.0)
        mono.append(val & 0xFF)
        mono.append((val >> 8) & 0xFF)
    var data_size := mono.size()
    var wav := PackedByteArray()
    # Header WAV (44 bytes)
    wav.append_array("RIFF".to_ascii_buffer())
    wav.resize(wav.size() + 4); wav.encode_u32(wav.size() - 4, data_size + 36)
    wav.append_array("WAVE".to_ascii_buffer())
    wav.append_array("fmt ".to_ascii_buffer())
    wav.resize(wav.size() + 4); wav.encode_u32(wav.size() - 4, 16)      # chunk size
    wav.resize(wav.size() + 2); wav.encode_u16(wav.size() - 2, 1)       # PCM
    wav.resize(wav.size() + 2); wav.encode_u16(wav.size() - 2, 1)       # mono
    wav.resize(wav.size() + 4); wav.encode_u32(wav.size() - 4, SAMPLE_RATE)
    wav.resize(wav.size() + 4); wav.encode_u32(wav.size() - 4, SAMPLE_RATE * 2)  # byte rate
    wav.resize(wav.size() + 2); wav.encode_u16(wav.size() - 2, 2)       # block align
    wav.resize(wav.size() + 2); wav.encode_u16(wav.size() - 2, 16)      # bits per sample
    wav.append_array("data".to_ascii_buffer())
    wav.resize(wav.size() + 4); wav.encode_u32(wav.size() - 4, data_size)
    wav.append_array(mono)
    return wav

signal recording_started()
signal recording_stopped()
signal audio_captured(wav_bytes: PackedByteArray)
signal player_text_ready(text: String, npc_id: String)
# player_text_ready emitida tras recibir respuesta de /stt con texto no vacío.
# npc_id = ID del NPC activo en el momento de la captura (pasado como contexto).
# Consumidores: NPCDialogueManager (lanza petición NPC), GajitoModule (lanza /grammar en paralelo).
```

**Acción de entrada a registrar en Project Settings → Input Map:**
```
Acción: "ptt"
Tecla: V (físico)
```

**Backend — endpoint STT:**
```python
# backend/routers/stt.py
@app.post("/stt")
async def transcribe(request: Request):
    wav_bytes = await request.body()
    # faster-whisper transcribe desde bytes en memoria
    segments, _ = whisper_model.transcribe(io.BytesIO(wav_bytes), language="en")
    text = " ".join([s.text for s in segments])
    return {"text": text.strip()}
```

## Alternativas Consideradas

### Alternativa 1: Plugin GDNative/GDExtension de terceros para audio
- **Descripción:** Usar un addon de Godot Asset Library que exponga captura de audio más directa
- **Pros:** API posiblemente más simple
- **Contras:** Dependencia externa; riesgo de incompatibilidad con Godot 4.6; mantenimiento incierto
- **Razón de rechazo:** `AudioEffectCapture` es suficiente para el caso de uso y es parte del motor oficial.

### Alternativa 2: STT directamente en el cliente (Whisper.cpp en GDExtension)
- **Descripción:** Correr faster-whisper o whisper.cpp directamente en el proceso Godot
- **Pros:** Sin servidor separado para STT
- **Contras:** Complejidad enorme de integración; requiere GDExtension C++; tamaño del ejecutable; no compatible con el stack Python ya decidido
- **Razón de rechazo:** El backend Python ya existe para LLM — agregar STT ahí es trivial. GDExtension sería desproporcionado.

### Alternativa 3: Escribir audio a disco y leer desde backend
- **Descripción:** Guardar WAV en `user://temp_recording.wav` y el backend lo lee de disco
- **Pros:** Más simple de debuggear
- **Contras:** Latencia de I/O; condiciones de carrera; archivos temporales que limpiar
- **Razón de rechazo:** El envío HTTP en memoria es más limpio y más rápido.

## Consecuencias

### Positivas
- PTT nativo en Godot sin dependencias externas
- El buffer de 10s cubre interrogatorios razonablemente largos
- WAV en memoria evita I/O de disco
- El HUD puede mostrar indicador PTT reactivo via señales

### Negativas
- La conversión PackedVector2Array → WAV requiere código manual no trivial (~30 líneas)
- El sample rate de Godot debe coincidir con lo que faster-whisper espera (16000 Hz)
- `AudioEffectCapture` requiere configuración manual del AudioBus en el editor (no scripteable)

### Riesgos
- **Riesgo:** El sample rate de `AudioEffectCapture` no es 16000 Hz en todos los sistemas. **Mitigación:** Verificar `AudioServer.get_mix_rate()` en `_ready()`. Si no es 16000, hacer resample o documentar como requisito del sistema.
- **Riesgo:** Micrófono no disponible o sin permisos. **Mitigación:** Verificar `AudioServer.get_input_device_list()` en arranque; si está vacío, mostrar advertencia en menú principal (no bloquea el juego — el jugador puede escribir en vez de hablar si se implementa fallback).
- **Riesgo:** El jugador mantiene V más de 10s (límite del buffer). **Mitigación:** Forzar `stop_recording()` automáticamente a los 8s con un Timer interno.
- **Riesgo:** `_build_wav()` genera WAV que faster-whisper no acepta. **Mitigación:** Probar enviando un WAV de prueba antes de integrar con el juego completo; comparar con un WAV generado por Python como referencia.

## Requisitos GDD Abordados

| Sistema GDD | Requisito | Cómo lo aborda este ADR |
|-------------|-----------|-------------------------|
| gdd_detective_noir_vr.md | TR-voz-001: PTT hold V / LB → AudioEffectCapture → WAV → FastAPI | Implementación directa del flujo descrito |
| gdd_detective_noir_vr.md | TR-voz-002: Latencia STT ≤ 4s end-to-end | El envío HTTP es no bloqueante; el audio llega al backend en ms; la latencia restante es de faster-whisper |
| gdd_detective_noir_vr.md | TR-ui-001: Indicador PTT activo en HUD | Señales `recording_started` / `recording_stopped` permiten al HUD mostrar/ocultar el indicador |

## Implicaciones de Rendimiento
- **CPU:** La conversión WAV ocurre en el hilo principal al soltar V — ~1ms para 10s de audio; aceptable
- **Memoria:** Buffer de 10s × 16000 Hz × 2 canales × 4 bytes = ~1.28 MB máximo en RAM durante captura
- **Tiempo de carga:** Sin impacto en carga de escena
- **Red:** Envío WAV al backend: ~320 KB para 10s de audio en 16-bit mono — localhost, latencia < 5ms

## Plan de Migración
Primera implementación — no hay código existente que migrar.

## Criterios de Validación
- Al mantener V, el indicador PTT aparece en HUD dentro de 1 frame
- Al soltar V, se emite `audio_captured` con un `PackedByteArray` no vacío
- El WAV generado es aceptado por faster-whisper (verificar con script Python de prueba independiente)
- Una frase en inglés de 5 palabras transcribe correctamente en ≤ 4s desde soltar V
- Si el micrófono no está disponible, el juego muestra advertencia sin crash

## Decisiones Relacionadas
- ADR-0002: Ollama llama3.2 — el texto STT resultante va a Ollama vía `/npc/{id}`
- ADR-0003: Backend FastAPI — define el endpoint `/stt` que recibe el WAV
- Arquitectura maestra: `docs/architecture/architecture.md` sección "Pipeline de Interrogatorio"
