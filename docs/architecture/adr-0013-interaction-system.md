# ADR-0013: Sistema de Interacción (Interaction System)

## Estado
Propuesto

## Date
2026-05-01

## Engine Compatibility

| Campo | Valor |
|-------|-------|
| **Motor** | Godot 4 |
| **Dominio** | Core / Input |
| **Riesgo de Conocimiento** | LOW — RayCast3D, Area3D e Input son APIs estables desde Godot 4.0 |
| **Referencias Consultadas** | ADR-0001 (add_clue), ADR-0005 (señales), ADR-0012 (Camera3D), TR-interact-001/002/003 |
| **APIs Post-Cutoff Usadas** | Ninguna |
| **Verificación Requerida** | Colisión de RayCast3D contra CollisionObject3D — verificar collision_mask correcto en build exportado; overlay de inspección en resoluciones no estándar |

## ADR Dependencies

| Campo | Valor |
|-------|-------|
| **Depende De** | ADR-0001 (GameManager.add_clue() — único punto de escritura de pistas); ADR-0012 (Camera3D definida en player.tscn — RayCast3D se ancla aquí) |
| **Habilita** | ADR-0015 Inventory Module (las pistas llegan al inventario vía add_clue definido aquí); ADR-0014 NPC Dialogue Module (el prompt de interrogación lo lanza este ADR) |
| **Bloquea** | Epic "Recolección de Pistas" — no puede implementarse sin este ADR |
| **Nota de Orden** | Camera3D de ADR-0012 debe existir antes de instanciar el RayCast3D de este ADR |

---

## Contexto

### Problema
No existe un ADR que documente cómo el jugador detecta objetos en el mundo, cómo se muestra el prompt de interacción, ni cómo se realiza el pickup de pistas al inventario/GameManager. El GDD define tres tipos de interacción distintos (examinar objeto físico → overlay + pickup, examinar NPC → menú contextual, confirmar testimonio → "¿Agregar como evidencia?") que deben derivar de un contrato de interfaz único para que distintos programadores implementen interactuables consistentes.

### Restricciones
- Toda escritura de pistas al estado del juego pasa por `GameManager.add_clue()` (ADR-0001 / forbidden_pattern: escritura_directa_estado_gamemanager).
- RayCast3D debe anclarse a `Camera3D` de `player.tscn` (ADR-0012).
- El overlay de inspección bloquea el movimiento del jugador — debe llamar `enable_input(false)` (ADR-0012).
- Tecla de interacción: E (teclado) / Botón X-Xbox / Cuadrado-PS. Mapeada como acción `interact` en Input Map.
- El sistema de interacción no posee estado de sesión; toda telemetría (si aplica) va a GameManager.

### Requisitos
- Detectar objeto interactuable apuntado con RayCast3D desde Camera3D (distancia máx. 2.0 m)
- Mostrar etiqueta de acción cuando RayCast3D impacta un interactuable ("Examinar cenicero", "Interrogar a Lola")
- Al presionar E/X: ejecutar la acción del interactuable activo
- Tipos de interactuable:
  1. **ClueInteractable**: abre overlay de inspección → al confirmar → `GameManager.add_clue(clue_id)`
  2. **NPCInteractable**: abre menú contextual ("Interrogar / Examinar") → lanza NPC dialogue o inspect
  3. **EnvironmentInteractable**: muestra descripción breve (flavor text), sin pickup
- Overlay de inspección: objeto centrado, descripción, botón confirmar (E) o cancelar (Esc)
- `GameManager.add_clue()` solo se llama al confirmar — no al abrir el overlay
- Ocultar etiqueta de acción cuando no hay interactuable en foco

---

## Decisión

`interaction_system.gd` es un script adjunto a un nodo hijo de `player.tscn` (hermano de `Camera3D`). Contiene el `RayCast3D` anclado en la misma posición que `Camera3D`. En cada `_process()` castea hacia adelante; si impacta un nodo que implementa la interfaz `Interactable` (método `interact()` + propiedad `interaction_label: String`), muestra la etiqueta en HUD y habilita la tecla `interact`.

Cada objeto interactuable en el nivel implementa la interfaz con un script propio (`clue_interactable.gd`, `npc_interactable.gd`, `env_interactable.gd`). No hay herencia obligatoria — basta con que expongan `interact()` e `interaction_label`.

El overlay de inspección es una escena `CanvasLayer` (`inspect_overlay.tscn`) instanciada en el nivel, que `interaction_system.gd` llama mediante señal. El overlay congela el movimiento del jugador mientras está abierto.

### Diagrama de Arquitectura

```
player.tscn
├── CharacterBody3D [player_controller.gd]
│   ├── Camera3D
│   └── InteractionSystem [interaction_system.gd]
│       └── RayCast3D  (target_position = Vector3(0,0,-2.0), enabled=true)
│
│   _process(delta):
│     1. RayCast3D.force_raycast_update()
│     2. Si collider tiene método interact() → _focused = collider
│        Sino → _focused = null
│     3. Emitir focus_changed(_focused)  (HUD escucha para mostrar/ocultar etiqueta)
│     4. Si Input.is_action_just_pressed("interact") y _focused != null:
│          _focused.interact()

el_agave_y_la_luna.tscn
├── ... (nivel 3D)
├── Cenicero [ClueInteractable]  (clue_id="F1", clue_label="Examinar cenicero")
├── Lola [NPCInteractable]       (npc_id="lola")
├── Maleta [ClueInteractable]    (clue_id="D1", clue_label="Examinar maleta")
└── InspectOverlay [CanvasLayer] (instanciado en el nivel, oculto por defecto)

Flujo ClueInteractable.interact():
  1. Emite request_inspect(clue_id, description_text, mesh_or_texture)
  2. InteractionSystem reenvía a InspectOverlay.open(...)
  3. enable_input(false) en PlayerController
  4. Jugador lee descripción → presiona E (confirmar) o Esc (cancelar)
  5. Si confirmar → GameManager.add_clue(clue_id) → close overlay → enable_input(true)
  6. Si cancelar → close overlay → enable_input(true) — sin pickup
```

### Interfaces Clave

```gdscript
# ── Contrato de interactuable (duck-typing — no herencia obligatoria) ──────────
# Todo nodo interactuable debe exponer:
var interaction_label: String          # "Examinar cenicero", "Interrogar a Lola"
func interact() -> void                # lógica específica del objeto

# ── res://scripts/core/interaction_system.gd ────────────────────────────────
extends Node3D

const INTERACTION_DISTANCE: float = 2.0  # metros

@onready var raycast: RayCast3D = $RayCast3D

# Señales
signal focus_changed(interactable)           # null cuando no hay foco
signal inspect_requested(clue_id: String, description: String)
signal npc_menu_requested(npc_id: String)

# ── res://scripts/interactables/clue_interactable.gd ────────────────────────
extends Node3D

@export var clue_id: String = ""
@export var interaction_label: String = "Examinar"
@export var description: String = ""          # texto mostrado en overlay
@export var auto_add: bool = false            # true = sin overlay, directo a add_clue

func interact() -> void:
    if auto_add:
        GameManager.add_clue(clue_id)
    else:
        # InteractionSystem escucha y abre overlay
        inspect_requested.emit(clue_id, description)

# ── res://scripts/interactables/npc_interactable.gd ────────────────────────
extends Node3D

@export var npc_id: String = ""
@export var interaction_label: String = "Hablar"

func interact() -> void:
    npc_menu_requested.emit(npc_id)

# ── res://scripts/ui/inspect_overlay.gd ─────────────────────────────────────
extends CanvasLayer

signal confirmed(clue_id: String)
signal cancelled()

func open(clue_id: String, description: String) -> void
func close() -> void
```

---

## Alternativas Consideradas

### Alternativa A: Area3D de proximidad por objeto
- **Descripción**: Cada interactuable tiene una `Area3D` esférica; al entrar el `CharacterBody3D` del jugador aparece el prompt sin necesidad de apuntar.
- **Pros**: Más fácil de disparar — el jugador no necesita apuntar exactamente.
- **Contras**: En una cantina llena de objetos cercanos, múltiples `Area3D` se activarían simultáneamente, generando conflictos de UI. El GDD describe "apuntar y presionar E/X", no detección de proximidad.
- **Razón de Rechazo**: No alinea con el flujo del GDD (RF-02: "press-X" implica apuntado). `Area3D` se reserva para un posible sistema de trigger de zonas narrativas (fuera del scope de este ADR).

### Alternativa B: Híbrido RayCast3D + Area3D (objetos vs. NPCs)
- **Descripción**: RayCast3D para pistas físicas (requiere apuntar directo); Area3D para NPCs (solo acercarse activa el menú).
- **Pros**: Los NPCs son más grandes y fáciles de perder con raycast; la proximidad es más natural.
- **Contras**: Dos sistemas de detección que deben coexistir. El HUD debe reconciliar cuál tiene prioridad si ambos se activan.
- **Razón de Rechazo**: Scope excesivo para un prototipo académico. Si el playtest demuestra que apuntar a NPCs es frustrante, se puede agregar Area3D complementaria sin cambiar la interfaz `interact()`.

---

## Consecuencias

### Positivas
- Duck-typing en GDScript elimina herencia forzada — cada interactuable es independiente.
- `interact()` es el único contrato: cualquier nuevo objeto del nivel solo necesita implementar ese método.
- `GameManager.add_clue()` permanece como único escritor de estado (sin violar forbidden_pattern).
- `enable_input(false/true)` garantiza que el overlay bloquea el movimiento sin estados inconsistentes.
- `auto_add: bool` en `ClueInteractable` permite objetos que se recogen sin overlay (ej. papeles en el suelo).

### Negativas
- Duck-typing no da error en compilación si un objeto "interactuable" no implementa `interact()` — solo falla en runtime. Mitigable con type hints o una clase base abstracta.
- El overlay de inspección es una escena separada instanciada en el nivel — no es autoload. Requiere que el diseñador de nivel lo incluya en cada escena que lo necesite.

### Riesgos
- **Riesgo**: RayCast3D no detecta colisiones si el `collision_mask` del ray no coincide con el `collision_layer` de los interactuables. **Mitigación**: Definir capa de física dedicada para interactuables (ej. capa 3) y documentar en CLAUDE.md. Verificar en build exportado.
- **Riesgo**: Jugador abre overlay y alt-tabs — `enable_input` queda en false, cursor desaparece. **Mitigación**: Conectar `inspect_overlay.cancelled` a `enable_input(true)` y también al evento de pausa.
- **Riesgo**: `clue_id` vacío en `ClueInteractable` genera `add_clue("")` en GameManager. **Mitigación**: Assert en `interact()`: `assert(clue_id != "", "ClueInteractable sin clue_id")`.
- **Riesgo**: En el flujo "¿Agregar como evidencia?" vía diálogo NPC (RF-02 testimonio), el prompt de confirmación lo lanza el NPC Dialogue Module (ADR-0014), no este ADR. **Mitigación**: ADR-0014 también llamará `GameManager.add_clue()` directamente — patrón consistente.

---

## Requisitos GDD Abordados

| Sistema GDD | Requisito | Cómo lo aborda este ADR |
|-------------|-----------|------------------------|
| gdd_detective_noir_vr.md / TR-interact-001 | Detección de proximidad → tecla E, menú contextual (Interrogar / Examinar) | RayCast3D a 2 m + `NPCInteractable.interact()` emite `npc_menu_requested` con opciones de menú |
| gdd_detective_noir_vr.md / TR-interact-002 | Overlay de inspección — vista centrada del objeto, Esc para cerrar | `InspectOverlay.open(clue_id, description)` — CanvasLayer con confirmación (E) o cancelación (Esc) |
| gdd_detective_noir_vr.md / TR-interact-003 | Pickup de pista → inventario; prompt "¿Agregar como evidencia?" en diálogo NPC | Confirmación en overlay → `GameManager.add_clue(clue_id)`; flujo testimonio NPC delegado a ADR-0014 |
| gdd_detective_noir_vr.md / RF-02 | El jugador puede inspeccionar y recoger pistas físicas con press-X (E/X) | Acción `interact` en Input Map mapeada a E + botón X/Cuadrado de mando |

---

## Implicaciones de Rendimiento
- **CPU**: `RayCast3D.force_raycast_update()` cada frame — O(1), operación trivial del motor de física de Godot.
- **Memoria**: Una escena `InspectOverlay` en el nivel + scripts ligeros por objeto interactuable.
- **Tiempo de Carga**: Ninguno.
- **Red**: Ninguno.

---

## Plan de Migración
ADR nuevo — no hay código existente que migrar. Primera implementación.

Pasos de integración:
1. Añadir `InteractionSystem` como hijo de `CharacterBody3D` en `player.tscn`.
2. Crear capa de física 3 ("Interactable") en Project Settings → Physics → Layer Names.
3. Añadir `ClueInteractable` / `NPCInteractable` a cada objeto del nivel en `el_agave_y_la_luna.tscn`.
4. Instanciar `InspectOverlay` en `el_agave_y_la_luna.tscn`.
5. HUD (ADR-0017) conecta `InteractionSystem.focus_changed` para mostrar/ocultar etiqueta de acción.

---

## Criterios de Validación
- Al apuntar al cenicero (F1) a menos de 2 m, aparece etiqueta "Examinar cenicero".
- Al alejarse o mirar otro lado, la etiqueta desaparece.
- Al presionar E: se abre overlay con descripción del cenicero; el jugador no puede moverse.
- Al confirmar con E: `GameManager.get_clue_state("F1")` retorna `"unchecked"` (pista registrada).
- Al cancelar con Esc: no se registra la pista; el jugador puede moverse.
- Al apuntar a Lola: aparece menú "Interrogar / Examinar" al presionar E.
- `clue_id` vacío en un `ClueInteractable` genera assert visible en editor.

---

## Decisiones Relacionadas
- [ADR-0001](adr-0001-gamemanager-singleton.md) — `add_clue()` como único escritor de pistas
- [ADR-0005](adr-0005-arquitectura-senales.md) — Señales para comunicación entre InteractionSystem y HUD/Overlay
- [ADR-0012](adr-0012-player-controller.md) — Camera3D donde se ancla el RayCast3D; `enable_input()` para bloquear movimiento
- [ADR-0014](adr-0014-npc-dialogue-module.md) — Recibe `npc_menu_requested` y gestiona el diálogo + "¿Agregar como evidencia?"
- [ADR-0015](adr-0015-inventory-module.md) — Recibe `clue_added` de GameManager y actualiza vista de inventario
