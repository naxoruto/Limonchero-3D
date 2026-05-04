# Índice de ADRs — Limonchero 3D

**¿Qué es un ADR?** Un Architecture Decision Record documenta una decisión técnica importante: qué se eligió, por qué, y qué alternativas se descartaron. Son la memoria del equipo — si alguien pregunta "¿por qué hacemos X así?", la respuesta está en el ADR correspondiente.

**Cómo leer uno:** Ir directo a `## Decisión` para entender qué se decidió. `## Contexto → Problema` explica el por qué. `## Alternativas Consideradas` explica qué se descartó y por qué.

---

## Tabla de ADRs

| ADR | Título | Dominio | Decisión en una línea |
|-----|--------|---------|----------------------|
| [ADR-0001](adr-0001-gamemanager-singleton.md) | GameManager Singleton | Núcleo / Scripting | Singleton Autoload — única fuente de verdad para estado de sesión (pistas, acusaciones, telemetría) |
| [ADR-0002](adr-0002-llm-ollama-exclusivo.md) | Ollama LLM Exclusivo | Núcleo / LLM | Ollama + llama3.2 local para todas las fases — sin OpenAI, sin internet |
| [ADR-0003](adr-0003-backend-fastapi-proceso-separado.md) | Backend FastAPI | Núcleo / Backend | Godot lanza el proceso FastAPI automáticamente con `OS.create_process()` + health check |
| [ADR-0004](adr-0004-ptt-audiocapture-wav.md) | PTT AudioCapture | Audio / Entrada | `AudioEffectCapture` captura micrófono → WAV en memoria → POST al backend |
| [ADR-0005](adr-0005-arquitectura-senales.md) | Arquitectura de Señales | Núcleo / Scripting | Comunicación entre capas solo por señales Godot tipadas; sin llamadas directas entre capas |
| [ADR-0006](adr-0006-condicionamiento-nivel-ingles.md) | Nivel de Inglés en Prompts | Núcleo / LLM | Nivel de inglés se inyecta como sufijo en system prompt del NPC vía campo en POST body |
| [ADR-0007](adr-0007-telemetria-sesion.md) | Telemetría de Sesión | Núcleo / Persistencia | GameManager exporta JSON de telemetría a `user://` al terminar sesión o resolver caso |
| [ADR-0008](adr-0008-puerta-confesion.md) | Puerta de Confesión | Lógica de Juego | Barry confiesa solo si F1+F2+F3 en estado `good` Y Barry nombrado como acusado — irreversible |
| [ADR-0009](adr-0009-balbuceo-npc.md) | Balbuceo NPC | Audio | Clips `.ogg` por NPC en `AudioStreamRandomizer` — cubren espera LLM sin TTS real |
| [ADR-0010](adr-0010-tablon-diegetico.md) | Tablón Diegético | Rendering / UI | `SubViewport` → `RichTextLabel` → `ViewportTexture` → `Sprite3D` en mundo 3D cerca del NPC |
| [ADR-0011](adr-0011-anti-stall-system.md) | Anti-Stall System | Núcleo / Game State | Timer en GameManager dispara pistas de Gajito a 4/5/7 min sin evidencia nueva; resetea en `clue_added` |
| [ADR-0012](adr-0012-player-controller.md) | Controlador del Jugador | Núcleo / Entrada | `CharacterBody3D` + `Camera3D` hijo — WASD + mouse/joystick, `move_and_slide()` en `_physics_process()` |
| [ADR-0013](adr-0013-interaction-system.md) | Sistema de Interacción | Núcleo / Entrada | `RayCast3D` desde cámara detecta objetos con duck-type `interact()` + `interaction_label`; pickup delega a `GameManager.add_clue()` |
| [ADR-0014](adr-0014-npc-dialogue-module.md) | Módulo de Diálogo NPC | Feature / IA | `NPCDialogueManager` Autoload gestiona historial por NPC, POST `/npc/{id}` al backend, árbol de acusación scripted |
| [ADR-0015](adr-0015-inventory-module.md) | Módulo de Inventario | UI / Feature | `InventoryHUD` CanvasLayer — `GridContainer` 4×2, reactivo a señales de GameManager, sin escritura de estado |
| [ADR-0016](adr-0016-gajito-module.md) | Módulo Gajito | Feature / IA / UI | Autoload que POST `/grammar` en paralelo al NPC; muestra corrección español auto-dismiss 5s; recibe anti-stall hints |
| [ADR-0017](adr-0017-hud-system.md) | Sistema HUD | UI / Presentación | `HUDManager` Autoload CanvasLayer — subtítulos dual-channel, PTT indicator, interaction prompts, Gajito popup; sin lógica de juego |

---

## Mapa de Dependencias

```
ADR-0001 GameManager (hub central)
  ├── ADR-0007 Telemetría          (escribe a GameManager)
  ├── ADR-0008 Confesión           (lee GameManager.clues)
  ├── ADR-0011 Anti-Stall          (timer en GameManager)
  ├── ADR-0013 Interacción         (llama GameManager.add_clue)
  └── ADR-0015 Inventario          (escucha señales de GameManager)

ADR-0003 Backend FastAPI
  ├── ADR-0002 Ollama LLM          (backend usa Ollama)
  ├── ADR-0004 PTT Audio           (Godot → POST /stt al backend)
  ├── ADR-0006 Nivel de inglés     (backend modifica prompts)
  └── ADR-0014 Diálogo NPC         (Godot → POST /npc al backend)

ADR-0005 Señales (rige comunicación entre todos los módulos)

ADR-0014 Diálogo NPC
  └── ADR-0016 Gajito              (grammar check paralelo)

ADR-0009 Balbuceo  →  ADR-0010 Tablón  →  ADR-0017 HUD
  (todos presentan output al jugador, gestionados por ADR-0017)
```

---

## Por dónde empezar (recomendado)

| Si eres... | Lee primero |
|-----------|-------------|
| Nuevo en el proyecto | ADR-0001 → ADR-0005 → ADR-0003 |
| Implementando NPCs | ADR-0014 → ADR-0006 → ADR-0009 |
| Implementando gameplay | ADR-0008 → ADR-0013 → ADR-0011 |
| Implementando UI/HUD | ADR-0017 → ADR-0015 → ADR-0016 |
| Configurando backend | ADR-0003 → ADR-0002 → ADR-0004 |
