# Story 002: Recogida de Pista → Inventario

> **Epic**: Sistema de Interacción
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3 horas

## Context

**ADR Governing Implementation**: ADR-0013, ADR-0001  
**ADR Decision Summary**: `InteractionSystem` es el único caller de `GameManager.add_clue()`. Cadena: `clue_picked` → `GameManager.add_clue()` → `inventory_changed` → HUD actualiza.

**Engine**: Godot 4.6 GDScript | **Risk**: LOW

---

## Acceptance Criteria

- [ ] Al emitir `clue_picked(clue_id)`, se llama `GameManager.add_clue(clue_id)`
- [ ] El objeto pista desaparece del mundo (o se vuelve no-interactuable) tras recogerlo
- [ ] HUD muestra notificación breve `"[pista] añadida al inventario"` (1.5s)
- [ ] SFX `inventory_pickup.ogg` se reproduce al recoger
- [ ] El mismo clue_id no puede recogerse dos veces
- [ ] Anti-stall: al recoger pista, GameManager reinicia temporizadores anti-estancamiento

## Implementation Notes

Conectar señal al inicializar:
```gdscript
# En el nodo raíz de la escena o en un Autoload
interaction_system.clue_picked.connect(_on_clue_picked)

func _on_clue_picked(clue_id: String) -> void:
    if GameManager.get_clue_state(clue_id).get("state") != "undiscovered":
        return  # ya recogida
    GameManager.add_clue(clue_id)
    # Desactivar nodo interactuable
    var node := _find_interactable_node(clue_id)
    if node:
        node.set_process(false)
        node.hide()  # o queue_free() según diseño
    # HUD notificación
    HudManager.show_pickup_notification(clue_id)
    # SFX
    AudioPlayer.play_sfx("inventory_pickup")
```

**Cadena completa (de architecture.md):**
```
E key → clue_picked(clue_id)
  → GameManager.add_clue(clue_id)           # único escritor
  → GameManager emite inventory_changed
  → HUD.update_inventory()
  → AntiStall.reset_timers()
  → InspectOverlay.show(clue_id)            # ver Story 003
```

## Test File

`tests/unit/core/clue_pickup_test.gd`  
- Test: `clue_picked` → `GameManager.clues` contiene clue_id  
- Test: mismo clue_id dos veces → no duplicado en inventario
