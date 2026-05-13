# ADR-0009: Balbuceo NPC — Audio de Pensamiento mientras el LLM Responde

## Estado
Propuesto

## Fecha
2026-05-01

## Compatibilidad con el Motor

| Campo | Valor |
|-------|-------|
| **Motor** | Godot 4.6 |
| **Dominio** | Audio |
| **Riesgo de Conocimiento** | BAJO — AudioStreamPlayer, AudioStreamRandomizer son APIs estables |
| **Referencias Consultadas** | Conocimiento directo de Godot 4.6 Audio API |
| **APIs Post-Corte Usadas** | Ninguna |
| **Verificación Requerida** | Confirmar que AudioStreamRandomizer está disponible en Godot 4.6 y acepta múltiples streams .ogg |

## Dependencias ADR

| Campo | Valor |
|-------|-------|
| **Depende De** | ADR-0004 (VoiceManager emite audio_captured — el balbuceo inicia cuando LLMClient recibe la request) |
| **Habilita** | Experiencia de interrogatorio con feedback audio del NPC |
| **Bloquea** | Ninguno |
| **Nota de Orden** | Los clips deben grabarse antes de la integración final; el sistema puede implementarse con clips placeholder |

## Contexto

### Declaración del Problema
Mientras el backend procesa la request LLM (hasta 8s), el jugador está esperando sin feedback visual ni auditivo del NPC. Se necesita un mecanismo de "el NPC está pensando" que sea auténtico para el mundo noir sin requerir TTS (que fue descartado) ni generación procedural compleja.

### Restricciones
- Sin TTS — los NPCs no hablan, solo balbucejan como indicador de pensamiento
- Sofía Meza (audio del equipo) grabará clips cortos por NPC
- Godot 4.6 — sin plugins de audio de terceros
- Los clips deben sentirse distintos por NPC (Barry ≠ Moni ≠ Lola)

### Requisitos
- Reproducir balbuceo mientras `_waiting_for_llm` es true
- Detener balbuceo cuando llega `npc_response_ready`
- Clips distintos por NPC (mínimo 3 por personaje)
- Duración de clip: 0.5–1.0 segundos
- Formato: .ogg (mejor compresión en Godot)

## Decisión

**Sofía graba 3–5 clips .ogg de balbuceo por NPC. En Godot, cada NPC tiene un `AudioStreamPlayer` con `AudioStreamRandomizer` que selecciona un clip aleatorio. El balbuceo se reproduce en loop mientras el LLMClient espera respuesta.**

### Estructura de archivos

```
res://assets/audio/babble/
  barry/
    babble_01.ogg
    babble_02.ogg
    babble_03.ogg
  moni/
    babble_01.ogg
    babble_02.ogg
    babble_03.ogg
  lola/
    babble_01.ogg
    babble_02.ogg
    babble_03.ogg
  gerry/
    babble_01.ogg
    babble_02.ogg
  spud/
    babble_01.ogg
    babble_02.ogg
```

### Implementación en NPCDialogue

```gdscript
# res://scripts/features/npc_dialogue.gd
@onready var _babble_player: AudioStreamPlayer = $BabblePlayer

func _ready() -> void:
    LLMClient.npc_response_ready.connect(_on_npc_response_ready)

func _start_babble(npc_id: String) -> void:
    var randomizer := AudioStreamRandomizer.new()
    var dir := "res://assets/audio/babble/%s/" % npc_id
    for i in range(1, 4):
        var stream := load("%sbabble_%02d.ogg" % [dir, i])
        if stream:
            randomizer.add_stream(i - 1, stream)
    _babble_player.stream = randomizer
    _babble_player.play()

func _stop_babble() -> void:
    _babble_player.stop()

func _on_npc_response_ready(npc_id: String, text: String) -> void:
    _stop_babble()
    # mostrar texto en panel diegético
```

### Flujo completo

```
Jugador suelta V → audio_captured emitido
  → LLMClient envía POST /npc/{id}
  → NPCDialogue._start_babble(npc_id)    ← balbuceo inicia
  → [backend procesa: STT + LLM ~2-8s]
  → npc_response_ready(npc_id, text)
  → NPCDialogue._stop_babble()           ← balbuceo detiene
  → Texto aparece en tablón/panel
```

## Alternativas Consideradas

### Alternativa 1: Generación procedural con AudioStreamGenerator
- **Descripción:** Godot genera ruido formante en tiempo real simulando habla
- **Pros:** Sin actores de voz; sin archivos; personalizable por parámetros
- **Contras:** Implementación compleja (~100 líneas de DSP); resultado genérico y poco característico
- **Razón de rechazo:** Sofía puede grabar clips en 1-2 horas; el resultado es más auténtico y caracteriza a cada NPC.

### Alternativa 2: Sin balbuceo — solo indicador visual
- **Descripción:** HUD muestra "Gajito está pensando…" sin audio
- **Pros:** Cero trabajo de audio
- **Contras:** La espera de 8s sin feedback auditivo se siente muerta; rompe la inmersión del interrogatorio noir
- **Razón de rechazo:** El balbuceo es parte del lenguaje audiovisual del género detective; su ausencia sería notable.

## Consecuencias

### Positivas
- Feedback inmediato al jugador de que el NPC está procesando
- Cada NPC tiene voz propia — Barry suena diferente a Moni
- AudioStreamRandomizer evita repetición mecánica del mismo clip
- Los clips .ogg ocupan < 500 KB total para todos los NPCs

### Negativas
- Requiere trabajo de grabación de Sofía antes de la integración final
- Si Sofía no termina los clips a tiempo, se necesitan placeholders (un clip genérico por NPC)

### Riesgos
- **Riesgo:** AudioStreamRandomizer no disponible o tiene API diferente en Godot 4.6. **Mitigación:** Alternativa: usar un Array de streams y seleccionar con `randi() % streams.size()` manualmente.
- **Riesgo:** Los clips no están listos cuando el programador integra el sistema. **Mitigación:** Usar un clip placeholder `res://assets/audio/babble/placeholder.ogg` hasta que Sofía entregue los definitivos.

## Requisitos GDD Abordados

| Sistema GDD | Requisito | Cómo lo aborda este ADR |
|-------------|-----------|-------------------------|
| gdd_detective_noir_vr.md | TR-npc-002: Balbuceo NPC mientras LLM procesa | AudioStreamRandomizer con clips .ogg por NPC |

## Implicaciones de Rendimiento
- **CPU:** Reproducción de .ogg — decodificación en hilo de audio; sin impacto en render
- **Memoria:** ~500 KB total de clips en RAM (streamed, no precargados)
- **Tiempo de carga:** Sin impacto — clips se cargan al iniciar diálogo con el NPC
- **Red:** Sin impacto

## Plan de Migración
Primera implementación — no hay código existente que migrar.
Sofía entrega clips antes del sprint de integración de diálogo NPC.

## Criterios de Validación
- Al soltar V, el balbuceo del NPC correspondiente inicia dentro de 1 frame
- Al recibir respuesta LLM, el balbuceo detiene antes de mostrar el texto
- Cada NPC suena distinto (validación subjetiva por el equipo)
- El sistema funciona con clips placeholder si los definitivos no están listos

## Decisiones Relacionadas
- ADR-0004: VoiceManager — `audio_captured` desencadena el envío LLM que activa el balbuceo
- ADR-0010 (pendiente): Tablón diegético — el texto del NPC aparece en el mismo sistema que el balbuceo termina
