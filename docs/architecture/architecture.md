# Detective Noir "Limonchero 3D" — Arquitectura Maestra

## Estado del Documento

- **Versión:** 1.1
- **Última actualización:** 2026-05-04
- **Motor:** Godot 4.6 (GDScript)
- **GDDs cubiertos:** gdd/gdd_detective_noir_vr.md (v0.3), levels/el_agave_y_la_luna.md, narrative/cast-bible.md, narrative/world-rules.md
- **ADRs referenciados:** ADR-0001..ADR-0017 (ver docs/architecture/traceability-index.md)
- **Aprobación Dirección Técnica:** 2026-05-01 — APROBADO
- **Revisión Factibilidad Programación:** Omitida — modo Lean

---

## Resumen de APIs del Motor

- **Motor:** Godot 4.6 (GDScript)
- **APIs verificadas contra Godot 4.6:**
  - `AudioEffectCapture` — estable en 4.6, usar `get_buffer(frames)` + `can_get_buffer(frames)`
  - `HTTPRequest` — estable en 4.6, señal `request_completed(result, code, headers, body)`
  - `CharacterBody3D` — estable, riesgo bajo
  - `SubViewport` — estable en 4.6

---

## Línea Base de Requisitos Técnicos

Extraído de GDD v0.3 + CLAUDE.md | **27 requisitos**

| ID Req | Sistema | Requisito | Dominio |
|--------|---------|-----------|---------|
| TR-jugador-001 | Jugador | Movimiento FPS — CharacterBody3D + Camera3D, WASD/mouse + mando | Núcleo/Entrada |
| TR-jugador-002 | Jugador | Sprint (Shift/L3) | Núcleo |
| TR-interact-001 | Interacción | Detección de proximidad → tecla E, menú contextual (Interrogar/Examinar) | Núcleo |
| TR-interact-002 | Interacción | Modo inspección de objeto — overlay centrado, Esc para cerrar | Núcleo/UI |
| TR-interact-003 | Interacción | Recogida de pista → inventario + prompt "¿Agregar como evidencia?" durante diálogo | Núcleo |
| TR-pista-001 | Evidencias/Inventario | Inventario 8 slots, distingue pistas físicas vs testimonios | Característica |
| TR-pista-002 | Evidencias/Inventario | Tablón diegético (pared 3D) + vista Tab legible en HUD | Característica/UI |
| TR-pista-003 | Evidencias/Inventario | Estado de cada pista: BUENA / NO_BUENA / SIN_REVISAR | Característica |
| TR-npc-001 | NPC | 5 NPCs con prompt de sistema único + historial de diálogo por sesión | Característica/IA |
| TR-npc-002 | NPC | Balbuceo por NPC — clip corto sincronizado con velocidad de texto | Presentación |
| TR-voz-001 | Voz/STT | PTT — mantener V / LB → AudioEffectCapture → WAV → FastAPI | Núcleo |
| TR-voz-002 | Voz/STT | Latencia STT ≤ 4s extremo a extremo, inglés con acento latino, >85% precisión | Núcleo |
| TR-llm-001 | Cliente LLM | HTTP POST localhost → FastAPI → Ollama/GPT-4o-mini | Fundación |
| TR-llm-002 | Cliente LLM | Timeout 8s por respuesta de NPC | Fundación |
| TR-llm-003 | Cliente LLM | Ollama + llama3.2 para todas las fases (ADR-0002 — Ollama exclusivo) | Fundación |
| TR-gajito-001 | Gajito | Evaluador gramatical: texto jugador → LLM → corrección español en pop-up | Característica/IA |
| TR-gajito-002 | Gajito | Evaluación en paralelo a la respuesta del NPC | Característica |
| TR-acus-001 | Acusación | Árbol de diálogo con Comisario Spud, hasta 3 pruebas | Característica |
| TR-acus-002 | Acusación | Puerta de confesión: F1+F2+F3 BUENAS simultáneas + Barry nombrado | Característica |
| TR-estado-001 | Estado de Juego | GameManager autoload: estado de pistas, progreso, flags | Fundación |
| TR-estado-002 | Estado de Juego | Anti-estancamiento L1/L2/L3: pistas a los 4/5/7 min sin evidencia nueva | Característica |
| TR-ui-001 | HUD/UI | Subtítulos dos canales, indicador PTT, pop-up Gajito | Presentación |
| TR-ui-002 | HUD/UI | Slider FOV 70–110°, tamaño de subtítulos ajustable | Presentación |
| TR-backend-001 | Backend | FastAPI: /stt /npc/{id} /grammar; detección sin conexión al arrancar | Fundación |
| TR-nivel-001 | Nivel de Inglés | Selector en menú principal (Principiante/Intermedio/Avanzado) | Característica/UI |
| TR-nivel-002 | Diálogo NPC | Prompt de sistema condicionado por nivel de inglés seleccionado | Característica/IA |
| TR-telemetria-001 | Registro de Sesión | GameManager registra eventos con marca de tiempo durante la sesión | Fundación |
| TR-telemetria-002 | Registro de Sesión | Exportación JSON al terminar la partida o al salir | Fundación |
| TR-telemetria-003 | Registro de Sesión | Campos: session_id, english_level, duración, pistas, npcs, acusaciones, errores, pistas anti-estancamiento, completado, acertó | Fundación |

---

## Mapa de Capas del Sistema

```
┌─────────────────────────────────────────────────────────────┐
│  CAPA DE PRESENTACIÓN                                       │
│  HUD/UI  ·  Audio Balbuceo NPC  ·  Overlay de Inspección   │
├─────────────────────────────────────────────────────────────┤
│  CAPA DE CARACTERÍSTICAS                                    │
│  Evidencias/Inventario  ·  Diálogo NPC  ·  Asistente Gajito│
│  Acusación/Final  ·  Anti-Estancamiento  ·  Nivel de Inglés │
│  Tablón Diegético de Evidencias                             │
├─────────────────────────────────────────────────────────────┤
│  CAPA NÚCLEO                                                │
│  Controlador Jugador  ·  Sistema Interacción  ·  Voz/PTT   │
├─────────────────────────────────────────────────────────────┤
│  CAPA DE FUNDACIÓN                                          │
│  GameManager (autoload)  ·  Cliente LLM  ·  Cargador Escena│
│  Registro de Sesión (parte de GameManager)                  │
│  Proxy Backend (Python/FastAPI — proceso separado)          │
├─────────────────────────────────────────────────────────────┤
│  CAPA DE PLATAFORMA                                         │
│  API motor Godot 4.6  ·  Audio SO  ·  HTTP  ·  Python 3.x  │
└─────────────────────────────────────────────────────────────┘
```

| Módulo | Capa |
|--------|------|
| HUD/UI | Presentación |
| Audio Balbuceo NPC | Presentación |
| Overlay de Inspección | Presentación |
| Sistema Evidencias/Inventario | Características |
| Sistema Diálogo NPC | Características |
| Asistente Gajito | Características |
| Acusación/Final | Características |
| Sistema Anti-Estancamiento | Características |
| Nivel de Inglés | Características |
| Tablón Diegético de Evidencias | Características |
| Controlador del Jugador | Núcleo |
| Sistema de Interacción | Núcleo |
| Voz/PTT | Núcleo |
| GameManager | Fundación |
| Cliente LLM | Fundación |
| Cargador de Escena | Fundación |
| Proxy Backend (FastAPI) | Fundación* |

*El Proxy Backend es un proceso Python externo. Parte del sistema, no del proceso Godot.

---

## Propiedad de Módulos

### Capa de Fundación

| Módulo | Posee | Expone | Consume | APIs del Motor |
|--------|-------|--------|---------|----------------|
| **GameManager** | Estado canónico: pistas, flags F1/F2/F3, puerta de confesión, english_level, session_id, telemetría | `add_clue()`, `set_clue_state()`, `is_confession_gate_open()`, `export_session_json()`, señales | — (fuente de verdad) | `Node` autoload, `signal`, `FileAccess` |
| **Cliente LLM** | Conexión HTTP a FastAPI, lógica de timeout | `send_npc_request()`, `send_grammar_check()`, `check_backend_health()` → señales | — | `HTTPRequest`, `OS.get_ticks_msec()` |
| **Cargador de Escena** | Transiciones de escena | `load_scene(path)` | GameManager (estado persistido) | `SceneTree.change_scene_to_file()` |
| **Proxy Backend** *(Python)* | Pipeline STT, enrutamiento LLM, evaluación gramatical | `POST /stt`, `POST /npc/{id}`, `POST /grammar`, `GET /health` | faster-whisper, Ollama/OpenAI | FastAPI, faster-whisper, httpx |

### Capa Núcleo

| Módulo | Posee | Expone | Consume | APIs del Motor |
|--------|-------|--------|---------|----------------|
| **Controlador del Jugador** | Movimiento FPS, rotación cámara, sprint | señal `interacted(target)`, posición/rotación | Entrada | `CharacterBody3D`, `Camera3D`, `Input` |
| **Sistema de Interacción** | Detección proximidad, menú contextual, recogida de pistas | señal `clue_picked(clue_id)`, señal `npc_context_opened(npc_id)` | Controlador Jugador, GameManager | `Area3D`, `RayCast3D` |
| **Voz/PTT** | Captura de audio, empaquetado WAV, envío al backend | señal `recording_started`, señal `audio_captured(wav_bytes)` | Entrada (V/LB), Cliente LLM | `AudioEffectCapture`, `AudioStreamMicrophone` |

### Capa de Características

| Módulo | Posee | Expone | Consume | APIs del Motor |
|--------|-------|--------|---------|----------------|
| **Evidencias/Inventario** | 8 slots, tipos, estados | `get_inventory()`, `has_clue()`, señal `inventory_changed` | GameManager | `Resource` / Dictionary |
| **Diálogo NPC** | Historial de conversación por NPC | señal `npc_response_ready(npc_id, text)`, señal `babble_trigger(npc_id)` | Cliente LLM, GameManager, Voz/PTT | `Node`, `Timer` |
| **Asistente Gajito** | Evaluación gramatical | señal `correction_ready(text)` | Cliente LLM | `Node` |
| **Acusación/Final** | Árbol de diálogo Spud, lógica de acusación | señal `case_resolved(correct: bool)` | GameManager | `Node` |
| **Anti-Estancamiento** | Temporizadores L1(4min)/L2(5min)/L3(7min) | señal `hint_trigger(level: int)` | GameManager (señal `clue_added` → reinicio) | `Timer` |
| **Nivel de Inglés** | Nivel seleccionado por el jugador | — (almacenado en GameManager) | — | — |
| **Tablón Diegético** | Representación 3D del inventario en la pared | — | Evidencias/Inventario | `Node3D`, `Sprite3D` / `SubViewport` |

### Capa de Presentación

| Módulo | Posee | Expone | Consume | APIs del Motor |
|--------|-------|--------|---------|----------------|
| **HUD/UI** | Subtítulos, indicador PTT, pop-up Gajito, pausa, slider FOV | — | Diálogo NPC, Gajito, Voz/PTT, GameManager | `CanvasLayer`, `Label`, `AnimationPlayer` |
| **Audio Balbuceo NPC** | Clips de audio por NPC, sincronización con velocidad de texto | — | Diálogo NPC (señal `babble_trigger`) | `AudioStreamPlayer` |
| **Overlay de Inspección** | Objeto en overlay centrado | — | Sistema Interacción (señal `inspect_opened`) | `SubViewport` / `CanvasLayer` |

### Diagrama de Dependencias

```
Plataforma (Godot 4.6 / FastAPI)
  └── Fundación
        ├── GameManager ◄──────────────────────────────────┐
        ├── Cliente LLM ◄───────────────────────────────┐  │
        ├── Cargador de Escena                          │  │
        └── Proxy Backend (Python)                      │  │
              └── Núcleo                                │  │
                    ├── Controlador Jugador             │  │
                    ├── Sistema Interacción ────────────┼──┘ (add_clue)
                    └── Voz/PTT ─────────────────────────┘ (envía vía Cliente LLM)
                          └── Características
                                ├── Diálogo NPC ──────────► Cliente LLM
                                ├── Gajito ───────────────► Cliente LLM
                                ├── Evidencias/Inventario ► GameManager
                                ├── Acusación ─────────────► GameManager
                                ├── Anti-Estancamiento ────► GameManager
                                └── Tablón Diegético ───────► Evidencias/Inventario
                                      └── Presentación
                                            ├── HUD/UI
                                            ├── Audio Balbuceo NPC
                                            └── Overlay de Inspección
```

**Regla:** las dependencias van hacia abajo o al mismo nivel. Fundación nunca importa de Características/Núcleo. GameManager comunica hacia arriba solo mediante señales.

---

## Flujo de Datos

### Ruta de Actualización por Fotograma

```
Entrada (teclado/mando)
  → Controlador Jugador._physics_process()
      → CharacterBody3D.move_and_slide()
      → Rotación Camera3D
  → Sistema Interacción._process()
      → Verificación RayCast3D / Area3D
      → Si objeto cerca: mostrar prompt en HUD
      → Si tecla-E: emitir interacted(objetivo)
  → HUD._process()
      → Dibuja estado PTT, subtítulos activos
```

Tipo: sincrónico, por fotograma. No cruza hilos.

---

### Pipeline de Interrogatorio (PTT → STT → LLM → Pantalla)

```
Jugador mantiene V
  → Voz/PTT: AudioEffectCapture.get_buffer()

[Jugador suelta V]
  → Voz/PTT: emite audio_captured(wav_bytes)
  → Cliente LLM: POST localhost/stt  {audio: wav_bytes}
      ← Backend: texto STT (string)
  → Diálogo NPC: recibe texto STT
      → agrega al historial: {role:"user", content: texto}
      → Cliente LLM: POST localhost/npc/{npc_id}
                         {history: [...], system_prompt: PROMPT_NPC + MODIFICADOR_NIVEL}
          ← Backend (≤8s timeout): texto respuesta NPC
      → emite npc_response_ready(texto, npc_id)
          → HUD: muestra subtítulo NPC letra a letra
          → Audio Balbuceo: reproduce clip sincronizado

  [En paralelo]
  → Gajito: Cliente LLM POST localhost/grammar {text: texto_STT}
      ← Backend: {error: bool, correction: string}
      → Si error: emite correction_ready(corrección)
          → HUD: muestra pop-up Gajito (~5s)
          → GameManager.register_grammar_error()
```

Tipo: asíncrono (HTTPRequest sin bloqueo). Timeout 8s → HUD muestra "Gajito está pensando…"

---

### Ruta de Recogida de Pista

```
Jugador tecla-E sobre objeto pista
  → Sistema Interacción: emite clue_picked(clue_id)
  → GameManager.add_clue(clue_id)
  → Evidencias/Inventario: emite inventory_changed
      → HUD: actualiza vista Tab
      → Tablón Diegético: actualiza representación 3D
  → Anti-Estancamiento: reinicia temporizadores (recibe clue_added)
  → Overlay de Inspección: muestra objeto
```

Tipo: cadena de eventos/señales, sincrónico.

---

### Ruta de Recogida de Testimonio

```
NPC responde con línea clave
  → HUD muestra prompt "¿Agregar como evidencia? [X]"
  → Jugador tecla-X
  → Diálogo NPC: emite testimony_prompt_shown(clue_id) → Sistema Interacción
  → [flujo idéntico a Recogida de Pista desde clue_picked en adelante]
```

---

### Ruta de Acusación

```
Jugador habla con Comisario Spud → Acusación/Final se activa
  → Jugador selecciona evidencias + nombra sospechoso
  → Acusación: GameManager.is_confession_gate_open()
      Si F1+F2+F3 BUENAS + Barry nombrado → emite case_resolved(correct=true)
      Si no → emite case_resolved(correct=false)
  → GameManager.register_accusation(sospechoso, evidencias, correcto)
  → GameManager.export_session_json()
  → Cargador de Escena: carga escena final
```

---

### Ruta de Exportación de Sesión

Se activa en dos condiciones (lo que ocurra primero):
1. `case_resolved()` emitido por Acusación/Final
2. `SceneTree.quit()` — el jugador cierra el juego

```
GameManager.export_session_json()
  → Construye Dictionary con todos los campos de telemetría
  → FileAccess.open("user://sesion_{session_id}_{timestamp}.json", WRITE)
  → JSON.stringify(datos) → escribe archivo
  → FileAccess.close()
```

---

### Orden de Inicialización

```
1. Godot arranca → Autoload: GameManager (singleton, primero)
2. Cargador de Escena carga main_menu.tscn
3. Menú principal: jugador ingresa session_id (ID participante) + selecciona nivel de inglés
   → GameManager almacena ambos valores
4. Menú principal: BackendLauncher.launch_backend() → OS.create_process("python3"|"python", [...])
   → Spinner "Iniciando sistema de IA..." por 2s
   → Health check GET /health con hasta 3 reintentos
   → Si falla → panel de error con instrucciones manuales → "Iniciar" deshabilitado
   → Si 200 OK → "Iniciar partida" habilitado
   (Ver ADR-0003 para detalles de lifecycle y soporte Linux/Windows)
5. Jugador inicia → Cargador de Escena carga el_agave_y_la_luna.tscn
6. Escena lista:
   a. Controlador Jugador inicializa CharacterBody3D + Camera3D
   b. Sistema Interacción registra todos los Area3D de la escena
   c. Diálogo NPC inicializa historial vacío por NPC (con modificador de nivel en prompt de sistema)
   d. Anti-Estancamiento inicia Temporizador L1 (4 min)
   e. HUD conecta señales de Diálogo NPC, Gajito, Voz/PTT
   f. GameManager.session_start_time = Time.get_unix_time_from_system()
7. Comisario Spud dispara briefing tutorial automáticamente
```

**Restricción crítica:** el backend FastAPI debe estar corriendo antes de que el jugador pueda iniciar. El juego lo verifica en el menú principal — no se asume disponible.

---

## Contratos de API

### GameManager (Autoload)

```gdscript
var english_level: String          # "beginner" | "intermediate" | "advanced"
var session_id: String
var clues: Dictionary              # { clue_id: { state, timestamp } }
var npcs_interrogated: Dictionary
var accusation_attempts: Array          # Array[{suspect, evidence, correct, timestamp}]
var grammar_errors_count: int
var anti_stall_triggers: Dictionary     # {"L1": int, "L2": int, "L3": int}
var completed: bool
var correct_accusation: bool
var session_start_time: float

func add_clue(clue_id: String) -> void
func set_clue_state(clue_id: String, state: String) -> void  # "good"|"not_good"|"unchecked"
func get_clue_state(clue_id: String) -> String
func is_confession_gate_open() -> bool
func register_interrogation(npc_id: String) -> void
func register_grammar_error() -> void
func register_accusation(suspect: String, evidence: Array, correct: bool) -> void
func export_session_json() -> void

signal clue_added(clue_id: String)
signal clue_state_changed(clue_id: String, state: String)
signal gate_opened()
```

**Invariante:** ningún módulo modifica `clues` directamente — solo a través de los métodos públicos.

---

### Cliente LLM

```gdscript
var base_url: String = "http://localhost:8000"
var timeout_sec: float = 8.0

func send_npc_request(npc_id: String, history: Array, player_text: String) -> void
func send_grammar_check(player_text: String) -> void
func check_backend_health() -> bool

signal npc_response_received(npc_id: String, response_text: String)
signal grammar_response_received(has_error: bool, correction: String)
signal backend_offline()
signal request_timeout(request_type: String)
```

**Garantía:** nunca lanza excepción — errores y timeouts siempre se emiten como señal.

---

### Voz/PTT

```gdscript
func start_recording() -> void
func stop_recording() -> void

signal recording_started()
signal recording_stopped()
signal audio_captured(wav_bytes: PackedByteArray)
```

---

### Diálogo NPC

```gdscript
var npc_id: String
var conversation_history: Array

func start_dialogue() -> void
func receive_player_audio(wav_bytes: PackedByteArray) -> void
func add_testimony_clue(clue_id: String) -> void

signal npc_response_ready(npc_id: String, text: String)
signal babble_trigger(npc_id: String)
signal testimony_prompt_shown(clue_id: String)
```

---

### Sistema de Interacción

```gdscript
func register_interactable(node: Node3D, type: String) -> void

signal clue_picked(clue_id: String)
signal npc_context_opened(npc_id: String)
signal inspect_opened(object_id: String)
```

---

### Evidencias/Inventario

```gdscript
const MAX_SLOTS: int = 8

func get_inventory() -> Array      # Array de { id, type, state, label }
func get_clue(clue_id: String) -> Dictionary
func has_clue(clue_id: String) -> bool

signal inventory_changed()
```

**Garantía:** `get_inventory()` siempre retorna Array (vacío si no hay pistas). Nunca null.

---

### Formato JSON de Sesión

```json
{
  "session_id": "P01",
  "english_level": "intermediate",
  "duration_seconds": 847,
  "completed": true,
  "correct_accusation": true,
  "clues": {
    "F1": {"state": "good", "timestamp": 142.3},
    "F2": {"state": "good", "timestamp": 380.1},
    "F3": {"state": "good", "timestamp": 511.7},
    "F4": {"state": "not_good", "timestamp": 290.5},
    "F5": {"state": "unchecked", "timestamp": 0.0}
  },
  "npcs_interrogated": {
    "barry": 3, "moni": 2, "gerry": 1, "lola": 1, "spud": 1
  },
  "accusation_attempts": [
    {"suspect": "moni", "evidence": ["F3"], "correct": false, "timestamp": 601.2},
    {"suspect": "barry", "evidence": ["F1","F2","F3"], "correct": true, "timestamp": 847.0}
  ],
  "grammar_errors_count": 7,
  "anti_stall_triggers": {"L1": 1, "L2": 0, "L3": 0}
}
```

---

## Auditoría de Decisiones Arquitectónicas

No existen decisiones arquitectónicas (ADRs) previas. Cobertura: 0/27 requisitos cubiertos por ADRs formales antes de esta sesión.

Esta sesión de arquitectura cubre los 27 requisitos técnicos con decisiones documentadas en este blueprint.

---

## Decisiones Arquitectónicas

ADR-0001..ADR-0016 aprobados. Ver índice completo en `docs/architecture/traceability-index.md`.

| ADR | Título | Capa |
|-----|--------|------|
| ADR-0001 | GameManager singleton autoload | Foundation |
| ADR-0002 | LLM Ollama exclusivo | Foundation |
| ADR-0003 | Backend FastAPI proceso separado | Foundation |
| ADR-0004 | PTT AudioEffectCapture WAV | Core |
| ADR-0005 | Arquitectura de señales entre capas | Foundation |
| ADR-0006 | Condicionamiento por nivel de inglés | Feature |
| ADR-0007 | Telemetría de sesión JSON | Foundation |
| ADR-0008 | Puerta de confesión Barry | Feature |
| ADR-0009 | Balbuceo NPC | Presentation |
| ADR-0010 | Tablón diegético evidencias | Presentation |
| ADR-0011 | Sistema anti-stall L1/L2/L3 | Feature |
| ADR-0012 | Player Controller FPS | Core |
| ADR-0013 | Interaction System | Core |
| ADR-0014 | NPC Dialogue Module | Feature |
| ADR-0015 | Inventory Module | Feature |
| ADR-0016 | Gajito Module | Feature |

**Pendiente:** ADR-0017 HUD System (TR-ui-001 parcial, TR-ui-002 gap).

---

## Principios de Arquitectura

1. **GameManager es la única fuente de verdad.** Ningún módulo mantiene estado de juego duplicado. Todo se consulta y modifica a través de GameManager.

2. **Las capas solo dependen hacia abajo.** Fundación nunca importa de Características/Núcleo. Presentación nunca llama métodos de Núcleo directamente. Cualquier violación de esta regla es un error de arquitectura.

3. **Los errores del backend nunca bloquean el juego.** El Cliente LLM siempre emite señales para errores y timeouts. El juego degrada de forma controlada (texto de marcador, indicador visual).

4. **El backend es un contrato, no una implementación.** El juego solo habla con FastAPI en localhost. Cambiar Ollama por GPT-4o-mini no requiere cambios en el código Godot — solo configuración del backend.

5. **La telemetría es pasiva.** GameManager registra eventos como efecto secundario de las operaciones normales del juego. Ningún sistema de juego llama explícitamente al registrador — solo GameManager lo hace internamente.

---

## Preguntas Abiertas

| N° | Pregunta | Bloquea |
|----|----------|---------|
| PA-001 | ~~¿Versión exacta de Godot 4?~~ → **Resuelto: Godot 4.6** | ✅ |
| PA-002 | ¿Puerto de FastAPI? (8000 por defecto) — ¿configurable en opciones o fijo en código? | ADR-003 |
| PA-003 | ¿El nivel "Avanzado" activa expresiones idiomáticas en todos los NPCs o solo en algunos? | ADR-006 |
| PA-004 | ¿Balbuceo de NPC: clips pre-grabados (Sofía los graba) o síntesis procedural en Godot? | ADR-009 |
| PA-005 | ¿Mockups de UI ya definidos? La sección 8.3 del GDD está pendiente | No bloquea arquitectura |
