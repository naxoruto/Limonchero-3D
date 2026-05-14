# Story 101: HUDManager Autoload

> **Epic**: Presentation: HUD/UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Foundation
> **Estimate**: 3-4 horas

## Context

**ADR Governing Implementation**: [ADR-0017: HUD System](../../../docs/architecture/adr-0017-hud-system.md)
**ADR Decision Summary**: HUDManager como autoload CanvasLayer, z-index alto. Señales como único medio de comunicación con otras capas.

**GDD**: §8.3.2 — Elementos HUD Overlay
**UX Spec**: `design/ux/hud.md`
**Art Bible**: §7.3 — Elementos HUD Overlay

**Engine**: Godot 4 GDScript | **Risk**: LOW
**Engine Notes**: Autoload en `Project Settings → Autoload → HUDManager.tscn`. CanvasLayer layer 10.

---

## Acceptance Criteria

- [ ] `HUDManager.tscn` como escena Autoload (CanvasLayer, layer 10)
- [ ] `HUDManager.gd` como script con nodos hijo: SubtitlePanel, PTTIndicator, InteractionPrompt, InventoryNotification
- [ ] API pública expuesta (ver Implementation Notes)
- [ ] Señales de entrada conectadas desde PlayerController, InteractionSystem, VoiceManager, LLMClient
- [ ] Todas las señales se conectan vía `SceneTree` (sin `get_node()` cross-layer)
- [ ] `set_visible_all(false)` para ocultar HUD completo al abrir menús/overlays
- [ ] `set_visible_all(true)` para restaurar al cerrar menús/overlays
- [ ] Crosshair (`Label`, center, texto="." en `#E8D5A3`) siempre visible excepto en menús

## Implementation Notes

```gdscript
# scripts/ui/hud_manager.gd
extends CanvasLayer

signal interaction_prompt_clicked()

@onready var subtitle_panel: Control = $SubtitlePanel
@onready var ptt_indicator: Control = $PTTIndicator
@onready var interaction_prompt: Label = $InteractionPrompt
@onready var inventory_notification: Label = $InventoryNotification
@onready var crosshair: Label = $Crosshair

func set_interaction_prompt(text: String, visible: bool) -> void:
    interaction_prompt.text = text
    interaction_prompt.visible = visible

func set_ptt_state(state: String) -> void:
    # "idle" | "recording" | "processing"
    ptt_indicator.set_state(state)

func show_inventory_notification(clue_name: String) -> void:
    inventory_notification.text = "[%s] añadida al inventario" % clue_name
    inventory_notification.visible = true
    await get_tree().create_timer(1.5).timeout
    inventory_notification.visible = false

func set_hud_visible(visible: bool) -> void:
    subtitle_panel.visible = visible
    ptt_indicator.visible = visible
    interaction_prompt.visible = visible
    inventory_notification.visible = visible
```

## Dependencies

- InteractionSystem Story 001 (prompt text)
- GameManager Story 002 (inventory_changed signal)
- Voice/PTT Story 001 (recording_started/stopped signals)
