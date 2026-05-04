# Story 003: Overlay de Inspección de Objeto

> **Epic**: Sistema de Interacción
> **Status**: Ready
> **Layer**: Core
> **Type**: UI + Logic
> **Estimate**: 3-4 horas

## Context

**ADR Governing Implementation**: ADR-0013, ADR-0012  
**ADR Decision Summary**: Overlay centrado. Esc para cerrar. `PlayerController.enable_input(false)` mientras overlay está abierto. Cursor visible durante inspección.

**GDD Requirement**: RF-02 — Modo inspección de pista: objeto en pantalla, botón Esc para cerrar.

**Engine**: Godot 4.6 GDScript | **Risk**: LOW

---

## Acceptance Criteria

- [ ] Al emitir `inspect_opened(object_id)`, aparece overlay centrado con el modelo/imagen del objeto
- [ ] `PlayerController.enable_input(false)` llamado al abrir → movimiento deshabilitado, cursor visible
- [ ] Presionar Esc cierra el overlay y llama `PlayerController.enable_input(true)`
- [ ] Overlay muestra: nombre del objeto (en español) + descripción breve
- [ ] Si el objeto es pista recogible, muestra botón `[E] Añadir al inventario` (solo si no está ya recogida)
- [ ] Botón `[Esc] Cerrar` siempre visible en esquina superior derecha

## Implementation Notes

```gdscript
# scripts/ui/inspect_overlay.gd
extends CanvasLayer

@onready var model_viewport: SubViewport = $SubViewport
@onready var name_label: Label = $Panel/NameLabel
@onready var desc_label: Label = $Panel/DescLabel
@onready var add_button: Button = $Panel/AddButton

var _current_object_id: String = ""

func show_object(object_id: String) -> void:
    _current_object_id = object_id
    var data := ObjectDatabase.get(object_id)  # dict con name, description, clue_id
    name_label.text = data.get("name", "")
    desc_label.text = data.get("description", "")
    var is_clue := data.has("clue_id")
    var already_picked := is_clue and GameManager.get_clue_state(data["clue_id"]).get("state") != "undiscovered"
    add_button.visible = is_clue and not already_picked
    show()
    get_tree().get_first_node_in_group("player").enable_input(false)

func _unhandled_input(event: InputEvent) -> void:
    if visible and event.is_action_pressed("ui_cancel"):
        _close()

func _on_add_pressed() -> void:
    InteractionSystem.clue_picked.emit(_current_object_id)
    _close()

func _close() -> void:
    hide()
    get_tree().get_first_node_in_group("player").enable_input(true)
```

**Objeto Database** — definir en `scripts/data/object_database.gd` (Dictionary con todos los IDs de pistas/objetos del GDD §3.4).

## Test File

`tests/unit/core/inspect_overlay_test.gd`  
- Test: `show_object()` → `PlayerController._input_enabled == false`  
- Test: Esc → overlay oculto + `_input_enabled == true`
