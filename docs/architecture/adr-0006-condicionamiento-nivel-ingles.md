# ADR-0006: Condicionamiento por Nivel de Inglés — Modificación de System Prompts de NPCs

## Estado
Propuesto

## Fecha
2026-05-01

## Compatibilidad con el Motor

| Campo | Valor |
|-------|-------|
| **Motor** | Godot 4.6 (cliente) + Python 3.x / FastAPI (backend) |
| **Dominio** | Núcleo / Integración LLM |
| **Riesgo de Conocimiento** | BAJO — decisión independiente del motor; Godot solo transmite un String adicional |
| **Referencias Consultadas** | Conocimiento directo de Godot 4.6, FastAPI, Ollama API |
| **APIs Post-Corte Usadas** | Ninguna |
| **Verificación Requerida** | Confirmar que llama3.2 respeta el sufijo de nivel en 9/10 turnos de prueba por cada NPC |

## Dependencias ADR

| Campo | Valor |
|-------|-------|
| **Depende De** | ADR-0001 (GameManager almacena `english_level`), ADR-0002 (Ollama recibe el prompt modificado) |
| **Habilita** | Epic de interrogatorio — el nivel de inglés condiciona cada respuesta NPC |
| **Bloquea** | Ninguno específico |
| **Nota de Orden** | Implementar después de ADR-0001 y ADR-0002 |

## Contexto

### Declaración del Problema
El jugador elige su nivel de inglés (Beginner / Intermediate / Advanced) en el menú principal antes de iniciar la partida. Este nivel debe modificar la complejidad del inglés usado por todos los NPCs en cada respuesta LLM, sin requerir prompts completamente distintos por NPC y por nivel. Se necesita decidir cómo el nivel viaja desde GameManager hasta el system prompt de Ollama.

### Restricciones
- Godot 4.6 GDScript — sin tipado de enums nativos en señales (usar String)
- 3 niveles fijos: `"beginner"`, `"intermediate"`, `"advanced"`
- El nivel no cambia durante la partida — se fija al inicio de sesión
- Todos los NPCs aplican el mismo condicionamiento de nivel (OQ-003 resuelto: todos por igual)
- Ollama con llama3.2 — el modelo debe respetar instrucciones de registro en el system prompt

### Requisitos
- `english_level` disponible en GameManager antes de `initialize_session()`
- Nivel transmitido al backend en cada POST `/npc/{id}`
- Backend inyecta sufijo de nivel al system prompt base del NPC antes de llamar a Ollama
- Sufijo debe ser en inglés (es parte del prompt que lee el LLM)
- Cambiar los textos del sufijo no debe requerir modificar código Godot

## Decisión

**El nivel de inglés se transmite como campo `english_level` en el body del POST `/npc/{id}`. El backend FastAPI inyecta un sufijo estandarizado al system prompt base del NPC antes de enviar a Ollama. El sufijo se define en `backend/config.py`.**

### Sufijos por nivel

```python
# backend/config.py
ENGLISH_LEVEL_SUFFIXES = {
    "beginner": (
        "IMPORTANT — Language level: BEGINNER. "
        "Use only simple, common words. Short sentences (max 10 words). "
        "No idioms, no slang, no complex grammar. Speak slowly and clearly."
    ),
    "intermediate": (
        "Language level: INTERMEDIATE. "
        "Use everyday vocabulary. Moderate sentence length. "
        "Occasional idioms are acceptable if common."
    ),
    "advanced": (
        "Language level: ADVANCED. "
        "Speak naturally. Rich vocabulary, idioms, colloquialisms, and noir slang are encouraged."
    ),
}
```

### Flujo completo

```
main_menu
  → Jugador selecciona nivel (Beginner / Intermediate / Advanced)
  → GameManager.english_level = "beginner" | "intermediate" | "advanced"
  → GameManager.initialize_session() guarda el nivel en la sesión

Durante interrogatorio:
  NPC Dialogue → LLMClient.request_npc_response(npc_id, history)
    → LLMClient añade english_level al body:
        {
          "history": [...],
          "system_prompt": "You are Barry Peel...",
          "english_level": "beginner"
        }
    → POST http://localhost:8000/npc/{npc_id}

Backend FastAPI:
  suffix = config.ENGLISH_LEVEL_SUFFIXES[english_level]
  full_prompt = f"{npc_system_prompt}\n\n{suffix}"
  response = ollama.chat(model=config.OLLAMA_MODEL,
                         messages=[{"role": "system", "content": full_prompt}, ...])
```

### Interfaces Clave

**Godot — GameManager:**
```gdscript
# res://scripts/foundation/game_manager.gd
var english_level: String = "intermediate"  # default

func set_english_level(level: String) -> void:
    assert(level in ["beginner", "intermediate", "advanced"])
    english_level = level
```

**Godot — LLMClient:**
```gdscript
# res://scripts/foundation/llm_client.gd
func request_npc_response(npc_id: String, history: Array) -> void:
    var body := JSON.stringify({
        "history": history,
        "system_prompt": _get_system_prompt(npc_id),
        "english_level": GameManager.english_level
    })
    _http.request(BACKEND_URL + "/npc/" + npc_id,
                  ["Content-Type: application/json"],
                  HTTPClient.METHOD_POST,
                  body)
```

**Backend FastAPI:**
```python
# backend/routers/npc.py
@app.post("/npc/{npc_id}")
async def npc_response(npc_id: str, body: NPCRequest):
    suffix = config.ENGLISH_LEVEL_SUFFIXES.get(body.english_level, "")
    full_prompt = f"{body.system_prompt}\n\n{suffix}" if suffix else body.system_prompt
    messages = [{"role": "system", "content": full_prompt}] + body.history
    response = ollama.chat(model=config.OLLAMA_MODEL, messages=messages,
                           options={"num_predict": 150})
    return {"text": response["message"]["content"]}
```

**Menú principal — selector de nivel:**
```gdscript
# res://scripts/presentation/main_menu.gd
func _on_level_selected(level: String) -> void:
    GameManager.set_english_level(level)
```

## Alternativas Consideradas

### Alternativa 1: Sufijo inyectado en backend (ELEGIDA)
- **Descripción:** Godot envía `english_level` como String; el backend construye el sufijo
- **Pros:** Cambiar textos del sufijo no toca código Godot; lógica de prompt centralizada
- **Contras:** Backend necesita conocer los 3 niveles; un valor inválido puede causar error
- **Razón de elección:** Máxima flexibilidad para ajustar el sufijo sin recompilar Godot

### Alternativa 2: Prompt completo por nivel en config
- **Descripción:** Tres system prompts completos por NPC (Barry_beginner.txt, Barry_intermediate.txt, Barry_advanced.txt)
- **Pros:** Máximo control por NPC
- **Contras:** 5 NPCs × 3 niveles = 15 archivos; mantenimiento muy alto; redundancia enorme
- **Razón de rechazo:** Innecesario — el sufijo estándar funciona igual para todos los NPCs

### Alternativa 3: Parámetro separado a Ollama options
- **Descripción:** Usar `options` de Ollama (temperature, etc.) para simular nivel
- **Pros:** Sin modificar el system prompt
- **Contras:** Ollama no tiene parámetro de complejidad léxica; no resuelve el problema real
- **Razón de rechazo:** El LLM responde a instrucciones en el prompt, no a parámetros de muestreo

## Consecuencias

### Positivas
- Un solo sufijo por nivel funciona para todos los NPCs — mantenimiento mínimo
- Cambiar el texto del sufijo solo requiere editar `backend/config.py`
- `english_level` ya está en GameManager — sin datos nuevos en el modelo de estado
- El nivel queda registrado en el JSON de telemetría de sesión (ADR-0007)

### Negativas
- llama3.2 puede no respetar el sufijo consistentemente — especialmente Barry con personaje noir muy marcado
- No hay condicionamiento visual del nivel (texto de NPCs en pantalla usa la misma fuente)

### Riesgos
- **Riesgo:** llama3.2 ignora el sufijo y usa vocabulario avanzado en Beginner. **Mitigación:** Probar 10 turnos con Barry en cada nivel antes de pruebas de usuario; si no cumple, mover el sufijo al inicio del system prompt (mayor peso para el modelo).
- **Riesgo:** `english_level` llega al backend como valor inválido. **Mitigación:** `set_english_level()` tiene `assert`; backend hace `.get(level, "")` con fallback silencioso a sin sufijo.

## Requisitos GDD Abordados

| Sistema GDD | Requisito | Cómo lo aborda este ADR |
|-------------|-----------|-------------------------|
| gdd_detective_noir_vr.md | TR-nivel-001: Selector de nivel en menú principal | `set_english_level()` llamado desde `main_menu._on_level_selected()` |
| gdd_detective_noir_vr.md | TR-nivel-002: Nivel condiciona complejidad de respuestas NPC | Sufijo inyectado en system prompt en cada request al backend |

## Implicaciones de Rendimiento
- **CPU:** Sin impacto — concatenación de strings en Python; costo ~microsegundos
- **Memoria:** Sin impacto — sufijos son constantes en config (< 500 bytes)
- **Tiempo de carga:** Sin impacto
- **Red:** Sin impacto — `english_level` añade ~20 bytes al body JSON

## Plan de Migración
Primera implementación — no hay código existente que migrar.

## Criterios de Validación
- Seleccionar Beginner en menú → Barry responde con frases ≤ 10 palabras en 9/10 turnos
- Seleccionar Advanced → Barry usa al menos 1 idiom o slang noir por respuesta en 7/10 turnos
- Cambiar el texto del sufijo en `config.py` sin reiniciar Godot afecta la próxima respuesta NPC
- `english_level` aparece registrado en el JSON de telemetría de sesión

## Decisiones Relacionadas
- ADR-0001: GameManager — almacena y expone `english_level`
- ADR-0002: Ollama llama3.2 — modelo que recibe el prompt modificado
- ADR-0007 (pendiente): Telemetría — `english_level` es campo obligatorio en el JSON de sesión
