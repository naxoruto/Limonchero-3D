# Sprint Plan — Mayo 2026
**Proyecto:** Limonchero 3D  
**Deadline final:** 2026-06-30  
**Generado:** 2026-05-03

---

## Sprint 0 — Design Cerrado
**Fechas:** 2026-05-03 → 2026-05-05 (2 días)  
**Responsable:** Diego  
**Goal:** Cerrar todos los gaps de diseño antes de que el equipo de código los necesite.

| Tarea | Entregable | Estado |
|-------|-----------|--------|
| Crear `art/art-style-definition.md` | Paleta + estilo + referencias visuales | ⬜ Pendiente |
| Crear `art/audio-design.md` | Lista SFX + specs balbuceos + 2 tracks música | ⬜ Pendiente |
| Crear `art/npc-llm-prompts.md` | 6 system prompts canónicos (para Martín) | ⬜ Pendiente |
| Crear historias épicas faltantes | `/create-stories cargador-escena`, `/create-stories controlador-jugador`, `/create-stories sistema-interaccion` | ⬜ Pendiente |
| Corregir `CLAUDE.md` | Remover refs OpenAI/Gemini → Ollama-only | ⬜ Pendiente |
| Modelar Agave (prop decorativo del club) | Static mesh low-poly, `assets/models/agave_v1.glb` | ⬜ Pendiente |

**Definition of Done Sprint 0:** Diego confirma los 6 docs existentes antes del 05 mayo.

---

## Sprint 1 — Backend + Foundation
**Fechas:** 2026-05-05 → 2026-05-12 (7 días)  
**Goal:** Backend Python fully live + GameManager completo + Scene Loader funcional.  
**Resultado esperado:** Godot puede enviar una pregunta al LLM y recibir respuesta de texto.

---

### Martín — Backend (BLOQUEANTE GLOBAL)

> Orden obligatorio: 001 → 003 → 004 → 002. Story 003 desbloquea Ignacio para LLM Client.

#### Story 001 — FastAPI Base + `/health`
**Archivo:** `production/epics/proxy-backend/story-001-estructura-base-health.md`  
**Estimado:** 2-3 horas  
**Criterios de aceptación:**
- [ ] Proyecto FastAPI creado en `backend/`
- [ ] `backend/requirements.txt` con: `fastapi uvicorn[standard] httpx ollama faster-whisper pytest pytest-asyncio`
- [ ] `GET /health` responde `{"status": "ok", "version": "1.0"}`
- [ ] `uvicorn backend.main:app --reload` arranca sin errores
- [ ] Test: `pytest backend/tests/test_health.py` pasa
- [ ] Verificación manual: `curl http://localhost:8000/health`

**Flujo de trabajo:**
```
/story-readiness production/epics/proxy-backend/story-001-estructura-base-health.md
→ /dev-story production/epics/proxy-backend/story-001-estructura-base-health.md
→ /story-done production/epics/proxy-backend/story-001-estructura-base-health.md
```

---

#### Story 003 — `/npc/{id}` Proxy a Ollama
**Archivo:** `production/epics/proxy-backend/story-003-endpoint-npc.md`  
**Estimado:** 5-6 horas  
**Prerequisito:** Story 001 ✓ + Ollama corriendo con `llama3.2`

**Request:**
```json
POST /npc/{npc_id}
{
  "history": [
    {"role": "user", "content": "Did you see anything tonight?"},
    {"role": "assistant", "content": "I was in the bathroom."}
  ],
  "message": "Are you sure no one could have entered the back door?"
}
```

**Response:**
```json
{
  "response": "Maybe.",
  "npc_id": "gerry",
  "duration_ms": 1840
}
```

**Criterios de aceptación:**
- [ ] Endpoint acepta los 6 NPC IDs: `spud`, `moni`, `gerry`, `lola`, `barry`, `gajito`
- [ ] Cada NPC usa su system prompt canónico (desde `art/npc-llm-prompts.md` o hardcoded en `backend/npc_prompts.py`)
- [ ] Historial de conversación incluido en el contexto enviado a Ollama
- [ ] Timeout de 8 segundos (retorna `{"error": "timeout"}` si supera)
- [ ] Barry responde en modo normal cuando `clues_presented` está vacío
- [ ] Barry confiesa cuando `clues_presented` contiene `["F1", "F2", "F3"]`
- [ ] Test: `pytest backend/tests/test_npc.py` pasa (mínimo 4 tests)
- [ ] Test manual: `curl -X POST localhost:8000/npc/gerry -d '{"history":[],"message":"Where were you?"}'`

**NPC IDs y restricciones críticas:**

| npc_id | Idioma respuesta | Condición especial |
|--------|-----------------|-------------------|
| `spud` | English only | Más paciente en escena tutorial inicial |
| `moni` | English only | Deflectar con coqueteo en preguntas difíciles |
| `gerry` | English only | Respuestas de 1-2 palabras |
| `lola` | English only | Nunca mencionar documentos ni demanda |
| `barry` | English only | Solo confiesa con F1+F2+F3 simultáneos |
| `gajito` | Español only | Corrección irónica + constructiva |

---

#### Story 004 — `/grammar` Endpoint (Gajito)
**Archivo:** `production/epics/proxy-backend/story-004-endpoint-grammar.md`  
**Estimado:** 4 horas  
**Prerequisito:** Story 001 ✓

**Request:**
```json
POST /grammar
{
  "transcript": "I are looking for evidence",
  "context": "detective interrogation"
}
```

**Response:**
```json
{
  "is_correct": false,
  "original": "I are looking for evidence",
  "correction": "I am looking for evidence",
  "explanation_es": "\"I are\" no existe en inglés. Con primera persona singular se usa \"I am\".",
  "severity": "high"
}
```

**Criterios de aceptación:**
- [ ] Responde `is_correct: true` para inglés gramaticalmente correcto
- [ ] Responde `is_correct: false` con corrección y explicación en español
- [ ] Campo `severity`: `"low"` (estilo/vocabulario) | `"high"` (error gramatical grave)
- [ ] Solo dispara corrección para `severity: "high"` — no interrumpir por errores menores
- [ ] Test: `pytest backend/tests/test_grammar.py` pasa (mínimo 3 tests)

---

#### Story 002 — `/stt` Endpoint (faster-whisper)
**Archivo:** `production/epics/proxy-backend/story-002-endpoint-stt.md`  
**Estimado:** 4-5 horas  
**Prerequisito:** Story 001 ✓ | Coordinar con Sofía para prueba de audio

**Request:**
```
POST /stt
Content-Type: audio/wav
[binary WAV data]
```

**Response:**
```json
{
  "transcript": "Did you hear a gunshot tonight?",
  "duration_ms": 2340,
  "language": "en",
  "confidence": 0.94
}
```

**Criterios de aceptación:**
- [ ] Acepta WAV binary en body (no form-data)
- [ ] Usa faster-whisper modelo `medium` (o `large-v3` si la máquina aguanta)
- [ ] Idioma forzado a `en` (inglés)
- [ ] Retorna transcript + duración en ms
- [ ] Latencia ≤ 3s para frase de 8 palabras en máquina de desarrollo
- [ ] Test: `pytest backend/tests/test_stt.py` con archivo `.wav` fixture
- [ ] Verificación con Sofía: grabar 5 frases → ≥ 85% palabras correctas

---

### Ignacio — Godot Foundation (paralelo a Backend)

> No espera backend. GameManager y Scene Loader son puramente locales.

#### Completar GameManager (Stories 002-005)

**Story 002 — Ciclo de Vida de Pistas**  
**Archivo:** `production/epics/gamemanager/story-002-ciclo-vida-pistas.md`  
**Estimado:** 3-4 horas

Criterios de aceptación:
- [ ] `register_clue(clue_id: String, state: String)` — registra pista en dict
- [ ] `mark_clue_good(clue_id: String)` — marca pista como GOOD
- [ ] `get_clue_state(clue_id: String) -> Dictionary` — retorna `{state, timestamp}`
- [ ] Clue IDs válidos: `F1`, `F2`, `F3`, `F4`, `F5`, `D1`-`D5`
- [ ] Estado inicial de todas las pistas: `"undiscovered"`
- [ ] Test GUT pasa

**Story 003 — Puerta de Confesión**  
**Archivo:** `production/epics/gamemanager/story-003-puerta-confesion.md`  
**Estimado:** 2-3 horas

Criterios de aceptación:
- [ ] `can_confess(accused: String) -> bool`
- [ ] Retorna `true` solo si: F1=GOOD **Y** F2=GOOD **Y** F3=GOOD **Y** `accused == "barry"`
- [ ] Retorna `false` en cualquier otro caso (acusado incorrecto, pistas insuficientes)
- [ ] Test GUT: 4 casos (correcto, acusado incorrecto, 2 pistas, 0 pistas)

**Story 004 — Telemetría**  
**Archivo:** `production/epics/gamemanager/story-004-registro-telemetria.md`  
**Estimado:** 2-3 horas

Criterios de aceptación:
- [ ] `log_event(event_type: String, data: Dictionary)` — añade al array de telemetría
- [ ] Campos canónicos (ADR-0007): `npcs_interrogated`, `anti_stall_triggers`, `clues_collected`, `session_start_time`
- [ ] Test GUT pasa

**Story 005 — Exportación JSON**  
**Archivo:** `production/epics/gamemanager/story-005-exportacion-json.md`  
**Estimado:** 2 horas

Criterios de aceptación:
- [ ] `export_session_json() -> String` — serializa estado completo a JSON
- [ ] Incluye: pistas, telemetría, `accusation_attempts` (Array), timestamp
- [ ] `save_session_to_file(path: String)` — escribe JSON a disco
- [ ] Test GUT pasa

---

#### Scene Loader
**Epic:** `production/epics/cargador-escena/`  
**Estimado:** 4-5 horas total

- [ ] Crear Story 001 si no existe: `/create-stories cargador-escena`
- [ ] `scripts/foundation/scene_loader.gd` como Autoload `SceneLoader`
- [ ] `load_scene(path: String)` — cambia escena con fade
- [ ] Main menu (`scenes/main_menu.tscn`) tiene botón "Iniciar Investigación"
- [ ] Botón carga `scenes/el_agave_y_la_luna.tscn`
- [ ] Si backend no responde en startup → mensaje de error visible en main menu (no crash)

---

### Definición de "Done" — Sprint 1

Al finalizar el sprint (2026-05-12), el equipo debe poder demostrar:

1. `curl http://localhost:8000/health` → `{"status": "ok"}`
2. `curl -X POST localhost:8000/npc/gerry -d '{"history":[],"message":"Where were you?"}'` → respuesta en inglés monosilábica
3. Godot: juego arranca, main menu visible, clic "Iniciar" carga El Agave y La Luna
4. `GameManager.can_confess("barry")` retorna `false` sin pistas
5. `GameManager.can_confess("barry")` retorna `true` después de marcar F1+F2+F3 como GOOD
6. Todos los tests del backend (`pytest backend/`) pasan
7. Todos los tests GUT del GameManager pasan

---

## Sprint 2 — Features Core
**Fechas:** 2026-05-12 → 2026-05-19  
**Goal:** Player puede moverse, interactuar con pistas, y hacer una pregunta a un NPC por voz.  
*(Detalle completo se expande al cerrar Sprint 1)*

Tareas previstas:
- Ignacio: Player Controller + LLM Client Godot
- Sofía: Voice/PTT epic (espera Backend Story 001+002 ✓)
- Martín: Ajustes y bugs del backend según feedback de Ignacio
- Diego + Art: Iniciar modelos 3D pistas físicas (R1, R2, R3 primero)

---

## Sprint 3 — Arte + Audio + NPC Hardcoding
**Fechas:** 2026-05-19 → 2026-05-26  
*(Detalle completo se expande al cerrar Sprint 2)*

Tareas previstas:
- Arte: Modelos pistas físicas completados, Agave (prop decorativo)
- Sofía: Audio completo (música, SFX, balbuceos)
- Ignacio: Inventory System, HUD, NPC Controller
- Martín: NPC prompts hardcoded + test confesión Barry

---

## Sprint 4 — Integración + Playtest
**Fechas:** 2026-05-26 → 2026-06-02  
*(Detalle completo se expande al cerrar Sprint 3)*

Tareas previstas:
- Smoke test crítico completo
- Primer playtest interno (toda la ruta: pistas → interrogatorio → acusación)
- Medición de latencia STT + LLM
- Bugs de integración

---

## Sprint 5 — Polish + QA
**Fechas:** 2026-06-02 → 2026-06-09  
*(Detalle completo se expande al cerrar Sprint 4)*

Tareas previstas:
- Bugfixes del playtest
- Balance de audio (music -6dB, sfx 0dB, babble -9dB)
- Accesibilidad: añadir apliques ámbar en Pasillo Servicio (fix deuteranopia)
- Build export Windows + Linux

---

## Sprint 6 — Release
**Fechas:** 2026-06-09 → 2026-06-30  
- Build final + README instalación para evaluador
- Docs de entrega académica
- Buffer de bugs de último minuto

---

## Dependencias entre personas

```
Diego (Sprint 0 docs)
  └── Martín necesita npc-llm-prompts.md para Story 003

Martín Story 001 (/health)
  └── Sofía puede iniciar Voice/PTT epic en Godot

Martín Story 003 (/npc)
  └── Ignacio puede implementar LLM Client Godot

Ignacio GameManager 003 (confesión gate)
  └── Test end-to-end de acusación Barry

Art modelos R3 (encendedor)
  └── Interaction System QA puede verificar pista crítica F3
```

---

*Actualizar estado de cada tarea al completarla. Próxima revisión: 2026-05-12 (cierre Sprint 1).*
