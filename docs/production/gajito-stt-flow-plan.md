# Plan — Flujo STT con Gajito como Gatekeeper

> **Estado:** propuesta (pendiente confirmación de preguntas abiertas al final)
> **Dependencias:** `dialogue.gd`, `voice_manager.gd`, `llm_client.gd`, FastAPI backend
> **No tocar todavía:** G2.4 Gajito popup global (este flujo lo reemplaza/integra dentro de DialogueUI)

---

## Flujo objetivo

```
[E] sobre NPC → abre DialogueUI
  │
  ├─ Idle timer (T1 segundos) → Gajito sugiere qué preguntar (hint)
  │
  └─ Mantén [V] → grabar audio
       │  suelta [V]
       ▼
   ┌─────────── REVISIÓN AUDIO ────────────┐
   │  ▶ Reproducir   ↻ Regrabar   ✓ Enviar │
   └─────────────────┬──────────────────────┘
                     │ ✓ Enviar
                     ▼
              POST /stt → transcript
                     │
   ┌─────────── REVISIÓN TEXTO ────────────┐
   │  "Did you see anyone last night?"     │
   │  ↻ Regrabar           ✓ Confirmar     │
   └─────────────────┬──────────────────────┘
                     │ ✓ Confirmar
                     ▼
            POST /gajito/evaluate → { pass: bool, score: float, correction: String }
                     │
       ┌─────────────┴─────────────┐
       │ pass=true                 │ pass=false
       ▼                           ▼
  POST /npc/{id}            Gajito popup con corrección
       │                           │
       ▼                           ▼
  Respuesta NPC en chat     Volver a "Mantén [V] para hablar"
```

---

## Fase A — Backend (FastAPI)

**A1. Endpoint `/stt` — sin cambios** salvo opcional: incluir `avg_logprob` (confianza Whisper) en respuesta.

**A2. Nuevo endpoint `POST /gajito/evaluate`**
- Body: `{ transcript: str, target_language: "en" }`
- Lógica: prompt al LLM (Ollama llama3.2) tipo "evalúa gramática y pronunciación inglesa del siguiente texto. Devuelve JSON".
- Respuesta:
  ```json
  {
    "pass": true,
    "score": 0.85,
    "correction": "Should be 'Did you see anyone last night?' (you said 'Did you saw...')",
    "tip": "Past tense + 'did' usa verbo en infinitivo."
  }
  ```
- Umbral `pass` decidido en backend (`score >= 0.7` por default, configurable).

**A3. Documentar en `docs/architecture/`** — añadir endpoint a la lista del proxy.

**Estimado:** 1–2h backend.

---

## Fase B — Cliente Godot (autoloads)

**B1. `VoiceManager` — guardar bytes para replay**
- Buffer interno `_last_wav_bytes: PackedByteArray` (ya emite por `audio_captured`, solo cachear)
- Método `get_last_audio() -> PackedByteArray`
- Método `play_last_audio()` — instancia `AudioStreamPlayer` con `AudioStreamWAV.create_from_buffer` (parser local de WAV o construir `AudioStreamWAV` desde PCM raw).
  - **Caveat:** `AudioStreamWAV` requiere PCM 8/16-bit + sample_rate. Si VoiceManager ya genera WAV header, lo parseamos; si genera PCM crudo, usamos directo.

**B2. `LLMClient` — nuevo método y señales**
- `request_gajito_evaluation(transcript: String)`
- Señales: `gajito_evaluation_ready(pass: bool, score: float, correction: String, tip: String)` + `gajito_evaluation_failed(error: String)`
- Mismo patrón que `request_npc`.

**Estimado:** 1h.

---

## Fase C — DialogueUI (state machine)

Reescritura de `dialogue.gd` como state machine. Estados:

| Estado | UI visible | Input válido |
|--------|-----------|--------------|
| `IDLE` | chat + status "Mantén [V] para hablar" | V (grabar), Esc (cerrar) |
| `RECORDING` | status "● Grabando..." | soltar V → CAPTURED |
| `CAPTURED` | panel revisión audio (▶ ↻ ✓) | botones |
| `STT_PROCESSING` | status "Transcribiendo..." | — |
| `TRANSCRIBED` | panel revisión texto (↻ ✓) | botones |
| `GAJITO_EVAL` | status "Gajito revisando..." | — |
| `GAJITO_FAIL` | popup corrección Gajito (✓ entendido → IDLE) | botón |
| `NPC_PROCESSING` | status "Pensando..." | — |
| `IDLE_TIMER` (sub-estado de IDLE) | hint de Gajito si T1 expira | — |

**Cambios concretos:**
- Añadir nodo `AudioReviewPanel` (PanelContainer hijo de VBox)
  - Label "Tu grabación" + 3 Buttons: `Reproducir` / `Regrabar` / `Enviar`
- Añadir nodo `TextReviewPanel`
  - Label que muestra transcript + 2 Buttons: `Regrabar` / `Confirmar`
- Añadir nodo `GajitoCorrectionPanel`
  - Label con `correction` + Label con `tip` + Button `Entendido, reintentar`
- Timer interno `_idle_hint_timer` (Timer node) — arranca al entrar IDLE, se resetea al hablar.

**Estimado:** 3–4h (mayor parte del trabajo).

---

## Fase D — `main_level.gd` — re-cableo

Cambiar el cableo actual:

- **Actual:**
  - `recording_stopped` → `VoiceManager.stop_recording`
  - `audio_captured` → `LLMClient.request_stt`
  - `stt_completed` → `_dialogue.add_player_message` → `LLMClient.request_npc`
  - `npc_response_ready` → `_dialogue.add_npc_message`

- **Nuevo:**
  - `recording_stopped` → `VoiceManager.stop_recording` → DialogueUI entra `CAPTURED` (no envía STT aún)
  - DialogueUI emite `audio_confirmed` → `LLMClient.request_stt`
  - `stt_completed` → DialogueUI entra `TRANSCRIBED` (no envía a Gajito aún)
  - DialogueUI emite `text_confirmed(transcript)` → `LLMClient.request_gajito_evaluation`
  - `gajito_evaluation_ready`:
    - `pass=true` → `add_player_message(transcript)` + `request_npc(...)`
    - `pass=false` → DialogueUI muestra `GAJITO_FAIL` con `correction` + `tip`

**Nuevas señales emitidas por DialogueUI:**
- `audio_confirmed()`
- `text_confirmed(transcript: String)`
- `retry_recording()` (al pulsar regrabar en cualquier panel — limpia estado y vuelve a IDLE)
- `gajito_correction_acknowledged()` (al cerrar GAJITO_FAIL)

**Estimado:** 1–2h.

---

## Fase E — Hints híbridos (hardcoded + lupa)

Sin endpoint LLM. Cero latencia, deterministas, testeables.

### E1 — Registry hardcoded

Nuevo archivo `docs/registry/npc_hints.yaml`:

```yaml
moni:
  - id: ask_about_voices
    text: "Pregúntale si oyó algo raro la noche del crimen."
    invalidates_when: ["heard_voices"]
  - id: ask_about_lighter
    text: "El mechero. Muestra el mechero ámbar."
    requires: ["has_f3"]
    invalidates_when: ["showed_f3"]
  - id: ask_about_barry
    text: "Pregunta directo por Barry Peel."
    invalidates_when: ["asked_barry"]
papolicia:
  - id: ...
gerry:
  - id: ...
lola:
  - id: ...
barry:
  - id: ...
```

- 3–5 hints por NPC, orden = de sutil a directo
- `requires`: lista de flags que deben estar `true` para ofrecer este hint (ej: tener F3 en inventario)
- `invalidates_when`: flags que marcan el hint como cubierto (no se vuelve a mostrar)
- Flags viven en un autoload `DialogueState` o se derivan del inventory + historial

### E2 — Loader

Autoload `HintRegistry` (singleton) carga el YAML al `_ready`. API:
- `get_next_hint(npc_id: String, state: Dictionary, shown_ids: Array) -> String`
- Devuelve primer hint válido (requires cumplidos, no invalidado, no mostrado en esta sesión)
- Si lista agotada → fallback `"Ya has cubierto lo importante. Confía en tu instinto."`

### E3 — Lupa en DialogueUI

- Icono 🔍 (TextureRect o Label con emoji) en esquina del panel
- Click → llama `HintRegistry.get_next_hint(...)` → muestra hint como mensaje verde lima del chat:
  ```
  Gajito: Pregúntale si oyó algo raro la noche del crimen.
  ```
- Tracker local `_hints_shown_this_session: Array[String]` para no repetir hasta cerrar diálogo

### E4 — Pop-up pasivo 40s

- Timer `_idle_hint_prompt` (40s) arranca al entrar IDLE, reset al pulsar V o recibir respuesta NPC
- Al expirar: micro-label discreto en esquina:
  ```
  💡 ¿Pierdes el hilo? Click 🔍
  ```
- No LLM, no auto-hint. Solo apunta a la lupa.
- Tras expirar, espera otros 40s antes de reaparecer

**Estimado:** 2h (registry + autoload + UI lupa + timer).

### Implicaciones

- Backend simplificado: solo `/stt`, `/npc/{id}`, `/gajito/evaluate`. **Eliminado `/gajito/hint`.**
- Cero costo LLM en hints
- Mantenimiento: editar `npc_hints.yaml` cuando narrativa cambia

---

## Orden de implementación sugerido

| # | Fase | Razón |
|---|------|-------|
| 1 | B1 — cache WAV en VoiceManager | bloqueante para review audio |
| 2 | C parcial — solo `CAPTURED` con replay + confirmar | demo del primer hub |
| 3 | C parcial — `TRANSCRIBED` con confirmar/regrabar | demo del segundo hub |
| 4 | D — re-cableo main_level con confirmaciones | conecta lo anterior |
| 5 | A2 — backend `/gajito/evaluate` | habilita gating |
| 6 | B2 — `LLMClient.request_gajito_evaluation` | cliente para A2 |
| 7 | C resto — GAJITO_EVAL, GAJITO_FAIL paneles | gating completo |
| 8 | E — idle hint timer | calidad de vida |

**Total estimado:** 8–12h de trabajo, repartido en 2–3 sesiones.

---

## Decisiones (cerradas)

1. **Formato audio cacheado:** WAV con header (lo que VoiceManager ya genera — 16-bit PCM mono). Playback parsea los 44 bytes de header y construye `AudioStreamWAV` con `data, format=FORMAT_16_BITS, mix_rate=_sample_rate, stereo=false`.
2. **Umbral pass/fail:** decisión backend. `score >= 0.7` por default, configurable vía env var. La UI solo recibe `pass: bool`.
3. **Idle hint:** **HARDCODED por NPC** (sin LLM). Registry `docs/registry/npc_hints.yaml`. Lupa 🔍 en DialogueUI da hints on-demand. Pop-up pasivo a los 40s apunta a la lupa.
4. **T1 idle:** 40 segundos (no auto-hint, solo prompt visual hacia la lupa).
5. **Hint repetido:** lupa cicla hints no-vistos esta sesión. Pop-up pasivo de 40s rearma cada 40s adicionales.
6. **TextReview muestra ambos:** texto inglés tal cual + traducción al español debajo (color verde lima, prefijo "Gajito: "). Requiere endpoint adicional o que Gajito eval/hint también devuelva traducción.
7. **Regrabar:** descarta audio anterior. No se guarda historial.

### Implicación adicional decisión 6

`/gajito/evaluate` debe extender respuesta:
```json
{
  "pass": true,
  "score": 0.85,
  "correction": "...",
  "tip": "...",
  "translation_es": "¿Viste a alguien anoche?"
}
```
Traducción siempre presente (pass=true o false), para que TextReview la muestre antes de enviar al NPC.

---

## Riesgos

- **Latencia acumulada:** STT (4 s budget) + Gajito eval (~3–5 s) + NPC (8 s budget) → ~15 s desde "✓ Confirmar" hasta respuesta NPC. Mostrar status claro en cada paso o el jugador piensa que está colgado.
- **Whisper en español:** si el jugador habla español por error, el STT inglés devuelve basura. Gajito debería detectar "no es inglés" como caso especial.
- **Audio playback en Godot 4:** `AudioStreamWAV` desde buffer requiere parsing manual del WAV header. Probarlo temprano (Fase B1) para no quedar bloqueado.
