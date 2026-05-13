# Story 001: Detección de Proximidad y Prompt "Presiona E"

> **Epic**: Sistema de Interacción
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3-4 horas

## Context

**ADR Governing Implementation**: [ADR-0013: Interaction System](../../../docs/architecture/adr-0013-interaction-system.md)  
**ADR Decision Summary**: RayCast3D + Area3D. Capa física 3 para interactuables. Señales `clue_picked`, `npc_context_opened`, `inspect_opened`. Sin `get_node()` cross-layer.

**Engine**: Godot 4.6 GDScript | **Risk**: LOW  
**Engine Notes**: Capa física 3 debe configurarse en `Project Settings → Physics → 3D → Layer Names`. Verificar en build exportado — RayCast puede comportarse distinto fuera del editor.

---

## Acceptance Criteria

- [ ] `InteractionSystem` como Autoload o hijo del Player, con `RayCast3D` apuntando al frente
- [ ] Detecta nodos en capa física 3 dentro de 2 metros
- [ ] Cuando hay objeto en rango: HUD muestra prompt `[E] Examinar` o `[E] Interrogar` según tipo
- [ ] Cuando no hay objeto: prompt oculto
- [ ] `register_interactable(node, type)` registra nodos al entrar a la escena
- [ ] Tipos válidos: `"clue"` | `"npc"` | `"object"`
- [ ] Señales emitidas al presionar E: `clue_picked(clue_id)`, `npc_context_opened(npc_id)`, `inspect_opened(object_id)`

## Implementation Notes

```gdscript
# scripts/player/interaction_system.gd
extends Node

signal clue_picked(clue_id: String)
signal npc_context_opened(npc_id: String)
signal inspect_opened(object_id: String)

@onready var raycast: RayCast3D = $RayCast3D  # hijo del nodo Player/Camera3D
var _interactables: Dictionary = {}  # node_id → {node, type, id}

func register_interactable(node: Node3D, type: String, object_id: String) -> void:
    _interactables[node.get_instance_id()] = {
        "node": node, "type": type, "id": object_id
    }

func _process(_delta: float) -> void:
    if not raycast.is_colliding():
        _hide_prompt()
        return
    var target := raycast.get_collider()
    var key := target.get_instance_id()
    if _interactables.has(key):
        var data: Dictionary = _interactables[key]
        _show_prompt(data["type"])
        if Input.is_action_just_pressed("interact"):
            _handle_interact(data)
    else:
        _hide_prompt()

func _handle_interact(data: Dictionary) -> void:
    match data["type"]:
        "clue":   clue_picked.emit(data["id"])
        "npc":    npc_context_opened.emit(data["id"])
        "object": inspect_opened.emit(data["id"])

func _show_prompt(type: String) -> void:
    var label := "[E] Interrogar" if type == "npc" else "[E] Examinar"
    # Emitir señal al HUD o usar un autoload UI
    pass

func _hide_prompt() -> void:
    pass
```

**Configurar RayCast3D:**
- `target_position`: `Vector3(0, 0, -2)` (2 metros adelante)
- `collision_mask`: capa 3 exclusivamente

## Test File

`tests/unit/core/interaction_detection_test.gd`  
- Test: nodo en capa 3 dentro de rango → señal correcta al presionar E  
- Test: nodo en capa distinta → sin señal
