# ADR-0016: Módulo Gajito (Gajito Module)

## Estado
Propuesto

## Date
2026-05-01

## Engine Compatibility

| Campo | Valor |
|-------|-------|
| **Motor** | Godot 4 |
| **Dominio** | Feature / AI / UI |
| **Riesgo de Conocimiento** | LOW — HTTPRequest, Timer y CanvasLayer son APIs estables; lógica gramatical en Python/backend |
| **Referencias Consultadas** | ADR-0001 (register_grammar_error), ADR-0003 (POST /grammar), ADR-0004 (audio_captured), ADR-0011 (anti_stall_triggered), ADR-0014 (texto jugador), TR-gajito-001/002 |
| **APIs Post-Cutoff Usadas** | Ninguna |
| **Verificación Requerida** | Paralelismo real entre POST /npc y POST /grammar — verificar que HTTPRequest de Godot no bloquea; pop-up visible sobre tablón diegético y sobre HUD de subtítulos |

## ADR Dependencies

| Campo | Valor |
|-------|-------|
| **Depende De** | ADR-0001 (register_grammar_error — telemetría); ADR-0003 (POST /grammar endpoint); ADR-0004 (audio_captured — obtiene el texto STT del jugador); ADR-0011 (anti_stall_triggered — Gajito también muestra hints) |
| **Habilita** | ADR-0017 HUD System (el pop-up de Gajito es un elemento del HUD que ADR-0017 debe coordinar) |
| **Bloquea** | Epic "Corrección Gramatical Gajito" |
| **Nota de Orden** | GajitoModule debe estar en Autoload. Necesita que VoiceManager (ADR-0004) emita `player_text_ready` antes de poder enviar la petición |

---

## Contexto

### Problema
No existe un ADR que documente cómo Gajito lanza la evaluación gramatical en paralelo a la respuesta NPC, cómo muestra el pop-up de corrección en español, cuándo lo descarta automáticamente, ni cómo acumula errores en telemetría. Gajito también es el canal para los hints del anti-stall (ADR-0011) — ambas responsabilidades deben coexistir en el mismo módulo sin colisión de pop-ups.

### Restricciones
- La evaluación gramatical es **no-bloqueante** — el jugador no espera a Gajito para que el NPC responda (TR-gajito-002). Las dos peticiones HTTP van en paralelo.
- `GameManager.register_grammar_error()` es el único punto de escritura de conteo de errores (ADR-0001).
- El texto del jugador llega desde VoiceManager vía STT (ADR-0004) — GajitoModule no captura audio directamente.
- Pop-up en español, esquina inferior izquierda. Auto-dismiss a los 5 s.
- El GDD especifica que Gajito corrige solo errores **graves** — el backend decide si hay error (responde con `has_error: bool`). Godot no evalúa gramática localmente.
- Si Gajito está mostrando un hint de anti-stall y llega una corrección, la corrección tiene prioridad.
- `stt_latency_budget = 4 s` (CLAUDE.md) — la petición /grammar se lanza inmediatamente tras recibir el texto STT, dentro de ese budget.

### Requisitos
- Recibir texto del jugador (post-STT) y enviarlo a `POST /grammar` con contexto NPC activo
- Respuesta del backend: `{has_error: bool, correction: String}` — mostrar pop-up solo si `has_error == true`
- Pop-up auto-dismiss a 5 s; si llega corrección mientras hay hint de anti-stall, reemplazar inmediatamente
- `GameManager.register_grammar_error()` en cada `has_error == true`
- Mostrar hints de anti-stall (`anti_stall_triggered`) en el mismo pop-up, con texto predefinido por nivel
- Sin bloqueo del movimiento ni del flujo de diálogo — pop-up es solo informativo

---

## Decisión

`GajitoModule` es un autoload en Feature layer. Conecta dos fuentes de entrada:
1. `VoiceManager.player_text_ready(text, npc_id)` — lanza `POST /grammar` en paralelo a la petición NPC.
2. `GameManager.anti_stall_triggered(level)` — muestra hint predefinido en el pop-up.

El pop-up es un `CanvasLayer` (`gajito_popup.tscn`) con un `PanelContainer` + `RichTextLabel`, posicionado en esquina inferior izquierda. Un `Timer` one-shot de 5 s controla el auto-dismiss. Si llega nueva corrección antes de que expire el timer, el contenido se reemplaza y el timer se reinicia.

La petición `POST /grammar` usa `LLMClient` (ADR-0003) o su propia instancia de `HTTPRequest` — dado que el LLMClient de ADR-0003 puede estar ocupado con la petición NPC simultánea, GajitoModule usa su **propia instancia HTTPRequest** independiente.

### Diagrama de Arquitectura

```
VoiceManager.player_text_ready(text, npc_id)
  └─► GajitoModule._on_player_text(text, npc_id)
        ├── POST /grammar  {text, npc_id, english_level}
        │     ├── OK {has_error: false} → ignorar (sin pop-up)
        │     └── OK {has_error: true, correction: "..."} →
        │             GameManager.register_grammar_error()
        │             GajitoPopup.show(correction)   ← reemplaza hint si está visible
        └── (simultáneo, no espera) NPC request continúa en NPCDialogueManager

GameManager.anti_stall_triggered(level)
  └─► GajitoModule._on_stall_hint(level)
        └── GajitoPopup.show(HINT_TEXTS[level])  ← baja prioridad vs corrección

GajitoPopup (CanvasLayer — layer 15, sobre todo)
  ├── PanelContainer (esquina inf. izq.)
  │   └── RichTextLabel (texto corrección o hint)
  └── Timer (one-shot, 5 s) → auto-dismiss
        └── Si show() llega antes de expirar → stop() + start(5.0) + update texto
```

### Interfaces Clave

```gdscript
# res://scripts/feature/gajito_module.gd
extends Node  # Autoload — Feature layer

# ── Constantes ────────────────────────────────────────────────────────────────
const GRAMMAR_ENDPOINT: String = "/grammar"
const POPUP_DURATION: float = 5.0

const HINT_TEXTS: Dictionary = {
    "L1": "Limonchero, ¿has revisado todos los rincones del local? Hay más pistas esperándote.",
    "L2": "Quizás vale la pena hablar con alguien que aún no hayas interrogado del todo...",
    "L3": "El cenicero junto a la barra tiene algo interesante. Y no olvides el guardarropa."
}

# ── Nodos ─────────────────────────────────────────────────────────────────────
@onready var _http: HTTPRequest = $HTTPRequest  # instancia propia — no comparte con NPCDialogueManager
@onready var _popup: CanvasLayer = $GajitoPopup
@onready var _label: RichTextLabel = $GajitoPopup/Panel/RichTextLabel
@onready var _timer: Timer = $GajitoPopup/DismissTimer

# ── Estado privado ────────────────────────────────────────────────────────────
var _pending_correction: bool = false

# ── Señales ───────────────────────────────────────────────────────────────────
signal grammar_correction_shown(correction: String)   # para tests / integración futura

# ── API pública ───────────────────────────────────────────────────────────────
func _ready() -> void:
    # Conectar fuentes de entrada
    VoiceManager.player_text_ready.connect(_on_player_text)
    GameManager.anti_stall_triggered.connect(_on_stall_hint)
    _http.request_completed.connect(_on_grammar_response)
    _popup.visible = false

func _on_player_text(text: String, npc_id: String) -> void:
    var body := JSON.stringify({
        "text": text,
        "npc_id": npc_id,
        "english_level": GameManager.english_level
    })
    _http.request("http://localhost:8000" + GRAMMAR_ENDPOINT,
                  ["Content-Type: application/json"],
                  HTTPClient.METHOD_POST, body)

func _on_grammar_response(_result, _code, _headers, body: PackedByteArray) -> void:
    var json := JSON.parse_string(body.get_string_from_utf8())
    if json == null or not json.get("has_error", false):
        return
    GameManager.register_grammar_error()
    _show_popup(json["correction"])
    grammar_correction_shown.emit(json["correction"])

func _on_stall_hint(level: String) -> void:
    if _pending_correction:
        return  # corrección activa tiene prioridad — hint se descarta
    _show_popup(HINT_TEXTS[level])

func _show_popup(text: String) -> void:
    _label.text = text
    _popup.visible = true
    _pending_correction = true
    _timer.stop()
    _timer.start(POPUP_DURATION)

func _on_dismiss_timer_timeout() -> void:
    _popup.visible = false
    _pending_correction = false
```

### Flujo de Prioridad Pop-up

| Situación | Resultado |
|-----------|-----------|
| Anti-stall L1 llega, pop-up vacío | Muestra hint L1 |
| Corrección llega mientras hint visible | Reemplaza hint, reinicia timer 5 s |
| Anti-stall L2 llega mientras corrección visible | **Descartado** — corrección tiene prioridad |
| Anti-stall L3 llega mientras corrección visible | **Descartado** — corrección tiene prioridad |
| Corrección llega mientras pop-up vacío | Muestra corrección, inicia timer 5 s |

---

## Alternativas Consideradas

### Alternativa A: Evaluación gramatical integrada en respuesta NPC (una sola petición)
- **Descripción**: Backend retorna en `/npc/{id}` tanto la respuesta del NPC como la corrección gramatical en un solo JSON.
- **Pros**: Una sola petición HTTP por turno. Más simple.
- **Contras**: La corrección debe esperar a que el NPC procese — puede tardar hasta 8 s. El GDD dice explícitamente que la corrección es inmediata ("interviene de inmediato"). Además acopla lógica de dos sistemas distintos en un endpoint.
- **Razón de Rechazo**: Viola TR-gajito-002 (paralelo, no-bloqueante). La corrección pierde su valor pedagógico si llega 8 s tarde.

### Alternativa B: Gajito como script en el nodo HUD
- **Descripción**: La lógica de Gajito vive en `hud.gd` como parte del HUD general (ADR-0017).
- **Pros**: Un archivo menos; el HUD ya gestiona el pop-up visualmente.
- **Contras**: Mezcla lógica de negocio (evaluación LLM, telemetría) con presentación (HUD). Dificulta tests unitarios de la lógica de corrección. Viola separación Feature/Presentation.
- **Razón de Rechazo**: GajitoModule tiene responsabilidades de Feature layer (petición HTTP, telemetría, lógica de prioridad). Debe estar separado del HUD de Presentation layer.

---

## Consecuencias

### Positivas
- `HTTPRequest` propio de GajitoModule garantiza paralelismo real con la petición NPC — sin contención.
- Lógica de prioridad pop-up centralizada en `_show_popup()` — una sola función gestiona ambas fuentes.
- Auto-dismiss via Timer Godot nativo — sin corutinas, sin polling.
- El backend decide si hay error grave — Godot no tiene lógica gramatical hardcodeada.

### Negativas
- Una instancia `HTTPRequest` adicional. Aceptado — Godot maneja múltiples instancias sin problema.
- `_pending_correction = true` previene mostrar hints anti-stall mientras hay corrección activa — un hint de L3 podría perderse si el jugador comete un error justo en ese momento. Aceptado: la corrección es más urgente pedagógicamente.

### Riesgos
- **Riesgo**: Backend /grammar no responde — petición queda pendiente. Si el jugador envía un nuevo mensaje antes de que la primera petición complete, `_http.request()` falla con `ERR_IN_USE`. **Mitigación**: Cancelar petición anterior con `_http.cancel_request()` antes de lanzar la nueva. La corrección del turno anterior se descarta.
- **Riesgo**: `player_text_ready` se emite con texto vacío (jugador no habló pero PTT se activó). **Mitigación**: VoiceManager no emite si `len(text.strip_edges()) == 0`. Verificar en ADR-0004.
- **Riesgo**: Pop-up visible durante árbol de acusación — interfiere con la UI de acusación. **Mitigación**: `GajitoModule` conecta `NPCDialogueManager.accusation_started` → `_popup.visible = false` + `_timer.stop()`.

---

## Requisitos GDD Abordados

| Sistema GDD | Requisito | Cómo lo aborda este ADR |
|-------------|-----------|------------------------|
| gdd_detective_noir_vr.md / TR-gajito-001 | Grammar evaluator: texto jugador → LLM → corrección española en pop-up | POST /grammar en paralelo; pop-up CanvasLayer esquina inf. izq.; auto-dismiss 5 s |
| gdd_detective_noir_vr.md / TR-gajito-002 | Evaluación gramatical paralela a respuesta NPC (no-bloqueante) | HTTPRequest propio de GajitoModule — no comparte con NPCDialogueManager |
| gdd_detective_noir_vr.md / RF-05 | Gajito evalúa inglés y corrige errores graves en español vía pop-up | `has_error: true` del backend → pop-up español + register_grammar_error() |
| CLAUDE.md / stt_latency_budget | 4 s end-to-end STT→LLM | POST /grammar lanzado inmediatamente en player_text_ready — dentro del budget |

---

## Implicaciones de Rendimiento
- **CPU**: Una petición HTTP async por turno de interrogatorio. Sin impacto en hilo principal.
- **Memoria**: Una instancia HTTPRequest + CanvasLayer ligero. < 1 KB de datos de estado.
- **Tiempo de Carga**: Ninguno — GajitoModule inicializa con popup oculto.
- **Red**: POST /grammar a localhost:8000 — tráfico local, negligible.

---

## Plan de Migración
ADR nuevo — no hay código existente que migrar.

Integración:
1. Añadir `GajitoModule` a Project Settings → Autoload (después de GameManager, después de NPCDialogueManager).
2. `VoiceManager` (ADR-0004) debe emitir señal `player_text_ready(text: String, npc_id: String)` — añadir si no existe.
3. Backend FastAPI ya tiene endpoint `/grammar` (ADR-0003) — verificar que retorna `{has_error, correction}`.
4. Conectar `NPCDialogueManager.accusation_started` → `GajitoModule._on_accusation_started()` para ocultar pop-up.

---

## Criterios de Validación
- Enviar "I goed to the bar" vía PTT: pop-up aparece con corrección en español en < 8 s, desaparece a los 5 s.
- Enviar frase correcta: no aparece pop-up.
- `GameManager.grammar_errors_count` incrementa exactamente en los turnos con error.
- Después de 4 min sin evidencia, hint L1 aparece en pop-up Gajito.
- Si corrección llega mientras se muestra hint L1, corrección la reemplaza inmediatamente.
- Durante árbol de acusación, pop-up de Gajito no es visible.
- Dos mensajes consecutivos en < 2 s: segunda petición cancela la primera (sin crash).

---

## Decisiones Relacionadas
- [ADR-0001](adr-0001-gamemanager-singleton.md) — register_grammar_error() para telemetría
- [ADR-0003](adr-0003-backend-fastapi-proceso-separado.md) — POST /grammar endpoint
- [ADR-0004](adr-0004-ptt-audiocapture-wav.md) — VoiceManager.player_text_ready como fuente de texto
- [ADR-0011](adr-0011-anti-stall-system.md) — anti_stall_triggered conecta a GajitoModule para hints
- [ADR-0014](adr-0014-npc-dialogue-module.md) — accusation_started para ocultar pop-up durante acusación
- [ADR-0017](adr-0017-hud-system.md) — HUD coordina visibilidad con GajitoPopup CanvasLayer
