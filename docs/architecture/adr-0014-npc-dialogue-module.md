# ADR-0014: Módulo de Diálogo NPC (NPC Dialogue Module)

## Estado
Propuesto

## Date
2026-05-01

## Engine Compatibility

| Campo | Valor |
|-------|-------|
| **Motor** | Godot 4 |
| **Dominio** | Feature / AI |
| **Riesgo de Conocimiento** | LOW — HTTPRequest y señales son APIs estables; la lógica LLM es en Python/backend |
| **Referencias Consultadas** | ADR-0001 (register_interrogation/accusation), ADR-0002 (Ollama), ADR-0003 (POST /npc/{id}), ADR-0006 (english_level), ADR-0008 (puerta confesión), ADR-0009 (balbuceo), ADR-0010 (tablón diegético), ADR-0013 (npc_menu_requested), TR-npc-001, TR-acus-001/002 |
| **APIs Post-Cutoff Usadas** | Ninguna |
| **Verificación Requerida** | Timeout de 8 s en build exportado Linux/Windows; historial no se corrompe si el jugador interrumpe una petición; árbol de acusación no puede abrirse si la sesión no está inicializada |

## ADR Dependencies

| Campo | Valor |
|-------|-------|
| **Depende De** | ADR-0001 (register_interrogation, register_accusation, english_level); ADR-0002 (Ollama como LLM); ADR-0003 (POST /npc/{id} y timeout); ADR-0006 (condicionamiento por nivel inglés); ADR-0008 (is_confession_gate_open); ADR-0013 (npc_menu_requested dispara este módulo) |
| **Habilita** | ADR-0016 Gajito Module (Gajito recibe el texto del jugador en paralelo al NPC); ADR-0017 HUD System (subtítulos de NPC y jugador, indicador PTT) |
| **Bloquea** | Epic "Interrogatorio NPC" — no puede implementarse sin este ADR |
| **Nota de Orden** | NPCDialogueManager debe estar en Autoload antes de que el nivel cargue cualquier NPC |

---

## Contexto

### Problema
No existe un ADR que documente dónde vive el historial de conversación por NPC, cómo se ensambla el prompt que recibe el backend, cómo se gestiona el timeout de 8 s, ni cómo funciona el árbol de acusación con Commissioner Spud. Sin esta decisión, la integración LLM y el flujo crítico de acusación no tienen contrato implementable.

### Restricciones
- 5 NPCs con system prompts únicos (definidos en cast-bible.md); el historial por NPC debe persistir durante toda la sesión.
- Timeout LLM: 8 segundos (CLAUDE.md). Pasado ese tiempo → respuesta de fallback.
- `english_level` del jugador condiciona el system prompt vía sufijo en backend (ADR-0006) — no se modifica aquí, se envía como campo en el JSON del request.
- Toda telemetría de interrogatorio/acusación va a GameManager (ADR-0001) — no a NPCDialogueManager.
- El árbol de acusación con Spud es **lógica scripted**, no LLM — el caso ya tiene culpable hardcodeado (ADR-0008).
- La confesión solo se desbloquea cuando `GameManager.is_confession_gate_open()` retorna true.
- Max historial: 10 turnos por NPC (20 mensajes = 10 user + 10 assistant) para no exceder el contexto de Ollama.

### Requisitos
- `NPCDialogueManager` autoload gestiona `_histories: Dictionary` keyed by npc_id
- Al recibir `npc_menu_requested(npc_id)` de ADR-0013 → abrir panel de diálogo o árbol de acusación
- Enviar petición `POST /npc/{npc_id}` con `{message, history, english_level}` vía LLMClient (ADR-0003)
- Timeout 8 s → emitir `npc_response_ready(npc_id, fallback_text)` con texto predefinido
- Al recibir respuesta → emitir `npc_response_ready(npc_id, response_text)`
- Detectar claves de testimonio en el texto NPC → emitir `testimony_available(clue_id)` para prompt "¿Agregar como evidencia?"
- Árbol de acusación (solo Spud): selección de hasta 3 pistas + nombre del sospechoso → validar puerta → case_resolved o case_failed
- Registrar cada interrogatorio en `GameManager.register_interrogation(npc_id)`
- Registrar cada intento de acusación en `GameManager.register_accusation(suspect, evidence, correct)`

---

## Decisión

`NPCDialogueManager` es un autoload en Foundation layer. Gestiona el historial de conversación de los 5 NPCs y enruta peticiones al backend vía `LLMClient` (autoload de ADR-0003). Para Commissioner Spud, detecta cuándo el jugador activa la acusación y abre un árbol de diálogo scripted en lugar de llamar al LLM.

El flujo de testimonio ("¿Agregar como evidencia?") se activa cuando el backend retorna un flag `testimony_clue_id` en la respuesta JSON — el backend detecta palabras clave en su propia respuesta y lo inyecta. Si no hay flag, `NPCDialogueManager` también mantiene un diccionario local de `TESTIMONY_TRIGGERS` por npc_id que hace matching simple sobre el texto de respuesta como fallback.

### Diagrama de Arquitectura

```
ADR-0013 InteractionSystem
  └── emite npc_menu_requested(npc_id)
        │
        ▼
NPCDialogueManager (autoload)
  ├── Si npc_id == "spud" y jugador elige "Acusar" → AccusationTree
  │     ├── Mostrar UI selección de pistas (hasta 3)
  │     ├── Mostrar campo nombre sospechoso
  │     ├── GameManager.is_confession_gate_open() ?
  │     │     ├── true  → GameManager emite case_resolved()
  │     │     └── false → GameManager emite case_failed("wrong_suspect"/"missing_evidence")
  │     └── GameManager.register_accusation(suspect, evidence, correct)
  │
  └── Si NPC regular → InterrogationFlow
        ├── Ensamblar request: {message: text, history: _histories[npc_id], english_level: GM.english_level}
        ├── LLMClient.request_npc_response(npc_id, request_body)
        │     ├── Timeout 8 s → npc_response_ready(npc_id, FALLBACK_TEXTS[npc_id])
        │     └── OK → npc_response_ready(npc_id, response.text)
        ├── Actualizar _histories[npc_id] (append user + assistant turn)
        ├── Si response.testimony_clue_id → emitir testimony_available(clue_id)
        └── GameManager.register_interrogation(npc_id)

Consumidores de npc_response_ready:
  ├── ADR-0010 (tablón diegético) → mostrar texto en Sprite3D
  ├── ADR-0009 (balbuceo) → detener audio
  └── ADR-0017 (HUD) → canal subtítulo NPC

testimony_available(clue_id) → UI prompt "¿Agregar como evidencia? [E]"
  └── Confirmado → GameManager.add_clue(clue_id)
```

### Interfaces Clave

```gdscript
# res://scripts/feature/npc_dialogue_manager.gd
extends Node  # Autoload — Foundation layer

# ── Constantes ────────────────────────────────────────────────────────────────
const MAX_HISTORY_TURNS: int = 10       # 10 turnos = 20 mensajes
const LLM_TIMEOUT_SEC: float = 8.0

# Textos de fallback si LLM no responde (uno por NPC)
const FALLBACK_TEXTS: Dictionary = {
    "spud":  "...",                                        # Spud espera
    "lola":  "I need a moment, detective.",
    "moni":  "Ask me later, darling.",
    "gerry": "Give me a second.",
    "barry": "I'm thinking."
}

# Claves de testimonio por NPC (fallback si backend no envía testimony_clue_id)
const TESTIMONY_TRIGGERS: Dictionary = {
    "moni":  [
        {"keywords": ["yellow", "golden coat", "yellowish", "upstairs", "someone went up"], "clue_id": "T2"},
        {"keywords": ["lighter", "gold lighter", "left something", "shiny", "his things"], "clue_id": "F3"}
    ],
    "gerry": [{"keywords": ["back door", "22 minutes", "left my post"], "clue_id": "T3"}]
}

# ── Estado privado ────────────────────────────────────────────────────────────
var _histories: Dictionary = {}         # {npc_id: Array[{role, content}]}
var _pending_npc_id: String = ""        # NPC con petición en vuelo
var _accusation_open: bool = false      # árbol de acusación activo

# ── Señales ───────────────────────────────────────────────────────────────────
signal npc_response_ready(npc_id: String, text: String)
signal testimony_available(clue_id: String)
signal accusation_started()
signal accusation_result(correct: bool, reason: String)

# ── API pública ───────────────────────────────────────────────────────────────
func start_interrogation(npc_id: String, player_message: String) -> void
    # Registra turno, arma request, llama LLMClient, inicia timer timeout

func open_accusation_tree() -> void
    # Solo válido si npc_id == "spud"; ignorado si _accusation_open == true

func submit_accusation(suspect: String, evidence: Array) -> void
    # Evalúa puerta, emite accusation_result, llama GameManager.register_accusation()

func get_history(npc_id: String) -> Array
    # Retorna copia de _histories[npc_id], o [] si no existe

func clear_history(npc_id: String) -> void
    # No llamar en sesión normal — solo para tests
```

### Árbol de Acusación (Commissioner Spud — scripted)

```
AccusationTree (escena CanvasLayer)
  1. Muestra inventario de pistas disponibles (clue_id + label)
  2. Jugador selecciona hasta 3 pistas (checkboxes)
  3. Jugador escribe o selecciona nombre del sospechoso
  4. Jugador confirma con botón "Acusar"
  5. NPCDialogueManager.submit_accusation(suspect, [clue_ids])
     └── GameManager.is_confession_gate_open() ?
           YES → GameManager emite case_resolved()
           NO  → reason = "wrong_suspect" si suspect != "barry"
                        = "missing_evidence" si F1/F2/F3 no todos GOOD
                 accusation_result(false, reason) → pantalla de fallo
  6. accusation_attempts en telemetría: máximo indefinido, pero case_failed es irreversible
     (GDD: una sola acusación incorrecta termina el caso)
```

---

## Alternativas Consideradas

### Alternativa A: Historial por nodo NPC en la escena del nivel
- **Descripción**: Cada NPC en `el_agave_y_la_luna.tscn` guarda su historial como variable local en su propio script.
- **Pros**: Cada NPC es autocontenido; más fácil de depurar de forma aislada.
- **Contras**: El historial se destruye si el nivel se recarga (aunque en este juego solo hay un nivel, es un riesgo en desarrollo/test). Requiere que `InteractionSystem` acceda al nodo NPC para iniciar la petición, lo que acopla dos capas distintas.
- **Razón de Rechazo**: Un autoload centralizado aísla la lógica LLM del grafo de escena y sobrevive a cualquier recarga durante desarrollo. Más consistente con el patrón Foundation de ADR-0001.

### Alternativa B: Ampliar GameManager para gestionar el historial
- **Descripción**: Añadir `_histories` a GameManager junto con la demás telemetría.
- **Pros**: Un singleton menos; historial disponible para la exportación de sesión.
- **Contras**: GameManager ya gestiona clues, telemetría, anti-stall y la puerta de confesión. Añadir lógica de conversación LLM supera su responsabilidad definida en ADR-0001. El historial de conversación no es telemetría — es estado operacional efímero.
- **Razón de Rechazo**: Viola el principio de responsabilidad única de GameManager tal como lo define ADR-0001.

---

## Consecuencias

### Positivas
- Historial de conversación centralizado y persistente durante toda la sesión.
- El árbol de acusación es scripted — no depende del LLM, sin riesgo de respuesta inesperada en el momento crítico del juego.
- `testimony_available` desacopla la detección de testimonio de la UI — el sistema de interacción (ADR-0013) o el HUD (ADR-0017) puede conectarse sin modificar este módulo.
- Fallback de 8 s garantiza que el juego nunca se cuelga esperando al LLM.

### Negativas
- Un autoload más en Foundation layer. Aceptado — la lógica LLM justifica separación de GameManager.
- `TESTIMONY_TRIGGERS` hardcodeado en GDScript. Si el diseño narrativo cambia los testimonios, hay que editar el código. Mitigable extrayendo a un JSON de configuración en iteraciones posteriores.
- La detección de testimonio vía palabras clave es frágil si el LLM parafrasea. El flag `testimony_clue_id` del backend es más robusto pero requiere lógica en Python.

### Riesgos
- **Riesgo**: `_pending_npc_id` no se limpia si el HTTPRequest falla sin timeout. **Mitigación**: `LLMClient` siempre emite señal (response o timeout) — nunca silencia errores. Conectar también a `request_failed` de HTTPRequest.
- **Riesgo**: Jugador abre acusación con Spud antes de tener F1+F2+F3. `case_failed` es irreversible. **Mitigación**: Esto es por diseño del GDD. AccusationTree puede mostrar un aviso visual "Evidencia incompleta" antes de confirmar, sin bloquear la acción — el jugador elige.
- **Riesgo**: Historial crece más de MAX_HISTORY_TURNS si el jugador interroga extensamente. **Mitigación**: `start_interrogation()` trunca `_histories[npc_id]` al insertar si `len > MAX_HISTORY_TURNS * 2` — elimina los dos mensajes más antiguos (mantiene system context implícito en el backend).
- **Riesgo**: `TESTIMONY_TRIGGERS` matching produce falsos positivos en respuestas LLM creativas. **Mitigación**: Priorizar el flag `testimony_clue_id` del backend; el matching local es solo fallback. Ajustar keywords en playtest.

---

## Requisitos GDD Abordados

| Sistema GDD | Requisito | Cómo lo aborda este ADR |
|-------------|-----------|------------------------|
| gdd_detective_noir_vr.md / TR-npc-001 | 5 NPCs con system prompts únicos e historial de conversación por sesión | `_histories[npc_id]` en NPCDialogueManager; system prompts definidos en backend (no en Godot) |
| gdd_detective_noir_vr.md / TR-acus-001 | Árbol de diálogo con Commissioner Spud, hasta 3 pistas presentadas | `AccusationTree` scripted — `submit_accusation(suspect, evidence[0..3])` |
| gdd_detective_noir_vr.md / TR-acus-002 | Puerta de confesión: F1+F2+F3 GOOD + Barry Peel nombrado | `GameManager.is_confession_gate_open()` llamado en `submit_accusation()` (ADR-0008) |
| gdd_detective_noir_vr.md / TR-interact-003 | Prompt "¿Agregar como evidencia?" durante diálogo NPC | Señal `testimony_available(clue_id)` → UI overlay → `GameManager.add_clue(clue_id)` |
| CLAUDE.md / llm_timeout | 8 segundos por respuesta NPC | `LLM_TIMEOUT_SEC = 8.0`; timer en `start_interrogation()` emite fallback si se agota |

---

## Implicaciones de Rendimiento
- **CPU**: Una petición HTTP async por turno de interrogatorio — no bloquea el hilo principal. Sin impacto perceptible.
- **Memoria**: Máx. 5 NPCs × 20 mensajes × ~200 chars ≈ 20 KB de historial total. Negligible.
- **Tiempo de Carga**: Ninguno — NPCDialogueManager inicializa `_histories = {}` vacío.
- **Red**: Una petición `POST /npc/{id}` por turno. Tráfico local (localhost:8000). Sin impacto.

---

## Plan de Migración
ADR nuevo — no hay código existente que migrar.

Integración con ADRs existentes:
1. `NPCDialogueManager` añadido a Project Settings → Autoload (después de GameManager).
2. `InteractionSystem` (ADR-0013) conecta su señal `npc_menu_requested` a `NPCDialogueManager._on_npc_menu_requested`.
3. `LLMClient` (ADR-0003) recibe llamada `request_npc_response(npc_id, body)` — emite `npc_response_ready` o dispara timeout.
4. `DiálogoNPC` en el nivel conecta `npc_response_ready` al tablón diegético (ADR-0010) y al balbuceo (ADR-0009).
5. `AccusationTree` instanciado en `el_agave_y_la_luna.tscn` — oculto por defecto.

---

## Criterios de Validación
- Al interactuar con Lola y escribir un mensaje, `_histories["lola"]` crece en 2 entradas por turno.
- Al esperar 8 s sin respuesta del backend, `npc_response_ready` emite el texto de fallback.
- Con F1+F2+F3 GOOD y "barry" como acusado, `submit_accusation()` dispara `case_resolved`.
- Con cualquier otro sospechoso o evidencia incompleta, `submit_accusation()` dispara `case_failed`.
- `GameManager.npcs_interrogated["lola"]` incrementa en 1 por cada `start_interrogation("lola", ...)`.
- Con historial de 11 turnos, la llamada #12 trunca a 10 turnos antes de enviar.
- `testimony_available("T2")` se emite cuando Moni menciona "yellow" / "golden coat" / "yellowish" / "upstairs" / "someone went up".
- `testimony_available("T3")` se emite cuando Gerry menciona "back door" / "22 minutes" / "left my post".
- `testimony_available("F3")` se emite cuando Moni menciona "lighter" / "gold lighter" / "left something" / "shiny" / "his things" (o cuando backend retorna `testimony_clue_id: "F3"`).

---

## Decisiones Relacionadas
- [ADR-0001](adr-0001-gamemanager-singleton.md) — register_interrogation, register_accusation, is_confession_gate_open
- [ADR-0002](adr-0002-llm-ollama-exclusivo.md) — Ollama como proveedor LLM
- [ADR-0003](adr-0003-backend-fastapi-proceso-separado.md) — POST /npc/{id}, LLMClient autoload, timeout handling
- [ADR-0006](adr-0006-condicionamiento-nivel-ingles.md) — english_level en request body
- [ADR-0008](adr-0008-puerta-confesion.md) — is_confession_gate_open(), case_resolved, case_failed
- [ADR-0009](adr-0009-balbuceo-npc.md) — npc_response_ready detiene balbuceo
- [ADR-0010](adr-0010-tablon-diegetico.md) — npc_response_ready muestra texto en tablón
- [ADR-0013](adr-0013-interaction-system.md) — npc_menu_requested dispara este módulo
